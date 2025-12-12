import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart';

import '../mvu/cmd.dart';
import '../mvu/msg.dart';
import '../mvu/mvu_runtime.dart';
import '../widgets/frame.dart';
import 'terminal.dart';

/// Error handler callback type.
///
/// Called after terminal state is restored but before exit.
/// Returns exit code to use.
typedef ErrorHandler =
    FutureOr<int> Function(
      Terminal terminal,
      Object error,
      StackTrace stack,
    );

/// Exit callback type for testing. Replaces `flushThenExit`.
typedef ExitCallback = Future<void> Function(Terminal terminal, int exitCode);

/// Cleanup callback type. Called before exit on all paths.
typedef CleanupCallback = FutureOr<void> Function(Terminal terminal);

/// Update function for MVU: (model, msg) -> (model, cmd?)
typedef Update<M> = (M, Cmd?) Function(M model, Msg msg);

/// View function for MVU: render model to frame
typedef View<M> = void Function(M model, Frame frame);

const _baseError = 128;
const int _sigInt = _baseError + 2;
const int _sigTerm = _baseError + 15;

/// Application class handles terminal initialization, main loop, and cleanup.
///
/// Provides automatic cleanup on normal exit, errors, and signals (SIGINT/SIGTERM).
///
/// Uses Model-View-Update (MVU) architecture:
/// ```dart
/// await Application(title: 'Counter').run(
///   init: CounterModel(),
///   update: (model, msg) => switch (msg) {
///     KeyMsg(key: KeyEvent(code: KeyCode(char: 'q'))) => (model, Quit()),
///     _ => (model, null),
///   },
///   view: (model, frame) => frame.renderWidget(Text('Count: ${model.count}')),
/// );
/// ```
///
/// For stateless demos (no model needed):
/// ```dart
/// await Application(title: 'Demo').runStateless(
///   update: (_, msg) => switch (msg) {
///     KeyMsg(key: KeyEvent(code: KeyCode(char: 'q'))) => (null, Quit()),
///     _ => (null, null),
///   },
///   view: (_, frame) => frame.renderWidget(Text('Hello')),
/// );
/// ```
class Application {
  /// The viewport to use (determines alternate screen, raw mode, cursor)
  final ViewPort viewport;

  /// Enable mouse event tracking
  final bool mouseEvents;

  /// Enable Kitty keyboard enhancement protocol
  final bool keyboardEnhancement;

  /// Set terminal title
  final String? title;

  /// Show error to stderr (default: true)
  final bool showError;

  /// Default exit code on unhandled error
  final int defaultErrorCode;

  /// Custom error handler. Called after terminal restored.
  final ErrorHandler? onError;

  /// Cleanup callback. Called before exit on all paths.
  final CleanupCallback? onCleanup;

  /// Exit callback for testing. If null, uses `flushThenExit`.
  @visibleForTesting
  final ExitCallback? exitCallback;

  /// Event polling timeout in milliseconds
  final int eventTimeout;

  Terminal? _terminal;
  StreamSubscription<ProcessSignal>? _sigintSub;
  StreamSubscription<ProcessSignal>? _sigtermSub;
  bool _disposed = false;

  // MVU runtime (lazy initialized)
  MvuRuntime? _runtime;

  /// Creates a new Application instance.
  Application({
    this.viewport = const ViewPortFullScreen(),
    this.mouseEvents = false,
    this.keyboardEnhancement = false,
    this.title,
    this.showError = true,
    this.defaultErrorCode = 1,
    this.onError,
    this.onCleanup,
    @visibleForTesting this.exitCallback,
    this.eventTimeout = 10,
  });

  /// Runs the application with Model-View-Update architecture.
  ///
  /// [init] is the initial model state.
  /// [update] transforms model based on messages, returns (model, cmd?).
  /// [view] renders model to frame.
  Future<int> run<M>({
    required M init,
    required Update<M> update,
    required View<M> view,
  }) async {
    final exitValue = await runZonedGuarded(
      () async {
        _terminal = await Terminal.create(viewport: viewport);
        _initTerminal();
        _setupSignalHandlers();
        final rc = await _runLoop(init, update, view);
        await _shutdown(exitCode: rc);
        return rc;
      },
      (error, stackTrace) async {
        await _shutdown(exitCode: defaultErrorCode, error: error, stack: stackTrace);
      },
    );

    return exitValue ?? _baseError;
  }

