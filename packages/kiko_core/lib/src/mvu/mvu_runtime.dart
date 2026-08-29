import 'dart:async';
import 'dart:collection';

import 'package:kiko_log/kiko_log.dart';
import 'package:termparser/termparser_events.dart';

import '../widgets/hit_map.dart';
import 'cmd.dart';
import 'frame_report.dart';
import 'mouse_router.dart';
import 'msg.dart';
import 'pointer_msg.dart';
import 'update_context.dart';

/// Internal cancellation token to prevent orphaned task results from queueing.
///
/// When [Quit] is processed, the token is cancelled. Any async tasks that
/// complete after cancellation will have their results discarded rather than
/// queued. This prevents messages from being processed during shutdown.
///
/// Note: This does not cancel in-flight async work (e.g., HTTP requests).
/// The work completes, but its result is discarded.
class _CancellationToken {
  bool _cancelled = false;

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelled;

  /// Requests cancellation.
  void cancel() => _cancelled = true;
}

/// Callback when a message is queued (for wake-up signaling).
typedef OnMsgQueued = void Function();

/// MVU runtime handles command processing and message queue management.
///
/// Every event source — terminal events, one-shot ticks, async task results,
/// frame reports — pushes to one queue in FIFO order. [nextMsg] waits on that
/// queue without polling; [close] wakes a waiting loop so shutdown can regain
/// control.
class MvuRuntime {
  final Queue<Msg> _msgQueue = Queue<Msg>();
  final MouseRouter _router = MouseRouter();
  _CancellationToken _token = _CancellationToken();

  /// The one-shot timers armed by [Tick] and not yet fired.
  final Set<Timer> _pendingTicks = {};

  /// Subscription to terminal events stream.
  StreamSubscription<Event>? _eventSubscription;

  /// Terminal events that arrived while delivery was held by
  /// [holdEventsForFirstFrame], waiting on [flushStartupEvents] to stamp and
  /// queue them.
  final List<Event> _startupEvents = [];

  /// Whether an incoming event is stamped and queued immediately, rather than
  /// held in [_startupEvents]. See [holdEventsForFirstFrame].
  bool _liveDelivery = true;

  /// Whether [close] has been called: [nextMsg] answers null from then on.
  bool _closed = false;

  /// The last report the previous frame produced, per widget id and type.
  ///
  /// A frame's report equal to this one is not news and is not queued.
  Map<(String, Type), FrameReport> _lastReports = const {};

  /// Exit code set by Quit command.
  int exitCode = 0;

  /// The tagged geometry of the last frame committed to the screen.
  ///
  /// The application refreshes it after every draw, and update reads it back
  /// through [UpdateContext.hits] to resolve a mouse event against the cells
  /// the user is actually looking at. Empty until the first frame is drawn.
  HitMap lastHitMap = const HitMap.empty();

  /// Completer for wake-up signaling.
  Completer<void> _wakeUp = Completer<void>();

  /// Callback when message queued (signals wake-up).
  final OnMsgQueued? _onMsgQueued;

  /// Creates a new MVU runtime.
  MvuRuntime({OnMsgQueued? onMsgQueued}) : _onMsgQueued = onMsgQueued;

  /// Resets runtime state for a new run.
  void reset() {
    exitCode = 0;
    lastHitMap = const HitMap.empty();
    _router.reset();
    _msgQueue.clear();
    _wakeUp = Completer<void>();
    _closed = false;
    _lastReports = const {};
    _cancelTicks();
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    _startupEvents.clear();
    _liveDelivery = true;
    _token = _CancellationToken();
  }

  /// Subscribes to terminal events stream.
  ///
  /// All terminal events are converted to messages and queued in FIFO order
  /// along with ticks and async task results.
  ///
  /// A mouse event is stamped as it arrives with the geometry then on screen,
  /// so it stays aimed at the cells the user aimed it at however long it waits.
  /// See [holdEventsForFirstFrame] for the one window where that geometry
  /// does not exist yet.
  void subscribeToEvents(Stream<Event> events) {
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = events.listen((event) {
      if (_liveDelivery) {
        final msg = eventToMsg(event, hits: lastHitMap);
        if (msg != null) queueMsg(msg);
      } else {
        _startupEvents.add(event);
      }
    });
  }

