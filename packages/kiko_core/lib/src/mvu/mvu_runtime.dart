import 'dart:async';
import 'dart:collection';

import 'package:termparser/termparser_events.dart';

import 'cmd.dart';
import 'msg.dart';

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
/// Uses unified stream architecture where all event sources (terminal events,
/// ticks, async tasks) push to the same queue in FIFO order.
class MvuRuntime {
  final Queue<Msg> _msgQueue = Queue<Msg>();
  Timer? _tickTimer;
  Timer? _frameTickTimer;
  _CancellationToken _token = _CancellationToken();

  // Frame timing
  DateTime _lastFrameTime = DateTime.now();
  int _frameNumber = 0;

  /// Subscription to terminal events stream.
  StreamSubscription<Event>? _eventSubscription;

  /// Exit code set by Quit command.
  int exitCode = 0;

  /// Completer for wake-up signaling.
  Completer<void> _wakeUp = Completer<void>();

  /// Callback when message queued (signals wake-up).
  final OnMsgQueued? _onMsgQueued;

  /// Creates a new MVU runtime.
  MvuRuntime({OnMsgQueued? onMsgQueued}) : _onMsgQueued = onMsgQueued;

  /// Resets runtime state for a new run.
  void reset() {
    exitCode = 0;
    _msgQueue.clear();
    _wakeUp = Completer<void>();
    _tickTimer?.cancel();
    _tickTimer = null;
    _frameTickTimer?.cancel();
    _frameTickTimer = null;
    _lastFrameTime = DateTime.now();
    _frameNumber = 0;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    _token = _CancellationToken();
  }

  /// Subscribes to terminal events stream.
  ///
  /// All terminal events are converted to messages and queued in FIFO order
  /// along with ticks and async task results.
  void subscribeToEvents(Stream<Event> events) {
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = events.listen((event) {
      queueMsg(eventToMsg(event));
    });
  }

  /// Queues a message and signals wake-up.
  void queueMsg(Msg msg) {
    _msgQueue.add(msg);
    _signalWakeUp();
  }

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

  /// Gets next message from the unified queue.
  ///
  /// All event sources (terminal events, ticks, async tasks) push to the same
  /// queue in FIFO order, providing fair interleaving without starvation.
  ///
  /// Returns immediately if message available, otherwise waits for wake-up
  /// signal or timeout.
  Future<Msg> nextMsg({required int timeout}) async {
    // Check queue first
    if (_msgQueue.isNotEmpty) {
      return _msgQueue.removeFirst();
    }

    // Wait for message or timeout
    await Future.any([
      _wakeUp.future,
      Future<void>.delayed(Duration(milliseconds: timeout)),
    ]);

    // Reset wake-up for next round
    _resetWakeUp();

    // Return message if available, otherwise NoneMsg
    if (_msgQueue.isNotEmpty) {
      return _msgQueue.removeFirst();
    }
    return const NoneMsg();
  }

  /// Starts the frame tick timer at the specified fps.
  ///
  /// FrameTick is internal and drives the render loop.
  /// This is separate from user [Tick] timers.
  void startFrameTick(int fps) {
    _frameTickTimer?.cancel();
    _lastFrameTime = DateTime.now();
    _frameNumber = 0;

    final interval = Duration(milliseconds: (1000 / fps).round());
    _frameTickTimer = Timer.periodic(interval, (_) {
      final now = DateTime.now();
      final delta = now.difference(_lastFrameTime);
      _lastFrameTime = now;
      _frameNumber++;

      queueMsg(
        FrameTickMsg(
          delta: delta,
          frameNumber: _frameNumber,
          timestamp: now,
        ),
      );
    });
  }

  /// Stops the frame tick timer.
  void stopFrameTick() {
    _frameTickTimer?.cancel();
    _frameTickTimer = null;
  }

  /// Checks if a message is stale and should be dropped.
  ///
  /// Droppable messages (e.g. FrameTickMsg) are stale when older than
  /// 2 frame intervals. This prevents rendering backlog from building up.
  bool isStale(Msg msg, int fps) {
    if (!msg.droppable) return false;
    if (msg is! FrameTickMsg) return false;
    // Stale = older than 2 frame intervals
    final threshold = Duration(milliseconds: (1000 / fps * 2).round());
    return DateTime.now().difference(msg.timestamp) > threshold;
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

  /// Cancels timers and subscriptions.
  void _cleanup() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _frameTickTimer?.cancel();
    _frameTickTimer = null;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
  }

  /// Process command, returns true if should exit.
  bool processCmd(Cmd? cmd) {
    switch (cmd) {
      case null:
      case None():
      case Unhandled():
        return false;
      case Quit(:final code):
        _token.cancel();
        exitCode = code;
        _cleanup();
        return true;
      case Tick(:final interval):
        _tickTimer?.cancel();
        final stopwatch = Stopwatch()..start();
        _tickTimer = Timer.periodic(interval, (_) {
          queueMsg(TickMsg(stopwatch.elapsed));
        });
        return false;
      case StopTick():
        _tickTimer?.cancel();
        _tickTimer = null;
        return false;
      case Emit(:final msg):
        queueMsg(msg);
        return false;
      case final AsyncCmd task:
        final token = _token; // Capture current token
        unawaited(
          task.execute().then((msg) {
            if (!token.isCancelled) queueMsg(msg);
          }),
        );
        return false;
      case Batch(:final cmds):
        for (final c in cmds) {
          if (processCmd(c)) return true;
        }
        return false;
      default:
        // Custom commands from widgets - not handled by runtime
        return false;
    }
  }

  /// Disposes runtime resources.
  void dispose() => _cleanup();
}
