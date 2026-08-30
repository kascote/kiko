import 'dart:io' show sleep;

import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

// FrameScript driven through a real application: how its steps pace against
// committed frames, the ready gate, and the quit it ends on.

/// A 4x2 tagged box at [left].
View _box(int left) => Stack(
  fit: plume.StackFit.expand,
  children: [
    Positioned(
      left: left,
      top: 0,
      width: 4,
      height: 2,
      child: Tagged('box', Container(border: BorderType.plain, child: Line(''))),
    ),
  ],
);

const _step = Duration(milliseconds: 5);

void main() {
  late TestBackend backend;

  setUp(() {
    backend = TestBackend(size: const TermSize(16, 3));
    final policy = StyleResolver.defaultPolicy;
    addTearDown(() => StyleResolver.defaultPolicy = policy);
  });

  test('each step goes out from the first frame committed after the previous step landed', () async {
    final landed = <int>[]; // the count of the frame in force as each key landed
    final seen = <String>[];
    var frame = -1;
    final script = FrameScript(backend, steps: (_) => List.filled(3, (b) => b.emitKey('n')));

    await Application(
      backend: backend,
      fps: 120,
      onFrame: (completed) {
        frame = completed.count;
        script.onFrame(completed);
      },
    ).run<int>(
      init: 0,
      update: script.wrap((model, msg, _) {
        if (msg case KeyMsg(:final key)) {
          seen.add(key);
          landed.add(frame);
        }
        return (model, null);
      }),
      view: (_, frame) => frame.render(Line('')),
    );

    expect(seen, ['n', 'n', 'n'], reason: 'the quit key never reaches the app');
    expect(landed, [0, 1, 2], reason: 'one step per frame, from the init frame on');
    expect(frame, 3, reason: 'the frame that shows the last step, then the quit');
    expect(script.completed, isTrue);
    expect(script.lastFrame!.count, 3);
  });

  test("a step resolves against the frame that shows the previous step's effect", () async {
    final presses = <(String?, int)>[]; // (target, local x) of every press
    final seen = <String>[];
    late final FrameScript script;
    // Every click aims one cell into the box where the last frame painted it.
    script = FrameScript(
      backend,
      quitKey: 'ctrl+x',
      steps: (_) => List.filled(3, (b) => b.emitClick(script.lastFrame!.hits.rectOf('box')!.x + 1, 1)),
    );

    await Application(backend: backend, fps: 120, onFrame: script.onFrame).run<int>(
      init: 0,
      update: script.wrap((clicks, msg, _) {
        switch (msg) {
          case PointerMsg(action: PointerAction.down, :final targetId, :final local):
            presses.add((targetId, local.x));
            return (clicks + 1, null);
          case KeyMsg(:final key):
            seen.add(key);
        }
        return (clicks, null);
      }),
      // The box moves four cells right with every click.
      view: (clicks, frame) => frame.render(_box(clicks * 4)),
    );

    expect(presses, [('box', 1), ('box', 1), ('box', 1)], reason: 'each click found the box where it had moved to');
    expect(script.lastFrame!.hits.rectOf('box')!.x, 12, reason: 'the last frame shows the third click applied');
    expect(seen, isEmpty, reason: 'the custom quit key never reaches the app');
    expect(script.completed, isTrue);
  });

  test('with a ready id, the steps wait for the frame in which that hit path is live', () async {
    late final int ticksWhenLanded;
    final script = FrameScript(
      backend,
      readyId: 'box',
      steps: (hits) {
        expect(hits.isLive('box'), isTrue, reason: 'built from the frame the box first painted in');
        return [(b) => b.emitKey('n')];
      },
    );

    await Application(backend: backend, fps: 120, onFrame: script.onFrame).run<int>(
      init: 0,
      update: script.wrap((ticks, msg, _) {
        switch (msg) {
          case InitMsg():
            return (ticks, const Tick(_step, id: 'clock'));
          case TickMsg():
            return (ticks + 1, ticks + 1 < 2 ? const Tick(_step, id: 'clock') : null);
          case KeyMsg(key: 'n'):
            ticksWhenLanded = ticks;
        }
        return (ticks, null);
      }),
      // The box appears on the second tick.
      view: (ticks, frame) => frame.render(ticks < 2 ? Line('') : _box(0)),
    );

    expect(ticksWhenLanded, 2);
    expect(script.completed, isTrue);
  });

  test('a message that is not a step landing never releases the next step', () async {
    final seen = <String>[];
    // The first step emits nothing, so it never lands; the app's own ticks
    // keep frames coming until the app quits by itself.
    final script = FrameScript(backend, steps: (_) => [(_) {}, (b) => b.emitKey('n')]);

    final rc = await Application(backend: backend, fps: 120, onFrame: script.onFrame).run<int>(
      init: 0,
      update: script.wrap((ticks, msg, _) {
        switch (msg) {
          case InitMsg():
            return (ticks, const Tick(_step, id: 'clock'));
          case TickMsg():
            return (ticks + 1, ticks + 1 < 5 ? const Tick(_step, id: 'clock') : const Quit(7));
          case KeyMsg(:final key):
            seen.add(key);
        }
        return (ticks, null);
      }),
      view: (_, frame) => frame.render(Line('')),
    );

    expect(rc, 7, reason: 'the app ended the run itself');
    expect(seen, isEmpty, reason: 'five ticks and their frames released no step');
    expect(script.completed, isFalse);
  });

  test('a click lands with its release, so a timed step after it goes out only then', () async {
    final seen = <String>[]; // every landing, in order
    final script = FrameScript(
      backend,
      steps: (_) => [
        (b) => b.emitClick(1, 1),
        // A timed step: nothing goes out now, one focus probe does later.
        (b) => Future<void>.delayed(const Duration(milliseconds: 20), () => b.emitFocus(hasFocus: true)),
        (b) => b.emitKey('n'),
      ],
    );

    await Application(backend: backend, fps: 1000, onFrame: script.onFrame).run<int>(
      init: 0,
      update: script.wrap((model, msg, _) {
        switch (msg) {
          case PointerMsg(:final action):
            seen.add(action.name);
            // Outlast the frame interval, so the loop paints between the press
            // and the release still waiting in the queue.
            if (action == PointerAction.down) sleep(const Duration(milliseconds: 2));
          case FocusMsg():
            seen.add('focus');
          case KeyMsg(:final key):
            seen.add(key);
        }
        return (model, null);
      }),
      view: (_, frame) => frame.render(_box(0)),
    );

    expect(seen, ['down', 'up', 'focus', 'n'], reason: 'the key went out only after the timed step landed');
    expect(script.completed, isTrue);
  });

  test('the leave the router delivers ahead of a pointer event is not a landing of its own', () async {
    final seen = <String>[]; // every landing, in order
    late final int seenWhenKeySent;
    final script = FrameScript(
      backend,
      steps: (_) => [
        (b) => b.emitMove(1, 1), // hover onto the box
        (b) => b.emitClick(8, 1), // off the box: a leave, then a press and a release
        (b) {
          seenWhenKeySent = seen.length;
          b.emitKey('n');
        },
      ],
    );

    await Application(backend: backend, fps: 1000, onFrame: script.onFrame).run<int>(
      init: 0,
      update: script.wrap((model, msg, _) {
        switch (msg) {
          case PointerLeaveMsg():
            seen.add('leave');
          case PointerMsg(:final action):
            seen.add(action.name);
            // Outlast the frame interval, so the loop paints between the press
            // and the release still waiting in the queue.
            if (action == PointerAction.down) sleep(const Duration(milliseconds: 2));
          case KeyMsg(:final key):
            seen.add(key);
        }
        return (model, null);
      }),
      view: (_, frame) => frame.render(_box(0)),
    );

    expect(seen, ['move', 'leave', 'down', 'up', 'n']);
    expect(seenWhenKeySent, 4, reason: 'the key went out after the release landed, not after the press');
    expect(script.completed, isTrue);
  });
}
