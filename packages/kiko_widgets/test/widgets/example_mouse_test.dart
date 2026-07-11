import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import '../../example/mouse_widgets.dart' as widgets;
import '../../example/scrollable_form.dart' as form;

// The two P5 examples, booted through a real application over a TestBackend and
// driven with real mouse events. Coordinates are read from the live hit map, so
// the tests assert behaviour, not a hand-computed layout.

/// Runs [model] through a real application, and once [readyId] has been painted
/// (its rect is in the committed hit map) feeds the events [events] builds from
/// that map, one per frame tick. Returns when the events are drained; [model] is
/// mutated in place, so the caller inspects it directly.
Future<void> _driveWhenReady<M>({
  required TestBackend backend,
  required M model,
  required (M, Cmd?) Function(M, Msg, UpdateContext) update,
  required void Function(M, Frame) view,
  required String readyId,
  required List<Event> Function(HitMap hits) events,
}) async {
  List<Event>? queue;
  var i = 0;

  await Application(backend: backend, fps: 120).run<M>(
    init: model,
    update: (m, msg, ctx) {
      if (msg is FrameTickMsg) {
        if (queue == null) {
          if (ctx.hits.rectOf(readyId) != null) queue = events(ctx.hits);
          return (m, null);
        }
        if (i >= queue!.length) return (m, const Quit());
        backend.emit(queue![i++]);
        return (m, null);
      }
      return update(m, msg, ctx);
    },
    view: view,
  );
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

  test('scrollable_form: a wheel over a field bubbles to the form and scrolls it', () async {
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
        // app bubbles it to the enclosing form, which scrolls.
        return [
          MouseEvent(field.x, field.y, MouseButton.wheelDown()),
          MouseEvent(field.x, field.y, MouseButton.wheelDown()),
        ];
      },
    );

    expect(model.scrollOffset, greaterThan(0), reason: 'the declined wheel should scroll the form');
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
