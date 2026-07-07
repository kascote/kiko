import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

const _ctx = plume.LayoutContext(measurer: plume.MonospaceMeasurer());

/// Wraps a measurer to count how many width requests reach it.
class _CountingMeasurer extends plume.TextMeasurer {
  _CountingMeasurer(this._inner);
  final plume.TextMeasurer _inner;
  int calls = 0;
  @override
  int widthOf(String text) {
    calls++;
    return _inner.widthOf(text);
  }
}

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

List<TableColumn> _columns() => <TableColumn>[
  TableColumn(field: 'id', label: Line('ID'), width: 2),
  TableColumn(field: 'name', label: Line('Name'), width: 4),
];

Future<TableViewModel> _seededTable({String? id}) async {
  final rows = <Map<String, Object?>>[
    <String, Object?>{'id': '1', 'name': 'Al'},
    <String, Object?>{'id': '2', 'name': 'Bo'},
  ];
  final source = TableDataSource.fromList(rows);
  final page = await source.getPage(0, 2);
  return TableViewModel(id: id, dataSource: source, keyField: 'id', columns: _columns())..insertRows(page, 0);
}

void main() {
  group('table view render', () {
    test('draws the sticky header and the visible rows', () async {
      final model = await _seededTable();
      final frame = _frame(7, 3)..render(TableView(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), 'ID Name\n1  Al\n2  Bo\n');
    });

    test('the measurer injected into the frame reaches cell text (mikos 0123)', () async {
      // Regression: the table body paints through paintLine, which used to
      // hardcode its own TermUnicodeMeasurer and ignore the frame's. A counting
      // measurer passed to Frame.render therefore saw zero requests for cells.
      final model = await _seededTable();
      final measurer = _CountingMeasurer(const TermUnicodeMeasurer());
      _frame(7, 3).render(
        TableView(model: model, theme: Theme.dark),
        measurer: measurer,
      );
      expect(measurer.calls, greaterThan(0));
    });

    test('paints real cell content through a RecordingSurface, not a hole', () async {
      // The row body used to gate on `surface is BufferSurface`, so a golden
      // taken through plume's own RecordingSurface saw a border and nothing
      // else. Rows now paint through the plume Surface protocol directly.
      final model = await _seededTable();
      final node = TableView(model: model, theme: Theme.dark).build()
        ..layout(plume.BoxConstraints.tight(const plume.Size(7, 3)), _ctx)
        ..place(plume.Offset.zero);
      final surface = plume.RecordingSurface<PaintToken>();
      node.paint(surface);

      // Each column (and the separator between them) is its own drawText
      // intent; spot-check one per row rather than pin the full cell-by-cell
      // breakdown, which is `TableRenderer`'s own well-tested business.
      final intents = surface.intents.map((i) => '$i').toList();
      expect(intents, isNotEmpty);
      expect(intents.any((i) => i.startsWith('drawText(0, 0, "ID"')), isTrue);
      expect(intents.any((i) => i.startsWith('drawText(0, 1, "1 "')), isTrue);
      expect(intents.any((i) => i.startsWith('drawText(0, 2, "2 "')), isTrue);
    });
  });

  group('table view click routing', () {
    test('a click in the table resolves to its id', () async {
      final model = await _seededTable(id: 'grid');
      final frame = _frame(7, 3)..render(TableView(model: model, theme: Theme.dark));
      expect(frame.hitId(0, 0), 'grid');
      expect(frame.hitId(3, 1), 'grid');
    });
  });
}
