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
    (model, msg, _) => (model, msg is InitMsg ? Quit(code) : null);

/// The key [quitOnKey] quits on, emitted by [quitAfterFirstFrame].
const quitKey = 'q';

/// An update that quits with [code] when [quitKey] arrives.
Update<int> quitOnKey([int code = 0]) =>
    (model, msg, _) => (model, msg is KeyMsg && msg.key == quitKey ? Quit(code) : null);

/// A frame callback that emits [quitKey] on [backend] from the first committed
/// frame, so the application paints once and then stops.
FrameCallback quitAfterFirstFrame(TestBackend backend) => (frame) {
  if (frame.count == 0) backend.emitKey(quitKey);
};

/// A view whose one widget fills the viewport and answers to the id `ok`.
void tagWholeArea(int _, Frame frame) =>
    frame.render(Tagged('ok', Container(border: BorderType.plain, child: Line(''))));

/// A report carrying one number: the shape a widget's own kind takes.
class _Rows extends FrameReport {
  const _Rows(super.id, this.rows);

  final int rows;
}

/// A leaf that fills its box and appends [reports] when painted.
class _Reporter extends Node implements View {
  _Reporter(this.reports);

  /// What this leaf reports each time it paints.
  final List<FrameReport> reports;

  @override
  Node build() => this;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.biggest;

