import 'dart:async';
import 'dart:io';

import 'package:kiko_log/kiko_log.dart';
import 'package:meta/meta.dart';
import 'package:plume/plume.dart' show TextMeasurer;

import '../backend/backend.dart' show Backend, ColorProfile;
import '../mvu/cmd.dart';
import '../mvu/msg.dart';
import '../mvu/mvu_runtime.dart';
import '../mvu/update_context.dart';
import '../plume/term_unicode_measurer.dart';
import '../style_resolver.dart';
import '../widgets/frame.dart';
import 'terminal.dart';

/// Error handler callback type.
///
/// Called after terminal state is restored but before `run()` completes.
/// Returns exit code to use.
typedef ErrorHandler =
    FutureOr<int> Function(
      Terminal terminal,
      Object error,
      StackTrace stack,
    );

/// Cleanup callback type. Called before `run()` completes on all paths.
typedef CleanupCallback = FutureOr<void> Function(Terminal terminal);

/// Update function for MVU: (model, msg, ctx) -> (model, cmd?)
///
/// [UpdateContext] carries what the runtime knows and the model does not — the
/// hit map and the viewport. Take it as `_` when you have no use for it.
typedef Update<M> = (M, Cmd?) Function(M model, Msg msg, UpdateContext ctx);

/// View function for MVU: render model to frame.
typedef Render<M> = void Function(M model, Frame frame);

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
///   update: (model, msg, _) => switch (msg) {
///     KeyMsg(key: 'q') => (model, const Quit()),
///     _ => (model, null),
///   },
///   view: (model, frame) => frame.render(myWidget(model)),
/// );
/// ```
///
/// For stateless demos (no model needed):
/// ```dart
/// await Application(title: 'Demo').runStateless(
///   update: (_, msg, _) => switch (msg) {
///     KeyMsg(key: 'q') => (null, const Quit()),
///     _ => (null, null),
///   },
///   view: (_, frame) => frame.render(Line('Hello')),
/// );
/// ```
class Application {
  /// The viewport to use (determines alternate screen, raw mode, cursor)
  final ViewPort viewport;

  /// Enable mouse event tracking
  final bool mouseEvents;

  /// Enable the full Kitty keyboard enhancement protocol: disambiguated
  /// escape codes plus key repeat/release events, alternate keys, and typed
  /// text — see [KeyMsg], [KeyReleaseMsg] and [ModifierKeyMsg].
  ///
  /// The enhancement only ever adds fidelity on top of the plain keyboard
  /// contract — it never changes how an existing [KeyMsg] arrives — so `null`
  /// (the default) auto-enables it: the request goes out iff the startup
  /// probe confirms the terminal supports it, and nothing changes on a
  /// terminal that fails or does not answer the probe. Pass `false` to always
  /// leave it off regardless of what the probe finds, or `true` to force the
  /// request unconditionally (today's opt-in behavior, kept as an escape
  /// hatch).
  final bool? keyboardEnhancement;

  /// Enable bracketed paste, so a paste arrives as one [PasteMsg]
  final bool bracketedPaste;

  /// Enable terminal focus reporting, so focus in/out arrives as a [FocusMsg]
  final bool focusEvents;

  /// Set terminal title
  final String? title;

  /// Show error to stderr (default: true)
  final bool showError;

  /// Default exit code on unhandled error
  final int defaultErrorCode;

  /// Custom error handler. Called after terminal restored.
  final ErrorHandler? onError;

  /// Cleanup callback. Called before `run()` completes on all paths.
  final CleanupCallback? onCleanup;

  /// Backend the terminal draws through. If null, draws on the real terminal.
  @visibleForTesting
  final Backend? backend;

  /// The width policy the terminal measures text with for the whole session.
  ///
  /// A terminal's ambiguous-width behavior does not change mid-run, so this is
  /// fixed for the life of the application and forwarded straight to
  /// [Terminal.create]: every [Frame] this app hands `view` lays out and paints
  /// with the same ruler. Defaults to [TermUnicodeMeasurer]'s narrow reading of
  /// ambiguous-width glyphs; pass `TermUnicodeMeasurer(cjk: true)` for a
  /// terminal configured for a CJK locale.
  final TextMeasurer measurer;

  /// Event polling timeout in milliseconds
  final int eventTimeout;

  /// Target frames per second for render loop.
  ///
  /// FrameTick timer fires at this rate to drive rendering.
  /// Default is 60fps (~16ms between frames).
  final int fps;

  /// Path to log file. If null, logging is disabled.
  final String? logPath;

  /// Minimum log level to record.
  final LogLevel logLevel;

  /// Log formatter (default: standard). Null means use standard formatter.
  final LogFormatter? logFormatter;

  /// Flush after every write (default: false, buffered).
  final bool logFlushPerWrite;