  /// Runs the application without model state.
  ///
  /// Convenience method for demos and examples that don't need state management.
  /// Uses `Null` as model type internally.
  ///
  /// [update] handles messages and returns commands. Model is always null.
  /// [view] renders to frame. Model param is always null, use `_` to ignore.
  Future<int> runStateless({
    required Update<Null> update,
    required View<Null> view,
  }) {
    return run<Null>(
      init: null,
      update: update,
      view: view,
    );
  }

  Future<int> _runLoop<M>(
    M init,
    Update<M> update,
    View<M> view,
  ) async {
    final terminal = _terminal!;
    final runtime = _runtime = MvuRuntime();
    final eventSource = _TerminalEventSource(terminal);

    runtime.reset();

    // Send InitMsg to allow initial commands
    var (model, initCmd) = update(init, const InitMsg());
    if (runtime.processCmd(initCmd)) return runtime.exitCode;

    while (true) {
      // 1. Render
      terminal.draw((frame) => view(model, frame));

      // 2. Get next message
      final msg = await runtime.nextMsg(eventSource, timeout: eventTimeout);

      // 3. Update
      final (newModel, cmd) = update(model, msg);
      model = newModel;

      // 4. Process command
      if (runtime.processCmd(cmd)) return runtime.exitCode;
    }
  }

  void _initTerminal() {
    final terminal = _terminal!;
    if (viewport is ViewPortFullScreen) {
      terminal
        ..enableAlternateScreen()
        ..hideCursor()
        ..enableRawMode();
    }
    if (mouseEvents) terminal.enableMouseEvents();
    if (keyboardEnhancement) terminal.enableKeyboardEnhancement();
    if (title != null) terminal.setTitle(title!);
  }

  /// Restore terminal output state (sync, just writes to stdout)
  void _restoreTerminalState() {
    final terminal = _terminal;
    if (terminal == null) return;

    if (keyboardEnhancement) terminal.disableKeyboardEnhancement();
    if (mouseEvents) terminal.disableMouseEvents();
    if (viewport is ViewPortFullScreen) {
      terminal
        ..disableRawMode()
        ..disableAlternateScreen()
        ..showCursor();
    }
  }

  /// Single shutdown path - all exits go through here.
  ///
  /// Handles normal exit, errors, and signals uniformly.
  Future<void> _shutdown({
    required int exitCode,
    Object? error,
    StackTrace? stack,
  }) async {
    if (_disposed) return;
    _disposed = true;

    _runtime?.dispose();

    await _cancelSignalHandlers();

    _restoreTerminalState();

    if (error != null && showError) {
      stderr
        ..writeln('Error: $error')
        ..writeln(stack);
    }

    await _runCleanup();

    var finalCode = exitCode;
    if (error != null && _terminal != null && onError != null) {
      finalCode = await onError!(_terminal!, error, stack!);
    }

    await _terminal?.dispose();
    await _exit(finalCode);
  }

  void _setupSignalHandlers() {
    void handleSignal(ProcessSignal signal) {
      // Signal exit code: 128 + signal number
      final code = signal == ProcessSignal.sigint ? _sigInt : _sigTerm;
      unawaited(_shutdown(exitCode: code));
    }

    _sigintSub = ProcessSignal.sigint.watch().listen(handleSignal);

    // SIGTERM not available on Windows
    if (!Platform.isWindows) {
      _sigtermSub = ProcessSignal.sigterm.watch().listen(handleSignal);
    }
  }

  Future<void> _runCleanup() async {
    try {
      if (onCleanup != null && _terminal != null) {
        await onCleanup!(_terminal!);
      }
    } on Object catch (e) {
      stderr.writeln('Cleanup error: $e');
    }
  }

  Future<void> _cancelSignalHandlers() async {
    await _sigintSub?.cancel();
    await _sigtermSub?.cancel();
    _sigintSub = null;
    _sigtermSub = null;
  }

  Future<void> _exit(int exitCode) async {
    final terminal = _terminal;
    if (exitCallback != null && terminal != null) {
      await exitCallback!(terminal, exitCode);
    } else {
      await terminal?.flushThenExit(exitCode);
    }
  }

  /// Clean up terminal state and exit.
  Future<void> dispose(int exitCode) => _shutdown(exitCode: exitCode);
}

/// Adapter to make Terminal implement EventSource.
class _TerminalEventSource implements EventSource {
  final Terminal _terminal;

  _TerminalEventSource(this._terminal);

  @override
  Event poll() => _terminal.poll<Event>();

  @override
  Future<Event> readEvent({required int timeout}) => _terminal.readEvent<Event>(timeout: timeout);
}
