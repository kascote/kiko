import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

import '../../example/theme_viewer/main.dart' as viewer;

/// A frame over a fresh in-memory buffer, ready to render into.
Frame _testFrame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// The buffer as a string: one line per row, trailing blanks trimmed.
String _screenText(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

// The theme viewer example, rendered headlessly: it is the canonical example
// for the theming doctrine, so its first frame is where the lift-or-fallback
// rule (a cursor lifting a selected row's fill instead of replacing it)
// shows on a real app screen, not just in a resolver unit test.
void main() {
  test(
    "the gallery list's first row starts selected under the cursor, as the selection fill lifted once",
    () {
      final model = viewer.Model();
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 160, height: 50));
      final frame = Frame(buffer.area, buffer, 0);
      viewer.view(model, frame);

      // The list tags its own rect with the model id, so the row's cells
      // come straight from the hit map rather than hard-coded coordinates.
      final rect = frame.hits.rectOf(model.list.id);
      expect(rect, isNotNull, reason: 'the list paints under its own id');
      final cell = buffer[(x: rect!.x, y: rect.y)];

      expect(cell.fg, equals(Theme.dark.selection.on));
      expect(cell.bg, equals(Theme.dark.selection.color!.lighten(Theme.stateLift)));
      // The list starts unfocused — the name field holds focus first — so
      // the cursor paints in the wash class and adds no bold. Bold marks a
      // collection that owns focus.
      expect(cell.modifier.has(Modifier.bold), isFalse);
    },
  );

  test('the starting frame shows the checked mark, a selected table row under the crosshair, and the crosshair', () {
    final model = viewer.Model();
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final buffer = frame.buffer;

    final box = frame.hits.rectOf(model.agree.id);
    expect(box, isNotNull, reason: 'the checkbox paints under its own id');
    expect(buffer[(x: box!.x + 1, y: box.y)].symbol, 'x', reason: 'seeded checked, so the mark shows');

    expect(model.table.getSelectedKeys(), equals({'R001'}));
    final table = frame.hits.rectOf(model.table.id);
    expect(table, isNotNull, reason: 'the table paints under its own id');
    // The header takes the first row; the selected row sits under the
    // cursor, so the crosshair's row wash lifts the selection fill.
    final selected = buffer[(x: table!.x + 1, y: table.y + 1)];
    expect(selected.fg, equals(Theme.dark.selection.on));
    expect(selected.bg, equals(Theme.dark.selection.color!.lighten(Theme.stateLift)));
    // The cursor column runs down every row: a bare row below the cursor
    // carries the cursor wash in that column.
    expect(buffer[(x: table.x + 1, y: table.y + 2)].bg, equals(Theme.dark.cursor.color));
  });

  test('F4 cycles the header through the three pages', () {
    final model = viewer.Model();
    var frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final ctx = UpdateContext(hits: frame.hits, area: frame.area);

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 3/3: Contrast'));

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 1/3: Reference'));

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 2/3: Gallery'));
  });
}