  Terminal? _terminal;
  StreamSubscription<ProcessSignal>? _sigintSub;
  StreamSubscription<ProcessSignal>? _sigtermSub;
  bool _disposed = false;

  // Set the instant a shutdown starts, from whichever path triggers it —
  // possibly while the drain loop in _runLoop is still running concurrently
  // (a signal, or a caller's dispose(code)). The loop checks this the moment
  // it regains control (see _runLoop) and returns without touching the
  // terminal again, since _shutdown may already be restoring or disposing it.
  bool _stopped = false;

  // The resolved keyboard-enhancement decision: whether _initTerminal actually
  // enabled it. `keyboardEnhancement` alone cannot answer this — the auto
  // (null) case depends on the backend's probe result — so teardown reads
  // this instead, to disable exactly when startup enabled and never touch
  // the terminal otherwise.
  bool _keyboardEnhancementEnabled = false;

  // The single completer `run()`'s Future<int> resolves through. `_shutdown`
  // is the only place that completes it, so every exit path — Quit, an
  // uncaught error, a signal, or a public `dispose(code)` — reports the same
  // way regardless of who triggered it.
  late Completer<int> _completer;

  // MVU runtime (lazy initialized)
  MvuRuntime? _runtime;

  /// Creates a new Application instance.
  Application({
    this.viewport = const ViewPortFullScreen(),
    this.mouseEvents = false,
    this.keyboardEnhancement,
    this.bracketedPaste = false,
    this.focusEvents = false,
    this.title,
    this.showError = true,
    this.defaultErrorCode = 1,
    this.onError,
    this.onCleanup,
    @visibleForTesting this.backend,
    this.measurer = const TermUnicodeMeasurer(),
    this.eventTimeout = 10,
    this.fps = 60,
    this.logPath,
    this.logLevel = LogLevel.info,
    this.logFormatter,
    this.logFlushPerWrite = false,
  });

  /// Runs the application with Model-View-Update architecture.
  ///
  /// [init] is the initial model state.
  /// [update] transforms model based on messages, returns (model, cmd?).
  /// [view] renders model to frame.
  ///
  /// Completes with the exit code, which [onError] may have replaced, under
  /// every backend — the framework never calls `exit()`. Terminating the
  /// process is the caller's line: `exit(await Application(...).run(...))`.
  Future<int> run<M>({
    required M init,
    required Update<M> update,
    required Render<M> view,
  }) async {
    // Create logger
    final log = logPath != null
        ? Log(
            output: FileOutput(
              logPath!,
              formatter: logFormatter ?? LogFormatter.standard,
              flushPerWrite: logFlushPerWrite,
            ),
            level: logLevel,
          )
        : Log(output: const NullOutput(), level: logLevel);

    _completer = Completer<int>();

    unawaited(
      runZonedGuarded(
        () async {
          Log.info('Application starting');
          _terminal = await Terminal.create(viewport: viewport, backend: backend, measurer: measurer);
          _initTerminal();
          _setupSignalHandlers();
          final rc = await _runLoop(init, update, view);
          await _shutdown(exitCode: rc);
        },
        (error, stackTrace) async {
          Log.error('Uncaught error', error, stackTrace);
          await _shutdown(exitCode: defaultErrorCode, error: error, stack: stackTrace);
        },
        zoneValues: {#kiko.log: log},
      ),
    );

    final exitCode = await _completer.future;
    await log.output.close();
    return exitCode;
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
    required Render<Null> view,
  }) {
    return run<Null>(
      init: null,
      update: update,
      view: view,
    );
  }

  Future<int> _runLoop<M>(M init, Update<M> update, Render<M> view) async {
    final terminal = _terminal!;
    final runtime = _runtime = MvuRuntime()
      ..reset()
      ..subscribeToEvents(terminal.events)
      // The initial draw below is now genuinely asynchronous, so an event a
      // handler emits while processing InitMsg can arrive before that draw
      // has committed a frame to stamp it against. Hold it until it has.
      ..holdEventsForFirstFrame();

    // The map a mouse event resolves against is the one that painted the cells
    // it was aimed at, so every draw hands its geometry back to the runtime.
    Future<void> draw(M model) async {
      runtime.lastHitMap = (await terminal.draw((frame) => view(model, frame))).hits;
    }

    // 1. Send InitMsg, process, render immediately (before FrameTick starts)
    final initCtx = UpdateContext(hits: runtime.lastHitMap, area: terminal.viewportArea);
    var (model, initCmd) = update(init, InitMsg(hasDarkBackground: terminal.backend.hasDarkBackground), initCtx);
    if (runtime.processCmd(initCmd)) return runtime.exitCode;
    await draw(model);
    runtime
      ..flushStartupEvents()
      // 2. Start FrameTick timer
      ..startFrameTick(fps);

    // 3. Main loop
    while (true) {
      // Coalesce pending messages (e.g. mouse moves) before processing
      runtime.coalesceQueue();

      // Get next message
      final msg = await runtime.nextMsg(timeout: eventTimeout);

      // A concurrent _shutdown (signal, dispose(code)) may have started, and
      // possibly already restored or disposed the terminal, while this await
      // was pending — stop before touching it again. nextMsg always returns
      // within eventTimeout, so this is checked promptly.
      if (_stopped) return runtime.exitCode;

      // Drop stale frames to prevent backlog
      if (runtime.isStale(msg, fps)) continue;

      // Resolve the message. A mouse event leaves the router as a routed event,
      // sometimes behind a leave or a cancel for the widget it abandons — up to
      // three messages, all reading the frame the pointer was over.
      final (:msgs, :hits) = runtime.route(msg);
      final ctx = UpdateContext(hits: hits, area: terminal.viewportArea);

      // Update model (all messages, including FrameTick)
      for (final delivered in msgs) {
        final (newModel, cmd) = update(model, delivered, ctx);
        model = newModel;

        // Process command
        if (runtime.processCmd(cmd)) return runtime.exitCode;
      }

      // Render only on FrameTick, and only for the message that was dequeued.
      if (msg is FrameTickMsg) await draw(model);
    }
  }