  /// Holds incoming events instead of stamping and queuing them immediately,
  /// until [flushStartupEvents] is called.
  ///
  /// A message handler can emit a terminal event (a synthetic click, say)
  /// before the runtime has ever drawn a frame — there is no committed
  /// geometry yet to stamp it against. Call this right after
  /// [subscribeToEvents] and before that first draw runs, so nothing slips
  /// through and gets stamped against an empty [lastHitMap].
  void holdEventsForFirstFrame() => _liveDelivery = false;

  /// Stamps and queues events held by [holdEventsForFirstFrame], then resumes
  /// immediate delivery for everything after.
  ///
  /// Call once, right after the runtime's first draw commits — the geometry
  /// those held events were always meant to resolve against.
  ///
  /// A held [WindowResizeEvent] is dropped instead of queued. Enabling
  /// in-band resize reporting makes the terminal send one immediately, and
  /// that report lands inside this hold window — it is not news, just an
  /// echo of the size the first draw already used. A resize that arrives
  /// after this flush is delivered normally; a terminal slow enough to get
  /// its enable-time report past the flush costs the app one redundant
  /// resize carrying the size it already has, which is harmless.
  void flushStartupEvents() {
    for (final event in _startupEvents) {
      if (event is WindowResizeEvent) continue;
      final msg = eventToMsg(event, hits: lastHitMap);
      if (msg != null) queueMsg(msg);
    }
    _startupEvents.clear();
    _liveDelivery = true;
  }

  /// Resolves a dequeued [msg] into the messages `update` should see, and the
  /// geometry they were resolved against.
  ///
  /// A mouse event arrives as one message and leaves as up to three: the widget
  /// the pointer left, the widget whose gesture was abandoned, and the routed
  /// [PointerMsg] itself. Deliver them in order, to the same model. Every other
  /// message passes through as itself.
  ///
  /// The returned `hits` is what [UpdateContext.hits] should carry for all of
  /// them: the frame the pointer was over for a mouse event, and the last frame
  /// committed for everything else. An app that walks [HitMap.hitPath] to hand a
  /// declined event to the next widget out therefore walks the very path that
  /// was hit.
  ({List<Msg> msgs, HitMap hits}) route(Msg msg) => (
    msgs: _router.route(msg, lastHitMap),
    hits: msg is RawPointerMsg ? msg.hits : lastHitMap,
  );

  /// Queues a message and signals wake-up.
  void queueMsg(Msg msg) {
    _msgQueue.add(msg);
    _signalWakeUp();
  }

  /// Queues the reports of a committed frame that carry news.
  ///
  /// A report equal to the one the previous frame produced under the same id
  /// and type is not queued: the fact has not changed, so its owner has
  /// nothing to learn. That is what lets a frame caused by a report settle
  /// instead of reporting its way into the next frame forever. A report
  /// whose id and type were absent from the previous frame is always queued.
  ///
  /// Reports are compared with `==`, so a report kind is a value.
  void queueReports(Iterable<FrameReport> reports) {
    final next = <(String, Type), FrameReport>{};
    for (final report in reports) {
      final key = (report.id, report.runtimeType);
      next[key] = report;
      if (_lastReports[key] != report) queueMsg(report);
    }
    _lastReports = next;
  }

  /// Whether a message is waiting in the queue.
  bool get hasPending => _msgQueue.isNotEmpty;

  /// Signals the event loop to wake up.
  void _signalWakeUp() {
    if (!_wakeUp.isCompleted) {
      _wakeUp.complete();
    }
    _onMsgQueued?.call();
  }

  /// Resets wake-up completer for next wait cycle.
  void _resetWakeUp() {
    if (_wakeUp.isCompleted) {
      _wakeUp = Completer<void>();
    }
  }

