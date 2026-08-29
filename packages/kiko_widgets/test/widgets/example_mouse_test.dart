import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:test/test.dart';

import '../../example/mouse_widgets.dart' as widgets;
import '../../example/scrollable_form.dart' as form;

// The two P5 examples, booted through a real application over a TestBackend and
// driven with real mouse/key events. Coordinates are read from the live hit
// map, so the tests assert behaviour, not a hand-computed layout.

/// The result of driving an app through [_driveWhenReady]: the [HitMap] from
/// the last paint, plus the cursor state the backend held right before
/// `Application.run` began its shutdown sequence.
///
/// The shutdown sequence unconditionally re-shows the cursor (leaving the
/// terminal usable once the alt screen/raw mode session ends) — reading
/// `backend.cursorVisible` *after* `_driveWhenReady` returns would always see
/// that, never the frame the test actually cares about. `cursorVisible` is
/// captured mid-run instead, before any of that runs.
typedef _DriveResult = ({HitMap hits, bool cursorVisible});

/// The key the harness quits on, intercepted before the example's update.
const _quitKey = 'ctrl+q';

/// Runs [model] through a real application, and once [readyId] has been painted
/// (its rect is in the committed hit map) feeds the events [events] builds from
/// that map, one per committed frame, then quits from the frame that follows
/// the last one. Returns the [HitMap] from that frame and the cursor
/// visibility it left (see [_DriveResult]); [model] is mutated in place, so
/// the caller can also inspect it directly.
///
/// A step goes out from the first frame committed after the previous step was
/// applied, so the last frame shows the last step's effect.
Future<_DriveResult> _driveWhenReady<M>({
  required TestBackend backend,
  required M model,
  required (M, Cmd?) Function(M, Msg, UpdateContext) update,
  required void Function(M, Frame) view,
  required String readyId,
  required List<void Function(TestBackend)> Function(HitMap hits) events,
}) async {
  List<void Function(TestBackend)>? queue;
  var i = 0;
  var pending = false;
  var quitSent = false;
  HitMap? lastPaintedHits;
  var lastCursorVisible = backend.cursorVisible;

  await Application(
    backend: backend,
    fps: 120,
    onFrame: (frame) {
      // Read right after the draw committed, so the LAST value recorded is
      // the settled state of the final frame — never the post-shutdown state.
      lastCursorVisible = backend.cursorVisible;
      lastPaintedHits = frame.hits;
      if (pending) return;
      if (queue == null) {
        if (frame.hits.rectOf(readyId) == null) return;
        queue = events(frame.hits);
      }
      if (i < queue!.length) {
        pending = true;
        queue![i++](backend);
        return;
      }
      if (!quitSent) {
        quitSent = true;
        backend.emitKey(_quitKey);
      }
    },
  ).run<M>(
    init: model,
    update: (m, msg, ctx) {
      if (msg case KeyMsg(key: _quitKey)) return (m, const Quit());
      // Anything after the init message is a step landing.
      if (msg is! InitMsg) pending = false;
      return update(m, msg, ctx);
    },
    view: view,
  );

  expect(i, queue!.length, reason: 'every scripted step ran');
  return (hits: lastPaintedHits!, cursorVisible: lastCursorVisible);
}

