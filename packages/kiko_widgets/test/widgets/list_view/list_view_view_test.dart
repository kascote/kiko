import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

const _ctx = plume.LayoutContext(measurer: plume.MonospaceMeasurer());

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

String _dump(Buffer buffer) {
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

ListViewModel<String, String> _list(List<String> items) =>
    ListViewModel<String, String>(dataView: DataView.fromList<String>(items), focused: true);

List<Line> _row(String item, int index, ItemState state) => [Line(item)];

void main() {
  group('list view render', () {
    test('draws the visible items inside a bordered box', () {
      final node = ListView<String, String>(
        model: _list(<String>['Apple', 'Banana', 'Cherry']),
        theme: Theme.dark,
        itemBuilder: _row,
        border: BorderType.plain,
      );
      final frame = _frame(12, 5)..render(node);

      expect(_dump(frame.buffer), '''
┌──────────┐
│Apple     │
│Banana    │
│Cherry    │
└──────────┘
''');
    });

    test('windows the rows to the scroll offset', () {
      final model = _list(<String>['a', 'b', 'c', 'd', 'e']);
      final node = ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row);

      // First frame fixes the visible count (3 rows) the model scrolls against.
      expect(_dump((_frame(5, 3)..render(node)).buffer), 'a\nb\nc\n');

      // Move the cursor to the end; the window slides down.
      for (var i = 0; i < 4; i++) {
        model.update(const KeyMsg('down'));
      }
      expect(_dump((_frame(5, 3)..render(node)).buffer), 'c\nd\ne\n');
    });

    test('shows the empty placeholder when there are no items', () {
      final node = ListView<String, String>(
        model: _list(<String>[]),
        theme: Theme.dark,
        itemBuilder: _row,
        emptyPlaceholder: Line('(empty)'),
      );
      expect(_dump((_frame(9, 1)..render(node)).buffer), '(empty)\n');
    });

    test('paints real row content through a RecordingSurface, not a hole', () {
      // The row body used to gate on `surface is BufferSurface`, so a golden
      // taken through plume's own RecordingSurface saw a border and nothing
      // else. Rows now paint through the plume Surface protocol directly, so
      // the focused row's fill and its text both land here too.
      final node =
          ListView<String, String>(model: _list(<String>['Apple']), theme: Theme.dark, itemBuilder: _row).build()
            ..layout(plume.BoxConstraints.tight(const plume.Size(5, 1)), _ctx)
            ..place(plume.Offset.zero);
      final surface = plume.RecordingSurface<PaintToken>();
      node.paint(surface);

      final intents = surface.intents.map((i) => '$i').toList();
      expect(intents, hasLength(2));
      expect(intents[0], startsWith('fillRect('));
      expect(intents[1], 'drawText(0, 0, "Apple", ${const PaintToken(Style())})');
    });
  });

  group('list view click routing', () {
    test('a click in the list resolves to its id', () {
      final model = ListViewModel<String, String>(
        id: 'menu',
        dataView: DataView.fromList<String>(<String>['a', 'b']),
        focused: true,
      );
      final frame = _frame(5, 2)..render(ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row));

      expect(frame.hitId(0, 0), 'menu');
      expect(frame.hitId(2, 1), 'menu');
    });
  });
}
