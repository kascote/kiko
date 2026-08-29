import 'package:kiko/kiko.dart';
// A mouse event waits in the queue in its un-routed form. Putting one back on
// the queue is the only way to make the loop see a burst of them at once.
import 'package:kiko/src/mvu/msg.dart' show RawPointerMsg;
import 'package:kiko/testing.dart';
import 'package:plume/plume.dart' as plume;
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

// The whole stack, driven through a real application: a backend delivers an
// event, the runtime stamps and queues it, the router resolves it, and the
// drain loop hands the result to `update`. Nothing here re-implements the loop
// or hand-sets the geometry it resolves against.

/// Something that fills whatever slot it is given.
View _pane() => Container(border: BorderType.plain, child: Line(''));

/// One tagged pane, [width] wide and 2 tall, at [left].
View _panel(String id, {int left = 0, int width = 4}) => Stack(
  fit: plume.StackFit.expand,
  children: [Positioned(left: left, top: 0, width: width, height: 2, child: Tagged(id, _pane()))],
);

MouseButton _down() => MouseButton.down(MouseButtonKind.left);
MouseButton _up() => MouseButton.up(MouseButtonKind.left);
MouseButton _drag() => MouseButton.drag(MouseButtonKind.left);
MouseButton _move() => MouseButton.moved();

/// The key every harness here quits on, intercepted before anything else.
const _quitKey = 'ctrl+q';

/// A message an update queues ahead of a terminal event, to change the model
/// (and so the next frame) before that event is processed.
class _Advance extends Msg {
  const _Advance();
}

/// Runs a real application over [backend], feeding it [events] one per
/// committed frame, and returns every message `update` saw after the init.
Future<List<Msg>> _drive(TestBackend backend, List<Event> events, Render<int> view) async {
  final seen = <Msg>[];
  final script = FrameScript(backend, steps: (_) => [for (final e in events) (b) => b.emit(e)]);

  await Application(backend: backend, fps: 120, onFrame: script.onFrame).run<int>(
    init: 0,
    update: script.wrap((model, msg, _) {
      if (msg is! InitMsg) seen.add(msg);
      return (model, null);
    }),
    view: view,
  );

  expect(script.completed, isTrue, reason: 'every scripted event went out');
  return seen;
}

/// Three panes across the viewport, tagged `a`, `b` and `c`.
void _threePanes(int _, Frame frame) => frame.render(
  Stack(
    fit: plume.StackFit.expand,
    children: [
      Positioned(left: 0, top: 0, width: 4, height: 2, child: Tagged('a', _pane())),
      Positioned(left: 4, top: 0, width: 4, height: 2, child: Tagged('b', _pane())),
      Positioned(left: 8, top: 0, width: 4, height: 2, child: Tagged('c', _pane())),
    ],
  ),
);