  @override
  void paintSelf(Surface surface) {
    if (surface is BufferSurface) reports.forEach(surface.report);
  }
}

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

    test('an ansi16 backend puts every resolver on the ansi16 policy', () async {
      backend.profile = ColorProfile.ansi16;

      await runApp(Application(backend: backend), update: quitOnInit());

      expect(StyleResolver.defaultPolicy, RenderPolicy.ansi16);
    });

    test('an ansi256 backend leaves the color policy in place', () async {
      backend.profile = ColorProfile.ansi256;

      await runApp(Application(backend: backend), update: quitOnInit());

      expect(StyleResolver.defaultPolicy, RenderPolicy.color);
    });

    test('a trueColor backend leaves the color policy in place', () async {
      backend.profile = ColorProfile.trueColor;

      await runApp(Application(backend: backend), update: quitOnInit());

      expect(StyleResolver.defaultPolicy, RenderPolicy.color);
    });
  });

  group('hasDarkBackground', () {
    test('threads a dark answer from the backend into InitMsg', () async {
      backend.hasDarkBackground = true;
      bool? seen;

      await runApp(
        Application(backend: backend),
        update: (model, msg, _) {
          if (msg is InitMsg) seen = msg.hasDarkBackground;
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(seen, isTrue);
    });

    test('threads a light answer from the backend into InitMsg', () async {
      backend.hasDarkBackground = false;
      bool? seen;

      await runApp(
        Application(backend: backend),
        update: (model, msg, _) {
          if (msg is InitMsg) seen = msg.hasDarkBackground;
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(seen, isFalse);
    });

    test('threads an unanswered probe into InitMsg as null', () async {
      backend.hasDarkBackground = null;
      var seenCount = 0;
      bool? seen;

      await runApp(
        Application(backend: backend),
        update: (model, msg, _) {
          if (msg is InitMsg) {
            seen = msg.hasDarkBackground;
            seenCount++;
          }
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(seenCount, 1);
      expect(seen, isNull);
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
        update: (model, msg, _) {
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

    test('enables window-resize reporting on the way in with no constructor flag, and '
        'restores it on the way out', () async {
      late final bool resizeOnInit;

      // No windowEvents-style flag exists on Application at all — unlike
      // mouseEvents/keyboardEnhancement/bracketedPaste/focusEvents above, this
      // mode is unconditional.
      final app = Application(backend: backend);

      await runApp(
        app,
        update: (model, msg, _) {
          if (msg is InitMsg) resizeOnInit = backend.windowResizeEvents;
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(resizeOnInit, isTrue);
      expect(backend.windowResizeEvents, isFalse, reason: 'restored on the way out');
    });
  });

  group('keyboard enhancement auto-resolution', () {
    test('auto (null) enables it at startup and disables it at teardown when the backend '
        'reports support', () async {
      backend.supportsKeyboardEnhancement = true;
      late final bool enabledOnInit;

      final app = Application(backend: backend);

      await runApp(
        app,
        update: (model, msg, _) {
          if (msg is InitMsg) enabledOnInit = backend.keyboardEnhancement;
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(enabledOnInit, isTrue);
      expect(backend.enableKeyboardEnhancementCount, 1);
      expect(backend.keyboardEnhancement, isFalse, reason: 'restored on the way out');
      expect(backend.disableKeyboardEnhancementCount, 1);
    });

    test('auto (null) never enables it, and touches nothing at teardown, when the backend '
        'reports no support', () async {
      // backend.supportsKeyboardEnhancement defaults to false.
      late final bool enabledOnInit;

      final app = Application(backend: backend);

      await runApp(
        app,
        update: (model, msg, _) {
          if (msg is InitMsg) enabledOnInit = backend.keyboardEnhancement;
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(enabledOnInit, isFalse);
      expect(backend.enableKeyboardEnhancementCount, 0);
      expect(backend.disableKeyboardEnhancementCount, 0, reason: 'teardown never touches the terminal');
    });

    test('explicit false never enables it even when the backend reports support', () async {
      backend.supportsKeyboardEnhancement = true;
      late final bool enabledOnInit;

      final app = Application(backend: backend, keyboardEnhancement: false);

      await runApp(
        app,
        update: (model, msg, _) {
          if (msg is InitMsg) enabledOnInit = backend.keyboardEnhancement;
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(enabledOnInit, isFalse);
      expect(backend.enableKeyboardEnhancementCount, 0);
      expect(backend.disableKeyboardEnhancementCount, 0, reason: 'teardown never touches the terminal');
    });

    test('explicit true forces it on even when the backend reports no support, and it is '
        'still disabled at teardown', () async {
      // backend.supportsKeyboardEnhancement defaults to false.
      late final bool enabledOnInit;

      final app = Application(backend: backend, keyboardEnhancement: true);

      await runApp(
        app,
        update: (model, msg, _) {
          if (msg is InitMsg) enabledOnInit = backend.keyboardEnhancement;
          return (model, msg is InitMsg ? const Quit() : null);
        },
      );

      expect(enabledOnInit, isTrue);
      expect(backend.enableKeyboardEnhancementCount, 1);
      expect(backend.keyboardEnhancement, isFalse, reason: 'restored on the way out');
      expect(backend.disableKeyboardEnhancementCount, 1);
    });
  });

  group('the exit path', () {
    test('a Quit code is returned', () async {
      final rc = await runApp(Application(backend: backend), update: quitOnInit(3));

      expect(rc, 3);
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

  group('external shutdown while the loop is running', () {
    // A real signal drives the same `_shutdown` call `dispose(code)` does —
    // see application.dart's `_setupSignalHandlers`. Self-sending SIGINT is
    // not exercised here: it proved unreliable under the `dart test` runner
    // (the watcher registered in-process never observed it), so this covers
    // the shared mechanism through the public entry point instead.
    test('dispose(code) completes run() with that code', () async {
      final app = Application(backend: backend);
      final runFuture = runApp(app, update: (model, _, _) => (model, null));

      // Let the app clear init and settle into the drain loop.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await app.dispose(9);

      expect(await runFuture, 9);
      expect(backend.disposed, isTrue);
    });

    test('the loop stops drawing once shutdown has started', () async {
      final app = Application(backend: backend);
      final runFuture = runApp(app, update: (model, _, _) => (model, null));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final drawsBeforeDispose = backend.drawCount;

      await app.dispose(0);
      await runFuture;

      // A couple more frame intervals: if the loop were still drawing, this
      // would catch it.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        backend.drawCount,
        drawsBeforeDispose,
        reason: 'shutdown restored/disposed the terminal; the loop must not touch it again',
      );
    });
  });

  group('the drain loop', () {
    test('renders on the init message and then on every frame tick', () async {
      var frames = 0;
      var views = 0;

      final rc = await runApp(
        Application(
          backend: backend,
          onFrame: (_) {
            frames++;
            if (frames == 2) backend.emitKey(quitKey);
          },
        ),
        update: quitOnKey(),
        view: (_, _) => views++,
      );

      expect(rc, 0);
      expect(views, 2, reason: 'the init draw, then one render for the first tick');
      expect(backend.drawCount, 2, reason: 'the quit key arrives before the next tick renders');
    });

    test('an event emitted by the backend reaches update as a message', () async {
      String? seenKey;

      final rc = await runApp(
        Application(backend: backend),
        update: (model, msg, _) {
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

    test('a resize emitted after the first frame reaches update as a ResizeMsg', () async {
      ResizeMsg? seenResize;

      final rc = await runApp(
        // The first frame commits inside the startup hold, where a
        // WindowResizeEvent is startup noise and is dropped, never queued. A
        // nudge key crosses the hold; the resize goes out once update sees it.
        Application(backend: backend, onFrame: (frame) => frame.count == 0 ? backend.emitKey('n') : null),
        update: (model, msg, _) {
          switch (msg) {
            case KeyMsg(key: 'n'):
              backend.emit(const WindowResizeEvent(30, 100, 640, 2000));
              return (model, null);
            case ResizeMsg():
              seenResize = msg;
              return (model, const Quit());
            default:
              return (model, null);
          }
        },
      );

      expect(rc, 0);
      expect(seenResize, isNotNull);
      expect(seenResize!.width, 100);
      expect(seenResize!.height, 30);
      expect(seenResize!.widthPixels, 2000);
      expect(seenResize!.heightPixels, 640);
    });
  });

  group('the update context', () {
    test('the init turn hit-tests an empty map, because nothing is painted yet', () async {
      late final String? hit;
      late final List<Hit> path;

      await runApp(
        Application(backend: backend),
        update: (model, msg, ctx) {
          if (msg is InitMsg) {
            hit = ctx.hits.hitId(0, 0);
            path = ctx.hits.hitPath(0, 0);
          }
          return (model, msg is InitMsg ? const Quit() : null);
        },
        view: tagWholeArea,
      );

      expect(hit, isNull);
      expect(path, isEmpty);
    });

    test('every later turn hit-tests the frame that was last committed', () async {
      late final String? hit;
      late final Rect? rect;

      await runApp(
        Application(backend: backend, onFrame: quitAfterFirstFrame(backend)),
        update: (model, msg, ctx) {
          if (msg is! KeyMsg) return (model, null);
          hit = ctx.hits.hitId(3, 1);
          rect = ctx.hits.rectOf('ok');
          return (model, const Quit());
        },
        view: tagWholeArea,
      );

      expect(hit, 'ok', reason: 'the draw that followed the init message committed the tag');
      expect(rect, Rect.create(x: 0, y: 0, width: 8, height: 2));
    });

    test('area is the viewport the application owns, not the whole terminal', () async {
      final fixed = Rect.create(x: 1, y: 0, width: 4, height: 2);
      late final Rect areaOnInit;
      late final Rect areaAfterFrame;

      await runApp(
        Application(backend: backend, viewport: ViewPortFixed(fixed), onFrame: quitAfterFirstFrame(backend)),
        update: (model, msg, ctx) {
          switch (msg) {
            case InitMsg():
              areaOnInit = ctx.area;
              return (model, null);
            case KeyMsg():
              areaAfterFrame = ctx.area;
              return (model, const Quit());
            default:
              return (model, null);
          }
        },
      );

      expect(areaOnInit, fixed, reason: 'the viewport is known before the first draw');
      expect(areaAfterFrame, fixed, reason: 'and a committed frame does not swap it for the terminal');
    });
  });

  group('the committed-frame hook', () {
    test('onFrame fires once per committed frame, with that frame', () async {
      final frames = <CompletedFrame>[];
      var views = 0;

      await runApp(
        Application(
          backend: backend,
          onFrame: (frame) {
            frames.add(frame);
            if (frames.length == 3) backend.emitKey(quitKey);
          },
        ),
        update: quitOnKey(),
        view: (model, frame) {
          views++;
          tagWholeArea(model, frame);
        },
      );

      expect(frames.map((f) => f.count), [0, 1, 2], reason: 'the init draw, then one per tick until the quit');
      expect(views, 3);
      expect(backend.drawCount, 3);
      for (final frame in frames) {
        expect(frame.area, backend.screen.area);
        expect(
          frame.hits.rectOf('ok'),
          Rect.create(x: 0, y: 0, width: 8, height: 2),
          reason: "that frame's own geometry",
        );
      }
    });

    test('a click emitted from onFrame resolves against that frame, the first to show its target', () async {
      late final PointerMsg click;
      late final Rect? rectInContext;
      Rect? boxWhenClicked;

      await Application(
        backend: backend,
        onFrame: (frame) {
          final box = frame.hits.rectOf('box');
          // The first frame has no box: ask for one. The next frame is the
          // first to show it, and the click aimed from there must land on it.
          if (box == null) {
            backend.emitKey('n');
            return;
          }
          boxWhenClicked = box;
          backend.emitClick(box.x + 3, box.y + 1);
        },
      ).run<int>(
        init: 0,
        update: (step, msg, ctx) {
          switch (msg) {
            case KeyMsg(key: 'n'):
              return (1, null);
            case final PointerMsg p:
              click = p;
              rectInContext = ctx.hits.rectOf('box');
              return (step, const Quit());
            default:
              return (step, null);
          }
        },
        view: (step, frame) => frame.render(
          step == 0 ? Line('') : Tagged('box', Container(border: BorderType.plain, child: Line(''))),
        ),
      );

      expect(boxWhenClicked, Rect.create(x: 0, y: 0, width: 8, height: 2));
      expect(click.targetId, 'box');
      expect(click.targetRect, boxWhenClicked, reason: 'stamped against the frame the callback described');
      expect(click.local, const Position(3, 1));
      expect(rectInContext, boxWhenClicked, reason: 'ctx.hits is that same map');
    });
  });

  group('frame reports', () {
    test('a report appended during paint reaches update on the loop iteration after the draw, '
        'carrying its id', () async {
      final seen = <_Rows>[];
      int? drawsWhenSeen;
      var views = 0;

      final rc = await runApp(
        Application(backend: backend),
        update: (model, msg, _) {
          if (msg is! _Rows) return (model, null);
          seen.add(msg);
          drawsWhenSeen = backend.drawCount;
          return (model, const Quit());
        },
        view: (_, frame) {
          views++;
          frame.render(_Reporter([_Rows('list', views)]));
        },
      );

      expect(rc, 0);
      expect(seen.map((r) => r.id), ['list']);
      expect(seen.single.rows, 1, reason: 'the first render reported');
      expect(drawsWhenSeen, 1, reason: "the first frame's report is processed before any second draw");
      expect(views, 1);
    });

    test('two reports with the same id and type in one frame deliver only the last', () async {
      final seen = <int>[];

      await runApp(
        Application(backend: backend, onFrame: quitAfterFirstFrame(backend)),
        update: (model, msg, _) {
          switch (msg) {
            case _Rows(:final rows):
              seen.add(rows);
              return (model, null);
            case KeyMsg(key: quitKey):
              return (model, const Quit());
            default:
              return (model, null);
          }
        },
        view: (_, frame) => frame.render(
          Column(
            children: [
              _Reporter(const [_Rows('list', 3)]),
              _Reporter(const [_Rows('list', 5)]),
            ],
          ),
        ),
      );

      expect(seen, [5], reason: "the quit key is queued behind the frame's reports, so all of them were seen");
    });

    test('a report handler reads the hit map of the frame that produced it', () async {
      // The box grows one cell per render, so each frame's geometry differs
      // from the last, and a report processed against the wrong map shows.
      final seen = <(int, int?)>[];
      var views = 0;

      await runApp(
        Application(backend: backend),
        update: (model, msg, ctx) {
          if (msg is! _Rows) return (model, null);
          seen.add((msg.rows, ctx.hits.rectOf('box')?.width));
          return (model, seen.length == 2 ? const Quit() : null);
        },
        view: (_, frame) {
          views++;
          frame.render(
            Row(
              children: [
                Tagged('box', Container(width: 2 + views, child: NodeView(_Reporter([_Rows('box', views)])))),
                Expanded(child: Line('')),
              ],
            ),
          );
        },
      );

      expect(seen, [(1, 3), (2, 4)], reason: 'each report sees the width the frame that reported it painted');
    });

    test("a terminal event emitted during a draw is queued behind that draw's reports, "
        'and the report still arrives', () async {
      // The awaiting run loop resumes, and queues the reports, before the
      // backend's event stream delivers the emitted key to the runtime.
      final order = <String>[];
      var views = 0;

      final rc = await runApp(
        Application(backend: backend),
        update: (model, msg, _) {
          switch (msg) {
            case KeyMsg(:final key):
              order.add('key $key');
              return (model, const Quit());
            case _Rows(:final rows):
              order.add('report $rows');
              return (model, null);
            default:
              return (model, null);
          }
        },
        view: (_, frame) {
          views++;
          // The first frame commits inside the startup hold, where an event
          // waits until the hold lifts. Emit from the second draw, where
          // delivery is live and the ordering is the loop's own.
          if (views == 2) backend.emitKey('n');
          frame.render(_Reporter([_Rows('list', views)]));
        },
      );

      expect(rc, 0);
      expect(order, ['report 1', 'report 2', 'key n']);
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

      final rc = await runApp(app, update: (_, _, _) => throw StateError('boom'));

      expect(seenError, isA<StateError>());
      expect(rc, 7, reason: 'onError replaces defaultErrorCode');
      expect(backend.rawMode, isFalse, reason: 'the terminal is restored even on the error path');
      expect(backend.windowResizeEvents, isFalse, reason: 'window-resize reporting is disabled too');
      expect(backend.disposed, isTrue);
    });

    test('without an onError, the failure exits with defaultErrorCode', () async {
      final app = Application(backend: backend, showError: false, defaultErrorCode: 2);

      final rc = await runApp(app, update: (_, _, _) => throw StateError('boom'));

      expect(rc, 2);
    });
  });

  group('the session measurer', () {
    test('a cjk measurer paints an ambiguous-width run the same way layout sized it', () async {
      // '°' is ambiguous width: one cell by default, two under a cjk locale.
      // A cjk Application must widen it identically in layout (so the next
      // glyph is placed a column over) and in paint (so the buffer marks the
      // widened cell skipped) — a mismatched measurer between the two is
      // exactly what used to shift every glyph after an ambiguous one over
      // by a column.
      const measurer = TermUnicodeMeasurer(cjk: true);
      final cjkBackend = TestBackend(size: const TermSize(4, 1), measurer: measurer);
      late final Buffer painted;

      await runApp(
        Application(backend: cjkBackend, measurer: measurer, onFrame: quitAfterFirstFrame(cjkBackend)),
        update: quitOnKey(),
        view: (_, frame) {
          frame.render(const Row(children: [Text('°'), Text('X')]));
          painted = frame.buffer;
        },
      );

      // Layout and paint agree on the terminal's own buffer: the glyph's
      // second cell is reserved and skipped, so X lands one column over.
      expect(painted[(x: 0, y: 0)].symbol, '°');
      expect(painted[(x: 1, y: 0)].skip, isTrue, reason: 'the second cell of the wide glyph is skipped');
      expect(painted[(x: 2, y: 0)].symbol, 'X', reason: 'layout reserved two cells, so X lands one column over');

      // And that same placement survives the diff onto the backend screen.
      expect(cjkBackend.screen[(x: 0, y: 0)].symbol, '°');
      expect(cjkBackend.screen[(x: 2, y: 0)].symbol, 'X');
    });

    test('the default measurer places the same run one column earlier than cjk', () async {
      // Companion to the test above with a plain (non-cjk) Application: '°'
      // measures one cell here, so X packs right next to it instead of one
      // column over. Layout and paint agree on that narrower width exactly the
      // same way they agreed on the wider one — the two configurations are each
      // internally consistent, just different.
      final narrowBackend = TestBackend(size: const TermSize(4, 1));
      late final Buffer painted;

      await runApp(
        Application(backend: narrowBackend, onFrame: quitAfterFirstFrame(narrowBackend)),
        update: quitOnKey(),
        view: (_, frame) {
          frame.render(const Row(children: [Text('°'), Text('X')]));
          painted = frame.buffer;
        },
      );

      expect(painted[(x: 0, y: 0)].symbol, '°');
      expect(painted[(x: 1, y: 0)].symbol, 'X', reason: 'a single-width glyph reserves only its own cell');

      expect(narrowBackend.screen[(x: 0, y: 0)].symbol, '°');
      expect(narrowBackend.screen[(x: 1, y: 0)].symbol, 'X');
    });

    test("clipping a too-narrow box truncates consistently with each measurer's own width", () async {
      // A one-cell box: the default measurer's one-cell glyph fits and paints;
      // the cjk measurer's two-cell glyph does not, and plume's clip drops it
      // whole rather than painting half of it. Same box, same content, two
      // different (both correct) outcomes — never a torn glyph.
      Future<Buffer> paintInto(TestBackend testBackend, {required TextMeasurer measurer}) async {
        late final Buffer painted;
        await runApp(
          Application(backend: testBackend, measurer: measurer, onFrame: quitAfterFirstFrame(testBackend)),
          update: quitOnKey(),
          view: (_, frame) {
            frame.render(const Text('°'));
            painted = frame.buffer;
          },
        );
        return painted;
      }

      const narrowMeasurer = TermUnicodeMeasurer();
      final narrowPainted = await paintInto(
        TestBackend(size: const TermSize(1, 1)),
        measurer: narrowMeasurer,
      );
      expect(narrowPainted[(x: 0, y: 0)].symbol, '°');

      const cjkMeasurer = TermUnicodeMeasurer(cjk: true);
      final cjkPainted = await paintInto(
        TestBackend(size: const TermSize(1, 1), measurer: cjkMeasurer),
        measurer: cjkMeasurer,
      );
      expect(cjkPainted[(x: 0, y: 0)].symbol, ' ', reason: 'the whole two-cell glyph is dropped, not half-painted');
    });
  });
}