void main() {
  test('mouse_widgets: a click activates a row and focuses its widget', () async {
    final model = widgets.AppModel();

    await _driveWhenReady<widgets.AppModel>(
      backend: TestBackend(size: const TermSize(60, 20)),
      model: model,
      update: widgets.update,
      view: widgets.view,
      readyId: 'employees',
      events: (hits) {
        final table = hits.rectOf('employees')!; // header at row 0, data below
        final list = hits.rectOf('departments')!; // items from row 0
        return [
          // A click on a table data row: focuses the table, activates the row.
          (b) => b.emitClick(table.x + 1, table.y + 1),
          // A click on a list item: focus moves to the list, same activation path.
          (b) => b.emitClick(list.x + 1, list.y),
        ];
      },
    );

    // Both presses reached the app as the same id-addressed command a keyboard
    // Enter emits, so both logged an activation.
    expect(model.log.length, greaterThanOrEqualTo(2));
    expect(model.log.any((l) => l.startsWith('employees')), isTrue);
    expect(model.log.any((l) => l.startsWith('departments')), isTrue);
    // The last press moved focus app-side to the list.
    expect(model.list.focused, isTrue);
    expect(model.table.focused, isFalse);
    expect(model.focus.focused.id, equals('departments'));
  });

  test('scrollable_form: a wheel over a field bubbles to the scroll view and scrolls it', () async {
    final model = form.AppModel();

    await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 18)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (hits) {
        final field = hits.rectOf('field-0/field-0')!;
        // The wheel addresses the field under it; the field declines, and the
        // app offers it outward to the enclosing scroll view, which scrolls.
        return [
          (b) => b.emitWheel(field.x, field.y, deltaY: 1),
          (b) => b.emitWheel(field.x, field.y, deltaY: 1),
        ];
      },
    );

    expect(model.scroll.scrollOffset, greaterThan(0), reason: 'the declined wheel should scroll the form');
  });

  test('scrollable_form: a wheel on the border of a field scrolls the form too', () async {
    final model = form.AppModel();

    await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 18)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (hits) {
        final content = hits.rectOf('field-0/field-0')!;
        // One row above the content, still inside field-0's own border — its
        // scope, not its content leaf. The field declines the wheel exactly
        // as it would over its content, and the router's outward walk
        // reaches the scroll view behind it.
        return [
          (b) => b.emitWheel(content.x, content.y - 1, deltaY: 1),
          (b) => b.emitWheel(content.x, content.y - 1, deltaY: 1),
        ];
      },
    );

    expect(model.scroll.scrollOffset, greaterThan(0), reason: 'a border wheel bubbles out to the scroll view too');
  });

  test('scrollable_form: a wheel over the bordered frame scrolls it too', () async {
    final model = form.AppModel();

    await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 18)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (hits) {
        // The outer frame's own plain id — no field involved. The router
        // declines it (the id names no member), and the app forwards it to
        // the scroll model by hand.
        final frame = hits.rectOf('form-frame')!;
        return [(b) => b.emitWheel(frame.x, frame.y, deltaY: 1)];
      },
    );

    expect(
      model.scroll.scrollOffset,
      greaterThan(0),
      reason: "the app forwards the frame id's pointer traffic to the same scroll model",
    );
  });

  test('scrollable_form: every field is reachable by scrolling, however short the screen (finding B)', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)), // short: only a couple of fields fit
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (hits) {
        final field = hits.rectOf('field-0/field-0')!;
        // Far more than enough notches to hit the bottom, whatever the
        // viewport height turns out to be.
        return [for (var i = 0; i < 40; i++) (b) => b.emitWheel(field.x, field.y, deltaY: 1)];
      },
    );

    expect(
      result.hits.rectOf('field-7/field-7'),
      isNotNull,
      reason: 'the last field must be reachable — no hardcoded visible count to fall short',
    );
  });

  test('scrollable_form: wheel-down at the bottom is a benign no-op, not a crash', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (hits) {
        final field = hits.rectOf('field-0/field-0')!;
        final frame = hits.rectOf('form-frame')!;
        return [
          // Scroll all the way to the bottom via the field-decline path...
          for (var i = 0; i < 40; i++) (b) => b.emitWheel(field.x, field.y, deltaY: 1),
          // ...then one more notch, straight on the frame: the app forwards
          // it to the scroll model, which declines too — nothing throws.
          (b) => b.emitWheel(frame.x, frame.y, deltaY: 1),
        ];
      },
    );

    expect(model.scroll.scrollOffset, equals(model.scroll.contentRows - model.scroll.viewportRows));
    expect(result.hits.rectOf('field-7/field-7'), isNotNull);
  });

  test('scrollable_form: Tab past the viewport edge scrolls the focused field into view', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (_) => [for (var i = 0; i < 7; i++) (b) => b.emitKey('tab')],
    );

    expect(model.focus.focused.id, equals('field-7'));
    expect(
      result.hits.rectOf('field-7/field-7'),
      isNotNull,
      reason: 'ensureVisible must have scrolled the last field into view as focus reached it',
    );
  });

  test('scrollable_form: Tab to the last field scrolls its whole frame into view, border included', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (_) => [for (var i = 0; i < 7; i++) (b) => b.emitKey('tab')],
    );

    expect(model.focus.focused.id, equals('field-7'));
    // ensureVisible targets the whole scoped frame, not just the content
    // leaf, so the scroll must reach exactly the bottom — the last field's
    // own bottom border included, not just its one content row.
    expect(
      model.scroll.scrollOffset,
      equals(model.scroll.contentRows - model.scroll.viewportRows),
      reason: "the last field's whole frame, border included, must be fully in view",
    );
    expect(result.hits.rectOf('field-7/field-7'), isNotNull);
  });

  test('scrollable_form: a field scrolled off-screen leaves no stray terminal cursor (G1)', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0/field-0',
      events: (hits) {
        final field = hits.rectOf('field-0/field-0')!;
        // Scroll the still-focused field-0 off the top, without moving focus.
        return [for (var i = 0; i < 10; i++) (b) => b.emitWheel(field.x, field.y, deltaY: 1)];
      },
    );

    expect(model.fields['field-0']!.focused, isTrue, reason: 'focus never moved — only scroll did');
    expect(
      result.cursorVisible,
      isFalse,
      reason: 'the focused field scrolled off-screen; the runtime must hide the cursor',
    );
  });

  test('scrollable_form: a press on a field focuses it', () async {
    final model = form.AppModel();

    await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 18)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-1/field-1',
      events: (hits) {
        final field = hits.rectOf('field-1/field-1')!;
        return [(b) => b.emitClick(field.x, field.y)];
      },
    );

    expect(model.focus.focused.id, equals('field-1'));
  });

  test('scrollable_form: a press on the border of a field focuses it', () async {
    final model = form.AppModel();

    await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 18)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-1/field-1',
      events: (hits) {
        final content = hits.rectOf('field-1/field-1')!;
        // A cell on field-1's own border — its scope, not its content leaf.
        // The scope's bare path is the same id the field itself answers to,
        // so the router's click-to-focus moves focus there directly.
        return [(b) => b.emitClick(content.x, content.y - 1)];
      },
    );

    expect(model.focus.focused.id, equals('field-1'));
  });
}