  void _initTerminal() {
    final terminal = _terminal!;
    // The backend's color profile is a process-wide fact known only here (the
    // theme is app-owned). Publish the matching policy once so every
    // StyleResolver a widget builds projects colors the same way this
    // terminal can actually render them.
    //
    // noColor drops color entirely, re-expressing meaning through modifiers.
    // ansi16 has only sixteen fixed, user-customized slots, so it paints
    // through the theme's named ANSI-16 table instead of guessing a nearby
    // RGB match. ansi256 and trueColor both stay on plain RGB: termlib
    // downsamples 256-indexed terminals automatically on the way out, and
    // that automatic downsample is trusted, so only the 16-color tier needs
    // the semantic table.
    StyleResolver.defaultPolicy = switch (terminal.backend.profile) {
      ColorProfile.noColor => RenderPolicy.noColor,
      ColorProfile.ansi16 => RenderPolicy.ansi16,
      ColorProfile.ansi256 || ColorProfile.trueColor => RenderPolicy.color,
    };
    if (viewport is ViewPortFullScreen) {
      terminal
        ..enableAlternateScreen()
        ..hideCursor()
        ..enableRawMode();
    }
    if (mouseEvents) terminal.enableMouseEvents();
    // null (auto) resolves against the backend's startup probe; an explicit
    // true/false always wins over it.
    _keyboardEnhancementEnabled = keyboardEnhancement ?? terminal.backend.supportsKeyboardEnhancement;
    if (_keyboardEnhancementEnabled) terminal.enableKeyboardEnhancement();
    if (bracketedPaste) terminal.enableBracketedPaste();
    if (focusEvents) terminal.enableFocusTracking();
    // Unconditional, unlike the flagged pairs above: an unsupported terminal
    // silently ignores this, and the backend self-manages the in-band/signal
    // fallback, so there is nothing for a constructor flag to gate.
    terminal.enableWindowResizeEvents();
    if (title != null) terminal.setTitle(title!);
  }

  /// Restore terminal output state (sync, just writes to stdout)
  void _restoreTerminalState() {
    final terminal = _terminal;
    if (terminal == null) return;

    if (_keyboardEnhancementEnabled) terminal.disableKeyboardEnhancement();
    if (mouseEvents) terminal.disableMouseEvents();
    if (bracketedPaste) terminal.disableBracketedPaste();
    if (focusEvents) terminal.disableFocusTracking();
    terminal.disableWindowResizeEvents();
    if (viewport is ViewPortFullScreen) {
      terminal
        ..disableRawMode()
        ..disableAlternateScreen()
        ..showCursor();
    }
  }

  /// Single shutdown path - all exits go through here.
  ///
  /// Handles normal exit, errors, signals, and a public [dispose] call
  /// uniformly. Completes [_completer] exactly once with the code the
  /// application exits with, which [onError] may have replaced, and returns
  /// that same code.
  Future<int> _shutdown({
    required int exitCode,
    Object? error,
    StackTrace? stack,
  }) async {
    // Tell a concurrently running _runLoop to stop before it touches the
    // terminal again, regardless of whether this call goes on to do the
    // shutdown work itself (see the _disposed guard right below).
    _stopped = true;

    if (_disposed) return exitCode;
    _disposed = true;

    Log.info('Application stopping (code: $exitCode)');

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

    if (!_completer.isCompleted) _completer.complete(finalCode);
    return finalCode;
  }

  void _setupSignalHandlers() {
    void handleSignal(ProcessSignal signal) {
      Log.info('Signal received: ${signal.name}');
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

  /// Clean up terminal state and complete [run]'s future with [exitCode].
  Future<void> dispose(int exitCode) => _shutdown(exitCode: exitCode);
}
