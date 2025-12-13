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

/// Abstract event source for MVU runtime.
///
/// Allows injecting test implementations that don't require a real terminal.
abstract interface class EventSource {
  /// Polls for event without blocking. Returns [NoneEvent] if none available.
  Event poll();

  /// Reads event with timeout. Returns [NoneEvent] on timeout.
  Future<Event> readEvent({required int timeout});
}

/// Callback when a message is queued (for wake-up signaling).
typedef OnMsgQueued = void Function();

/// MVU runtime handles command processing and message queue management.
class MvuRuntime {
  final Queue<Msg> _msgQueue = Queue<Msg>();
  Timer? _tickTimer;
  _CancellationToken _token = _CancellationToken();

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
    _token = _CancellationToken();
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
  void resetWakeUp() {
    if (_wakeUp.isCompleted) {
      _wakeUp = Completer<void>();
    }
  }

  /// Returns the wake-up future for awaiting.
  Future<void> get wakeUpFuture => _wakeUp.future;

  /// Gets next message from queue, poll, or wait.
  ///
  /// Priority order:
  /// 1. Queued messages (from Tasks, Ticks)
  /// 2. Polled terminal events (sync check)
  /// 3. Wait for terminal event or wake-up signal
  ///
  /// ## Starvation Warning
  ///
  /// Queued messages always have priority over terminal events. This means:
  /// - A very fast [Tick] (e.g., <10ms) could starve keyboard/mouse input
  /// - Use reasonable tick intervals (≥100ms for animations, ≥1000ms for clocks)
  ///
  /// Note: Simply reversing the priority (terminal first) would cause the
  /// opposite problem - rapid mouse movements could starve tick/task messages.
  ///
  /// ## Future Improvement
  ///
  /// True fair interleaving requires a unified event stream where all sources
  /// (terminal, ticks, tasks) push to the same queue ordered by arrival time.
  /// This needs a new broadcast stream API in termlib (can't reuse internal
  /// onEvent - it would break read()/pollTimeout()).
  /// See specs/model_view_update.md "Future: Fair Event Scheduling" for details.
  Future<Msg> nextMsg(EventSource source, {required int timeout}) async {
    while (true) {
      // 1. Check queue (Tasks, Ticks)
      if (_msgQueue.isNotEmpty) {
        return _msgQueue.removeFirst();
      }

      // 2. Check terminal events (sync, no wait)
      final peek = source.poll();
      if (peek is! NoneEvent) {
        return eventToMsg(peek);
      }

      // 3. Wait for terminal event OR wake-up signal
      final readFuture = source.readEvent(timeout: timeout);
      await Future.any([readFuture, _wakeUp.future]);

      // Reset wake-up for next round
      resetWakeUp();

      // Always await readFuture to prevent losing events
      final event = await readFuture;
      return eventToMsg(event);
    }
  }

  /// Process command, returns true if should exit.
  bool processCmd(Cmd? cmd) {
    switch (cmd) {
      case null:
      case None():
        return false;
      case Quit(:final code):
        _token.cancel();
        exitCode = code;
        _tickTimer?.cancel();
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
        unawaited(task.execute().then((msg) {
          if (!token.isCancelled) queueMsg(msg);
        }));
        return false;
      case Batch(:final cmds):
        for (final c in cmds) {
          if (processCmd(c)) return true;
        }
        return false;
    }
  }

  /// Disposes runtime resources.
  void dispose() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }
}
