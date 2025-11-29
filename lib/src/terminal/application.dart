import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart';

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

/// Event handler callback type. Returns exit code or null to continue.
typedef EventHandler = int? Function(Event event);

const _baseError = 128;
const int _sigInt = _baseError + 2;
const int _sigTerm = _baseError + 15;

/// Application class handles terminal initialization, main loop, and cleanup.
///
/// Provides automatic cleanup on normal exit, errors, and signals (SIGINT/SIGTERM).
///
/// Example:
/// ```dart
/// final exitCode = await Application(
///   mouseEvents: true,
///   title: 'My App',
/// ).run(
///   render: (frame) {
///     frame.renderWidget(myWidget);
///   },
///   onEvent: (event) {
///     if (event is KeyEvent && event.code.char == 'q') return 0;
///     return null; // continue
///   },
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

  /// Runs the application main loop.
  ///
  /// [render] is called each frame to draw widgets.
  /// [onEvent] is called when an event is received. Return exit code to stop,
  /// or null to continue.
  Future<int> run({
    required WidgetRenderCallback render,
    required EventHandler onEvent,
  }) async {
    final exitValue = await runZonedGuarded(
      () async {
        _terminal = await Terminal.create(viewport: viewport);
        _initTerminal();
        _setupSignalHandlers();
        final rc = await _runLoop(render, onEvent);
        await dispose(rc);
        return rc;
      },
      (error, stackTrace) async {
        await _handleError(error, stackTrace);
      },
    );

    return exitValue ?? _baseError;
  }

  Future<int> _runLoop(
    WidgetRenderCallback render,
    EventHandler onEvent,
  ) async {
    final terminal = _terminal!;
    while (true) {
      terminal.draw(render);
      final event = await terminal.readEvent<Event>(timeout: eventTimeout);
      final exitCode = onEvent(event);
      if (exitCode != null) return exitCode;
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

  Future<void> _handleError(Object error, StackTrace stack) async {
    final terminal = _terminal;
    await _cancelSignalHandlers();
    _restoreTerminalState();
    _disposed = true;

    if (showError) {
      stderr
        ..writeln('Error: $error')
        ..writeln(stack);
    }

    await _runCleanup();

    final exitCode = terminal != null && onError != null ? await onError!(terminal, error, stack) : defaultErrorCode;

    await _exit(exitCode);
  }

  void _setupSignalHandlers() {
    void handleSignal(ProcessSignal signal) {
      if (_disposed) return;
      _disposed = true;

      // Restore terminal immediately (sync)
      _restoreTerminalState();

      // Signal exit code: 128 + signal number
      final code = signal == ProcessSignal.sigint ? _sigInt : _sigTerm;

      // Run cleanup then exit
      unawaited(_runCleanupAndExit(code));
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

  Future<void> _runCleanupAndExit(int code) async {
    await _runCleanup();
    await _terminal?.dispose();
    await _exit(code);
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

  /// Clean up terminal state and exit
  Future<void> dispose(int exitCode) async {
    if (_disposed) return;
    _disposed = true;

    await _cancelSignalHandlers();
    _restoreTerminalState();
    await _terminal?.dispose();
    await _runCleanup();
    await _exit(exitCode);
  }
}
