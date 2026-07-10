import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Runs [app] to completion, quitting as soon as [update] says so.
Future<int> runApp(
  Application app, {
  required Update<int> update,
  Render<int>? view,
}) => app.run<int>(init: 0, update: update, view: view ?? (_, _) {});

/// An update that quits with [code] the moment the application starts.
Update<int> quitOnInit([int code = 0]) =>
    (model, msg) => (model, msg is InitMsg ? Quit(code) : null);

void main() {
  late TestBackend backend;

  setUp(() {
    backend = TestBackend(size: const TermSize(8, 2));
    // _initTerminal publishes the policy process-wide; put it back afterwards.
    final policy = StyleResolver.defaultPolicy;
    addTearDown(() => StyleResolver.defaultPolicy = policy);
  });

  group('color profile projection', () {
    test('a noColor backend puts every resolver on the noColor policy', () async {
      backend.profile = ColorProfile.noColor;

      await runApp(Application(backend: backend), update: quitOnInit());

      expect(StyleResolver.defaultPolicy, RenderPolicy.noColor);
    });

    test('a color backend leaves the color policy in place', () async {
      backend.profile = ColorProfile.ansi16;

      await runApp(Application(backend: backend), update: quitOnInit());

      expect(StyleResolver.defaultPolicy, RenderPolicy.color);
    });
  });

  group('terminal setup and restore', () {
    test('enables the requested modes on the way in and restores them on the way out', () async {
      late final bool altOnInit;
      late final bool rawOnInit;
      late final bool mouseOnInit;
      late final bool cursorOnInit;

      final app = Application(
        backend: backend,
        title: 'demo',
        mouseEvents: true,
        keyboardEnhancement: true,
        bracketedPaste: true,
        focusEvents: true,
      );

      await runApp(
        app,
        update: (model, msg) {
          if (msg is InitMsg) {
            altOnInit = backend.alternateScreen;
            rawOnInit = backend.rawMode;
            mouseOnInit = backend.mouseEvents;
            cursorOnInit = backend.cursorVisible;
          }
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(altOnInit, isTrue);
      expect(rawOnInit, isTrue);
      expect(mouseOnInit, isTrue);
      expect(cursorOnInit, isFalse, reason: 'a full screen app hides the cursor');
      expect(backend.title, 'demo');

      expect(backend.alternateScreen, isFalse);
      expect(backend.rawMode, isFalse);
      expect(backend.mouseEvents, isFalse);
      expect(backend.keyboardEnhancement, isFalse);
      expect(backend.bracketedPaste, isFalse);
      expect(backend.focusTracking, isFalse);
      expect(backend.cursorVisible, isTrue);
    });
  });

  group('the exit path', () {
    test('a Quit code is returned and handed to the backend', () async {
      final rc = await runApp(Application(backend: backend), update: quitOnInit(3));

      expect(rc, 3);
      expect(backend.exitCode, 3);
      expect(backend.disposed, isTrue);
    });

    test('cleanup runs after the terminal is restored and before it is disposed', () async {
      late final bool rawDuringCleanup;
      late final bool disposedDuringCleanup;

      final app = Application(
        backend: backend,
        onCleanup: (_) {
          rawDuringCleanup = backend.rawMode;
          disposedDuringCleanup = backend.disposed;
        },
      );

      await runApp(app, update: quitOnInit());

      expect(rawDuringCleanup, isFalse, reason: 'raw mode is already restored');
      expect(disposedDuringCleanup, isFalse, reason: 'the terminal is still alive');
      expect(backend.disposed, isTrue);
    });

    test('quitting on the init message returns before anything is drawn', () async {
      var views = 0;

      await runApp(
        Application(backend: backend),
        update: quitOnInit(),
        view: (_, _) => views++,
      );

      expect(views, 0);
      expect(backend.drawCount, 0);
    });
  });

  group('the drain loop', () {
    test('renders on the init message and then on every frame tick', () async {
      var ticks = 0;
      var views = 0;

      final rc = await runApp(
        Application(backend: backend),
        update: (model, msg) {
          if (msg is! FrameTickMsg) return (model, null);
          ticks++;
          return (model, ticks == 2 ? const Quit() : null);
        },
        view: (_, _) => views++,
      );

      expect(rc, 0);
      expect(views, 2, reason: 'the init draw, then one render for the first tick');
      expect(backend.drawCount, 2, reason: 'the second tick quits before rendering');
    });

    test('an event emitted by the backend reaches update as a message', () async {
      String? seenKey;

      final rc = await runApp(
        Application(backend: backend),
        update: (model, msg) {
          switch (msg) {
            case InitMsg():
              backend.emit(const KeyEvent(KeyCode.char('q')));
              return (model, null);
            case KeyMsg(:final key):
              seenKey = key;
              return (model, const Quit(5));
            default:
              return (model, null);
          }
        },
      );

      expect(seenKey, 'q');
      expect(rc, 5);
    });
  });

  group('the error path', () {
    test('onError sees the failure and its code reaches the backend', () async {
      Object? seenError;

      final app = Application(
        backend: backend,
        showError: false,
        onError: (_, error, _) {
          seenError = error;
          return 7;
        },
      );

      final rc = await runApp(app, update: (_, _) => throw StateError('boom'));

      expect(seenError, isA<StateError>());
      expect(backend.exitCode, 7, reason: 'the process would exit with the handler code');
      expect(
        rc,
        1,
        reason: 'run() returns defaultErrorCode, not the onError code — see note 0154',
      );
      expect(backend.rawMode, isFalse, reason: 'the terminal is restored even on the error path');
      expect(backend.disposed, isTrue);
    });
  });
}