  /// Returns the wake-up future for awaiting.
  Future<void> get wakeUpFuture => _wakeUp.future;

  /// Takes the next message from the queue, waiting until one is queued.
  ///
  /// Every event source pushes to the same queue in FIFO order, so messages
  /// interleave fairly without starvation. Returns immediately when a message
  /// is waiting; otherwise waits — indefinitely — for [queueMsg] or [close].
  /// Answers null once the runtime is closed, whether or not messages remain:
  /// shutdown has started and nothing else is to be processed.
  Future<Msg?> nextMsg() async {
    while (true) {
      if (_closed) return null;
      if (_msgQueue.isNotEmpty) return _msgQueue.removeFirst();
      await _wakeUp.future;
      _resetWakeUp();
    }
  }

  /// Closes the queue: a waiting [nextMsg] wakes and answers null, and so does
  /// every call after.
  ///
  /// [dispose] calls it; shutdown from outside the loop — a signal, a
  /// `dispose(code)` — reaches the loop through it.
  void close() {
    _closed = true;
    _signalWakeUp();
  }

  /// Coalesces pending messages in the queue.
  ///
  /// For each coalesceable message type (identified by [Msg.coalesceKey]),
  /// keeps only the latest message, removing older duplicates.
  /// This reduces processing for high-frequency events like mouse moves.
  void coalesceQueue() {
    if (_msgQueue.length < 2) return;

    final messages = _msgQueue.toList();
    final seen = <String, int>{}; // coalesceKey → index to keep
    final toRemove = <int>{};

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.coalesceable) {
        final key = msg.coalesceKey;
        if (seen.containsKey(key)) {
          toRemove.add(seen[key]!); // mark older for removal
        }
        seen[key] = i;
      }
    }

    if (toRemove.isNotEmpty) {
      _msgQueue.clear();
      for (var i = 0; i < messages.length; i++) {
        if (!toRemove.contains(i)) {
          _msgQueue.add(messages[i]);
        }
      }
    }
  }

  /// Cancels every pending one-shot tick.
  void _cancelTicks() {
    for (final timer in _pendingTicks) {
      timer.cancel();
    }
    _pendingTicks.clear();
  }

  /// Cancels timers and subscriptions.
  void _cleanup() {
    _cancelTicks();
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
  }

  /// Process command, returns true if should exit.
  bool processCmd(Cmd? cmd) {
    switch (cmd) {
      case null:
        return false;
      case Quit(:final code):
        _token.cancel();
        exitCode = code;
        _cleanup();
        return true;
      case Tick(:final interval, :final id, :final key):
        final stopwatch = Stopwatch()..start();
        late final Timer timer;
        timer = Timer(interval, () {
          _pendingTicks.remove(timer);
          queueMsg(TickMsg(id, key: key, elapsed: stopwatch.elapsed));
        });
        _pendingTicks.add(timer);
        return false;
      case Emit(:final msg):
        queueMsg(msg);
        return false;
      case final AsyncCmd task:
        final token = _token; // Capture current token
        unawaited(
          task.execute().then((msg) {
            if (msg != null && !token.isCancelled) queueMsg(msg);
          }),
        );
        return false;
      case Batch(:final cmds):
        for (final c in cmds) {
          if (processCmd(c)) return true;
        }
        return false;
      default:
        // Widget→app commands (events) must be consumed in update() before
        // they reach the runtime — everything legitimate is matched above, so
        // anything landing here is a forgotten event handler (or a Cmd nobody
        // handles).
        assert(() {
          Log.warn(
            'Cmd ${cmd.runtimeType} reached the runtime unhandled and was '
            'dropped — did you forget to consume it in update()?',
          );
          return true;
        }(), 'logs unhandled commands in debug');
        return false;
    }
  }

  /// Disposes runtime resources and closes the queue.
  void dispose() {
    _cleanup();
    close();
  }
}
