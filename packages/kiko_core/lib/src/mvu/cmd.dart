import 'msg.dart';

/// Commands are side effects returned from update.
///
/// Commands tell the MVU runtime what side effects to perform.
/// Extend this class to create custom commands for widgets.
abstract class Cmd {
  /// Creates a command.
  const Cmd();
}

/// A command that can be executed asynchronously.
// ignore: one_member_abstracts
abstract interface class AsyncCmd {
  /// Executes the command and returns the resulting message.
  Future<Msg> execute();
}

/// No operation - continue the loop.
class None extends Cmd {
  /// Creates a None command.
  const None();
}

/// Quit the application with an exit code.
class Quit extends Cmd {
  /// Exit code (default 0).
  final int code;

  /// Creates a Quit command with optional exit code.
  const Quit([this.code = 0]);
}

/// Batch multiple commands together.
class Batch extends Cmd {
  /// List of commands to execute (unmodifiable).
  final List<Cmd> cmds;

  /// Creates a Batch command.
  Batch(List<Cmd> cmds) : cmds = List.unmodifiable(cmds);
}

/// Immediately queue a message for processing.
///
/// Use when update needs to trigger another message without async work.
/// The message is queued and processed in the next loop iteration.
///
/// Example:
/// ```dart
/// // Trigger a refresh after some state change
/// SomeAction() => (model.copyWith(...), Emit(RefreshRequested())),
/// ```
class Emit extends Cmd {
  /// The message to queue.
  final Msg msg;

  /// Creates an Emit command.
  const Emit(this.msg);
}

/// Request periodic tick messages.
///
/// When returned from update, the runtime will send `TickMsg` at the
/// specified interval until a `StopTick` command is issued.
class Tick extends Cmd {
  /// Interval between ticks.
  final Duration interval;

  /// Creates a Tick command.
  const Tick(this.interval);
}

/// Stop receiving tick messages.
class StopTick extends Cmd {
  /// Creates a StopTick command.
  const StopTick();
}

/// Signals that a focused model didn't handle a message.
///
/// Return this from `update()` when the model is focused but chooses not to
/// handle the message. Parent can then handle it (e.g., Tab for focus cycling,
/// global shortcuts).
///
/// Unfocused models should return `null` (ignored), not `Unhandled`.
class Unhandled extends Cmd {
  /// Creates an Unhandled command.
  const Unhandled();
}

/// Run an async operation and send a message when complete.
///
/// Example:
/// ```dart
/// // In update function
/// FetchData() => (
///   model.copyWith(loading: true),
///   Task(
///     () => http.get(url),
///     onSuccess: (response) => DataLoaded(response),
///     onError: (e) => LoadFailed(e),
///   ),
/// ),
///
/// // Fire-and-forget (analytics, logging)
/// Task(() => analytics.track('clicked'))
/// ```
///
/// Both `onSuccess` and `onError` are optional. If not provided, returns
/// `NoneMsg` for that case.
class Task<T> extends Cmd implements AsyncCmd {
  /// The async operation to run.
  final Future<T> Function() _run;

  /// Converts the result to a message. If null, returns `NoneMsg`.
  final Msg Function(T result)? _onSuccess;

  /// Converts error to a message. If null, returns `NoneMsg`.
  final Msg Function(Object error)? _onError;

  /// Creates a Task command.
  const Task(
    this._run, {
    Msg Function(T)? onSuccess,
    Msg Function(Object)? onError,
  }) : _onSuccess = onSuccess,
       _onError = onError;

  @override
  Future<Msg> execute() async {
    try {
      final result = await _run();
      return _onSuccess?.call(result) ?? const NoneMsg();
    } on Object catch (e) {
      return _onError?.call(e) ?? const NoneMsg();
    }
  }
}
