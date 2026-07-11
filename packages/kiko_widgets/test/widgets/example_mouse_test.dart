import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:termparser/termparser_events.dart';
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

/// Runs [model] through a real application, and once [readyId] has been painted
/// (its rect is in the committed hit map) feeds the events [events] builds from
/// that map, one per frame tick. Returns the [HitMap] from the last paint and
/// the cursor visibility from just before shutdown (see [_DriveResult]); [model]
/// is mutated in place, so the caller can also inspect it directly.
///
/// A message emitted on tick N is only dequeued and applied on a LATER
/// iteration, and `Application` paints only on a `FrameTickMsg` iteration and
/// skips that paint entirely once `update` answers `Quit` — so quitting the
/// instant the queue drains would ship the second-to-last state, never
/// painting the last event's effect. A couple of idle ticks after the queue
/// drains give that last message room to be applied and painted before Quit.
Future<_DriveResult> _driveWhenReady<M>({
  required TestBackend backend,
  required M model,
  required (M, Cmd?) Function(M, Msg, UpdateContext) update,
  required void Function(M, Frame) view,
  required String readyId,
  required List<Event> Function(HitMap hits) events,
}) async {
  List<Event>? queue;
  var i = 0;
  var idleTicks = 0;
  HitMap? lastPaintedHits;
  var lastCursorVisible = backend.cursorVisible;

  await Application(backend: backend, fps: 120).run<M>(
    init: model,
    update: (m, msg, ctx) {
      if (msg is FrameTickMsg) {
        // Captured before this tick's own draw, so the LAST value recorded
        // (just before Quit is returned) reflects the previous, now-settled
        // draw — never the post-shutdown state.
        lastCursorVisible = backend.cursorVisible;
        if (queue == null) {
          if (ctx.hits.rectOf(readyId) != null) queue = events(ctx.hits);
          return (m, null);
        }
        if (i < queue!.length) {
          backend.emit(queue![i++]);
          return (m, null);
        }
        if (idleTicks < 2) {
          idleTicks++;
          return (m, null);
        }
        return (m, const Quit());
      }
      return update(m, msg, ctx);
    },
    view: (m, frame) {
      view(m, frame);
      lastPaintedHits = frame.hits;
    },
  );

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
          // A press on a table data row: focuses the table, activates the row.
          MouseEvent(table.x + 1, table.y + 1, MouseButton.down()),
          MouseEvent(table.x + 1, table.y + 1, MouseButton.up()),
          // A press on a list item: focus moves to the list, same activation path.
          MouseEvent(list.x + 1, list.y, MouseButton.down()),
          MouseEvent(list.x + 1, list.y, MouseButton.up()),
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
      readyId: 'field-0',
      events: (hits) {
        final field = hits.rectOf('field-0')!;
        // The wheel addresses the field under it; the field declines, and the
        // app offers it outward to the enclosing scroll view, which scrolls.
        return [
          MouseEvent(field.x, field.y, MouseButton.wheelDown()),
          MouseEvent(field.x, field.y, MouseButton.wheelDown()),
        ];
      },
    );

    expect(model.scroll.scrollOffset, greaterThan(0), reason: 'the declined wheel should scroll the form');
  });

  test('scrollable_form: a wheel over the bordered frame scrolls it too (E-split recipe)', () async {
    final model = form.AppModel();

    await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 18)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0',
      events: (hits) {
        // The frame's own tag — no field involved, no decline to bubble. It
        // routes to the SAME ScrollViewModel as the content area's self-tag.
        final frame = hits.rectOf('form-frame')!;
        return [MouseEvent(frame.x, frame.y, MouseButton.wheelDown())];
      },
    );

    expect(
      model.scroll.scrollOffset,
      greaterThan(0),
      reason: 'the frame is a second id routed to the same scroll model',
    );
  });

  test('scrollable_form: every field is reachable by scrolling, however short the screen (finding B)', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)), // short: only a couple of fields fit
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0',
      events: (hits) {
        final field = hits.rectOf('field-0')!;
        // Far more than enough notches to hit the bottom, whatever the
        // viewport height turns out to be.
        return [for (var i = 0; i < 40; i++) MouseEvent(field.x, field.y, MouseButton.wheelDown())];
      },
    );

    expect(
      result.hits.rectOf('field-7'),
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
      readyId: 'field-0',
      events: (hits) {
        final field = hits.rectOf('field-0')!;
        final frame = hits.rectOf('form-frame')!;
        return [
          // Scroll all the way to the bottom via the field-decline path...
          for (var i = 0; i < 40; i++) MouseEvent(field.x, field.y, MouseButton.wheelDown()),
          // ...then one more notch, straight on the frame: declines, nothing
          // above consumes it, nothing throws.
          MouseEvent(frame.x, frame.y, MouseButton.wheelDown()),
        ];
      },
    );

    expect(model.scroll.scrollOffset, equals(model.scroll.contentRows - model.scroll.viewportRows));
    expect(result.hits.rectOf('field-7'), isNotNull);
  });

  test('scrollable_form: Tab past the viewport edge scrolls the focused field into view', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0',
      events: (_) => [for (var i = 0; i < 7; i++) const KeyEvent(KeyCode.named(KeyCodeName.tab))],
    );

    expect(model.focus.focused.id, equals('field-7'));
    expect(
      result.hits.rectOf('field-7'),
      isNotNull,
      reason: 'ensureVisible must have scrolled the last field into view as focus reached it',
    );
  });

  test('scrollable_form: a field scrolled off-screen leaves no stray terminal cursor (G1)', () async {
    final model = form.AppModel();

    final result = await _driveWhenReady<form.AppModel>(
      backend: TestBackend(size: const TermSize(50, 10)),
      model: model,
      update: form.update,
      view: form.view,
      readyId: 'field-0',
      events: (hits) {
        final field = hits.rectOf('field-0')!;
        // Scroll the still-focused field-0 off the top, without moving focus.
        return [for (var i = 0; i < 10; i++) MouseEvent(field.x, field.y, MouseButton.wheelDown())];
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
      readyId: 'field-1',
      events: (hits) {
        final field = hits.rectOf('field-1')!;
        return [MouseEvent(field.x, field.y, MouseButton.down()), MouseEvent(field.x, field.y, MouseButton.up())];
      },
    );

    expect(model.focus.focused.id, equals('field-1'));
  });
}