void main() {
  late TestBackend backend;

  setUp(() {
    backend = TestBackend(size: const TermSize(12, 3));
    final policy = StyleResolver.defaultPolicy;
    addTearDown(() => StyleResolver.defaultPolicy = policy);
  });

  group('the layers compose', () {
    test('a click on the top-left cell reaches update as (0, 0) of the widget painted there', () async {
      late final PointerMsg click;

      await Application(backend: backend).run<int>(
        init: 0,
        update: (model, msg, _) {
          switch (msg) {
            case InitMsg():
              backend.emit(MouseEvent(0, 0, _down()));
              return (model, null);
            case final PointerMsg p:
              click = p;
              return (model, const Quit());
            default:
              return (model, null);
          }
        },
        view: (_, frame) => frame.render(Tagged('x', _pane())),
      );

      expect(click.targetId, 'x');
      expect(click.global, Position.origin);
      expect(click.local, Position.origin, reason: 'the backend translated, the router subtracted');
      expect(click.inside, isTrue);
    });
  });

  group('an event is resolved against the frame it was aimed at', () {
    test('a click queued before a frame commits still hits where the widget was', () async {
      late final PointerMsg click;
      late final Rect? rectWhenClicked;
      Rect? rectOnScreen;

      await Application(
        backend: backend,
        fps: 120,
        onFrame: (frame) {
          // The second frame is the first painted after the box moved: read
          // back what is actually on screen, then stop.
          if (frame.count != 1) return;
          rectOnScreen = frame.hits.rectOf('box');
          backend.emitKey(_quitKey);
        },
      ).run<int>(
        init: 0,
        update: (step, msg, ctx) {
          switch (msg) {
            case InitMsg():
              // Aimed at the box where it is painted right now, at x = 0...
              backend.emit(MouseEvent(1, 1, _down()));
              // ...and a message that moves the box is queued ahead of it.
              return (step, const Emit(_Advance()));
            case _Advance():
              return (1, null);
            case final PointerMsg p:
              click = p;
              rectWhenClicked = ctx.hits.rectOf('box');
              return (step, null);
            case KeyMsg(key: _quitKey):
              return (step, const Quit());
            default:
              return (step, null);
          }
        },
        view: (step, frame) => frame.render(_panel('box', left: step == 0 ? 0 : 6)),
      );

      expect(click.targetId, 'box');
      expect(click.targetRect, Rect.create(x: 0, y: 0, width: 4, height: 2), reason: 'where the box was clicked');
      expect(click.local, const Position(1, 1));
      expect(rectWhenClicked, click.targetRect, reason: 'ctx.hits is the map the message resolved against');
      expect(rectOnScreen, Rect.create(x: 6, y: 0, width: 4, height: 2), reason: 'the box had already moved on');
    });
  });

  group('hover, through the loop', () {
    test('the pane being left is told so before the event that left it is delivered', () async {
      final seen = await _drive(
        backend,
        [MouseEvent(1, 1, _move()), MouseEvent(5, 1, _move()), MouseEvent(9, 1, _move())],
        _threePanes,
      );

      expect(
        seen.map((m) => m is PointerMsg ? 'over ${m.targetId}' : '$m'),
        [
          'over a',
          'PointerLeaveMsg(a)',
          'over b',
          'PointerLeaveMsg(b)',
          'over c',
        ],
        reason: 'one dequeued event, two delivered messages, in that order',
      );
    });

    test('a burst of moves coalesces, so the pane swept over never hears about it', () async {
      final seen = <Msg>[];

      // The cursor arrives over `a`, then two more moves land in the queue
      // before the loop can drain either — as they would from a cursor
      // outrunning the frame rate. fps 1 keeps a draw from landing between
      // them.
      await Application(backend: backend, fps: 1).run<int>(
        init: 0,
        update: (step, msg, ctx) {
          switch (msg) {
            case InitMsg():
              backend.emit(MouseEvent(1, 1, _move()));
              return (step, null);
            case PointerMsg(targetId: 'a'):
              seen.add(msg);
              return (
                step,
                Batch([
                  Emit(RawPointerMsg(MouseEvent(5, 1, _move()), ctx.hits)),
                  Emit(RawPointerMsg(MouseEvent(9, 1, _move()), ctx.hits)),
                ]),
              );
            case PointerMsg(targetId: 'c'):
              seen.add(msg);
              return (step, const Quit());
            case Routed():
              seen.add(msg);
              return (step, null);
            default:
              return (step, null);
          }
        },
        view: _threePanes,
      );

      expect(
        seen.map((m) => m is PointerMsg ? 'over ${m.targetId}' : '$m'),
        [
          'over a',
          'PointerLeaveMsg(a)',
          'over c',
        ],
        reason: 'the middle pane never painted a hover, so it is never told about one',
      );
    });
  });

  group('capture, through the loop', () {
    test('the release reaches the panel the press began on, and knows it landed outside', () async {
      final seen = await _drive(
        backend,
        [MouseEvent(1, 1, _down()), MouseEvent(9, 1, _drag()), MouseEvent(9, 1, _up())],
        (_, frame) => frame.render(_panel('panel')),
      );

      final pointers = seen.whereType<PointerMsg>().toList();
      expect(pointers.map((p) => p.targetId), ['panel', 'panel', 'panel']);
      expect(pointers.map((p) => p.captured), [false, true, true]);
      expect(pointers.map((p) => p.inside), [true, false, false]);
      expect(pointers.last.local, const Position(9, 1), reason: 'still counted from the panel’s own corner');
      expect(seen.last, const PointerLeaveMsg('panel'), reason: 'hover catches up once the button is up');
    });

    test('losing focus mid-drag cancels the gesture before the focus message lands', () async {
      final seen = await _drive(
        backend,
        [MouseEvent(1, 1, _down()), const FocusEvent(hasFocus: false)],
        (_, frame) => frame.render(_panel('panel')),
      );

      expect(seen.skip(1), [
        const PointerCancelMsg('panel'),
        const PointerLeaveMsg('panel'),
        const FocusMsg(hasFocus: false),
      ], reason: 'nothing is left waiting for a release that will never come');
    });

    test('a captor scrolled out of a Viewport is told its gesture is over', () async {
      // The doctrine payoff (spec 0166 / task 0174): presence-clipping in
      // HitMap is the only change needed — this drives the real router path
      // (mouse_router.dart untouched) through a real Application loop.
      late final Msg cancelMsg;
      final backend = TestBackend(size: const TermSize(6, 3));

      // A 3-row viewport onto 6 rows of content: 'field' fills the window at
      // scrollOffset 0, and is scrolled fully out of it at scrollOffset 6.
      View content(int scrollOffset) => Viewport(
        scrollOffset: scrollOffset,
        child: const Column(
          children: [Tagged('field', SizedBox(width: 6, height: 3)), SizedBox(width: 6, height: 3)],
        ),
      );

      var dragged = false;

      await Application(
        backend: backend,
        fps: 120,
        onFrame: (frame) {
          // Drag from the first frame that no longer shows the captor.
          if (dragged || frame.hits.isLive('field')) return;
          dragged = true;
          backend.emit(MouseEvent(0, 0, _drag()));
        },
      ).run<int>(
        init: 0,
        update: (step, msg, _) {
          switch (msg) {
            case InitMsg():
              // Captured while 'field' fills the whole 3-row window.
              backend.emit(MouseEvent(0, 0, _down()));
              return (step, null);
            case final PointerMsg p when p.targetId == 'field':
              // Button still down: scroll 'field' fully past the top.
              return (1, null);
            case final PointerCancelMsg c:
              cancelMsg = c;
              return (step, const Quit());
            default:
              return (step, null);
          }
        },
        view: (step, frame) => frame.render(content(step == 0 ? 0 : 6)),
      );

      expect(dragged, isTrue);

      expect(cancelMsg, const PointerCancelMsg('field'));
    });
  });
}
