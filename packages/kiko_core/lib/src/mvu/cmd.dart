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
  /// Executes the command and returns the resulting message, or null when the
  /// outcome has no message. A null result queues nothing.
  Future<Msg?> execute();
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

  /// Creates a Batch command from [cmds], dropping any null entries.
  ///
  /// Accepting `Cmd?` lets a caller build the list from expressions that may
  /// have nothing to contribute — `Batch([cmd, for (final e in events) onEvent(e)])`
  /// — without filtering nulls itself.
  Batch(Iterable<Cmd?> cmds) : cmds = List.unmodifiable(cmds.whereType<Cmd>());
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

/// Request one `TickMsg` after [interval].
///
/// A tick is one-shot: exactly one `TickMsg` arrives, carrying [id], [key],
/// and the time elapsed since the tick was armed. An animation re-arms by
/// returning another `Tick` from its `TickMsg` case; when it stops re-arming,
/// no more ticks arrive. Several ticks may be pending at once.
///
/// [id] addresses the tick like an async result: a focus router delivers the
/// `TickMsg` to the widget registered under it, and an app-level animation
/// picks an id no widget claims so the router declines it and the app's own
/// `update` handles it. [key] is the owner's generation — bump it when the
/// animation starts or restarts, and drop a `TickMsg` whose key is stale
/// instead of re-arming, so a restart never runs two chains at once.
///
/// ```dart
/// KeyMsg(key: 'space') => (model..running = true..chain++, Tick(step, id: 'clock', key: model.chain)),
/// TickMsg(id: 'clock', :final key, :final elapsed) when key == model.chain && model.running =>
///   (model..advance(elapsed), Tick(step, id: 'clock', key: model.chain)),
/// TickMsg() => (model, null), // stale, or stopped: not re-armed
/// ```
class Tick extends Cmd {
  /// How long after arming the `TickMsg` arrives.
  final Duration interval;

  /// The stable id of the owner the `TickMsg` is addressed to.
  final String id;

  /// The owner's generation, carried back on the `TickMsg` unchanged.
  final Object? key;

  /// Creates a one-shot tick for the owner registered under [id].
  const Tick(this.interval, {required this.id, this.key});
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
/// Both `onSuccess` and `onError` are optional. An outcome with no handler
/// queues nothing.
class Task<T> extends Cmd implements AsyncCmd {
  /// The async operation to run.
  final Future<T> Function() _run;

  /// Converts the result to a message. Null queues nothing on success.
  final Msg Function(T result)? _onSuccess;

  /// Converts error to a message. Null queues nothing on failure.
  final Msg Function(Object error)? _onError;

  /// Creates a Task command.
  const Task(
    this._run, {
    Msg Function(T)? onSuccess,
    Msg Function(Object)? onError,
  }) : _onSuccess = onSuccess,
       _onError = onError;

  @override
  Future<Msg?> execute() async {
    try {
      final result = await _run();
      return _onSuccess?.call(result);
    } on Object catch (e) {
      return _onError?.call(e);
    }
  }
}
