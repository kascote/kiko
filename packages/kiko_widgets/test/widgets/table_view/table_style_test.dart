import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Renders [model] through a [TableRenderer] into a fresh buffer, returning
/// the buffer so tests can inspect cell fg/bg/modifier directly (not just
/// glyphs — that's `table_renderer_test.dart`'s job).
Buffer renderBuffer(
  TableViewModel model, {
  required int width,
  required int height,
  Theme theme = Theme.dark,
  TableViewStyle style = const TableViewStyle(),
  bool showCrosshair = false,
  Line? emptyPlaceholder,
}) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  TableRenderer(
    model,
    theme,
    style: style,
    showCrosshair: showCrosshair,
    emptyPlaceholder: emptyPlaceholder,
  ).paint(buffer.area, BufferSurface(buffer));
  return buffer;
}

/// Two 5-wide columns ("a", "b") separated by the default one-space
/// separator: header at y=0, row N at y=N+1. Column "a" renders its value
/// with an explicit red foreground so tests can check that a wash or fill
/// never clobbers a cell's own color.
List<TableColumn> _columns() => [
  TableColumn(
    field: 'a',
    label: Line('A'),
    width: 5,
    render: (ctx) => Line.fromTexts([Text(ctx.value.toString(), style: const Style(fg: Color.red))]),
  ),
  TableColumn(field: 'b', label: Line('B'), width: 5),
];

List<Map<String, Object?>> _rows(int count) => List.generate(count, (i) => {'id': 'r$i', 'a': '-$i', 'b': 'v$i'});

TableViewModel _model({
  int rowCount = 4,
  bool selectionEnabled = false,
  bool focused = true,
}) {
  final model = TableViewModel(
    rows: _rows(rowCount),
    keyField: 'id',
    columns: _columns(),
    selectionEnabled: selectionEnabled,
    focused: focused,
  )..insertRows(_rows(rowCount), 0);
  return model;
}

void main() {
  group('TableView anatomy styling', () {
    group("wash preserves each cell's own foreground", () {
      test('cursor row wash does not clobber a custom render fg', () {
        final model = _model()
          ..update(const KeyMsg('down')) // cursorRow = 1
          ..update(const KeyMsg('right')); // cursorCol = 1 ("b"), so col "a" is not the cursor cell

        final buffer = renderBuffer(model, width: 11, height: 5);

        // Row 1, column "a" (x=0..4, y=2): on the cursor row but not the
        // cursor cell — should carry the cursor wash bg while keeping the
        // custom red fg from the column's own render callback.
        final cell = buffer[(x: 0, y: 2)];
        expect(cell.fg, equals(Color.red), reason: 'custom fg must survive the wash');
        expect(cell.bg, equals(Theme.dark.cursor.color));
      });

      test('non-cursor row is unaffected', () {
        final model = _model();
        final buffer = renderBuffer(model, width: 11, height: 5);

        // Row 2 (y=3) is neither the cursor row nor selected.
        final cell = buffer[(x: 0, y: 3)];
        expect(cell.fg, equals(Color.red));
        expect(cell.bg, equals(Color.reset));
      });

      test('hover row wash preserves a custom render fg', () {
        // Hover data row 2 (screen y=3), away from the cursor at row 0.
        final model = _model()..hoverRow = 2;
        final buffer = renderBuffer(model, width: 11, height: 5);

        final cell = buffer[(x: 0, y: 3)];
        expect(cell.fg, equals(Color.red), reason: 'custom fg must survive the hover wash');
        expect(cell.bg, equals(Theme.dark.hover.color));
      });

      test('hover is the weakest state: the cursor row wash wins over it', () {
        // Row 0 is both hovered and the cursor; on a non-cursor column its wash
        // is the cursor tone, not the hover tone.
        final model = _model()..hoverRow = 0;
        final buffer = renderBuffer(model, width: 11, height: 5);

        // Column "b" (x=6) on the cursor row (y=1): cursor row wash, not hover.
        final cell = buffer[(x: 6, y: 1)];
        expect(cell.bg, equals(Theme.dark.cursor.color), reason: 'the cursor wash wins over the hover wash');
      });

      test('crosshair column wash also preserves fg', () {
        final model = _model()
          ..update(const KeyMsg('down')) // cursorRow = 1
          ..update(const KeyMsg('right')); // cursorCol = 1 ("b")

        final buffer = renderBuffer(model, width: 11, height: 5, showCrosshair: true);

        // Row 0, column "a" (x=0, y=1): not the cursor row, and column "a"
        // is not the cursor column either — should be untouched.
        final untouched = buffer[(x: 0, y: 1)];
        expect(untouched.bg, equals(Color.reset));

        // Row 0, column "b" (x=6, y=1): not the cursor row, but IS the
        // cursor column — crosshair wash should tint its bg.
        final crosshairCol = buffer[(x: 6, y: 1)];
        expect(crosshairCol.bg, equals(Theme.dark.cursor.color));
      });
    });

    group('crosshair off by default', () {
      test('cursor column is not washed when showCrosshair is false', () {
        final model = _model()
          ..update(const KeyMsg('down')) // cursorRow = 1
          ..update(const KeyMsg('right')); // cursorCol = 1 ("b")

        final buffer = renderBuffer(model, width: 11, height: 5);

        // Row 0, column "b" (x=6, y=1): shares the cursor's column but not
        // its row. With crosshair off, only the cursor row + cell paint.
        final cell = buffer[(x: 6, y: 1)];
        expect(cell.bg, equals(Color.reset));
      });

      test('the same cell is washed once showCrosshair is turned on', () {
        final model = _model()
          ..update(const KeyMsg('down'))
          ..update(const KeyMsg('right'));

        final buffer = renderBuffer(model, width: 11, height: 5, showCrosshair: true);
        final cell = buffer[(x: 6, y: 1)];
        expect(cell.bg, equals(Theme.dark.cursor.color));
      });
    });

    group('selected + cursor layering', () {
      test('the cursor stays visible over a selected run', () {
        final model = _model(selectionEnabled: true)
          ..update(const KeyMsg('space')) // select row 0
          ..update(const KeyMsg('down'))
          ..update(const KeyMsg('space')) // select row 1
          ..update(const KeyMsg('down'))
          ..update(const KeyMsg('space')); // select row 2; cursor now on row 2

        final buffer = renderBuffer(model, width: 11, height: 5);

        // Row 0, column "b": selected, not the cursor row — pure selectedRow
        // fill. (Column "a" always shows its own red fg regardless of state,
        // so the plain column is what proves the fill's fg.)
        final selectedOnly = buffer[(x: 6, y: 1)];
        expect(selectedOnly.fg, equals(Theme.dark.selection.on));
        expect(selectedOnly.bg, equals(Theme.dark.selection.color));

        // Row 2, column "a": selected AND the cursor row, but not the cursor
        // cell (cursor is at column 0 = "a" actually — move right so "a"
        // isn't the cursor column for this check).
        final rowStyled = buffer[(x: 6, y: 3)]; // column "b", row 2
        // The wash (bg-only) must win over the selection fill's bg, while
        // the selection fill's fg (there's no custom render on column b)
        // shows through untouched by the wash.
        expect(rowStyled.bg, equals(Theme.dark.cursor.color));
        expect(rowStyled.fg, equals(Theme.dark.selection.on));

        // Row 2, column "a" (x=0): the exact cursor cell — the fill wins
        // outright over both the selection fill and the row wash, and picks
        // up bold. Column "a" has a custom red fg, which still survives.
        final cursorCell = buffer[(x: 0, y: 3)];
        expect(cursorCell.fg, equals(Color.red));
        expect(cursorCell.bg, equals(Theme.dark.cursor.color));
        expect(cursorCell.modifier.has(Modifier.bold), isTrue);
      });
    });

    group('header and separator derivation', () {
      test('header has no fg of its own and turns on bold', () {
        final model = _model();
        final buffer = renderBuffer(model, width: 11, height: 5);

        final header = buffer[(x: 0, y: 0)];
        expect(header.fg, equals(Color.reset), reason: 'the header inherits the ground; only bold is its own');
        expect(header.modifier.has(Modifier.bold), isTrue);
      });

      test('separator derives from border.ink in the header and in rows', () {
        final model = _model();
        final buffer = renderBuffer(model, width: 11, height: 5);

        expect(buffer[(x: 5, y: 0)].fg, equals(Theme.dark.border.color));
        expect(buffer[(x: 5, y: 1)].fg, equals(Theme.dark.border.color));
      });
    });

    group('pending and placeholder derivation', () {
      test('a hole inside the loaded range uses the pending default', () {
        // Page 1 (rows 2-3) is missing between page 0 (0-1) and page 2 (4-5),
        // the way a concurrent forward+backward load can leave a gap.
        final model = TableViewModel(keyField: 'id', columns: _columns(), pageSize: 2, totalCount: 6)
          ..insertRows(_rows(6).sublist(0, 2), 0)
          ..insertRows(_rows(6).sublist(4, 6), 2);

        final buffer = renderBuffer(model, width: 11, height: 7);

        // Row index 2 falls in the hole and paints the pending placeholder.
        final cell = buffer[(x: 0, y: 3)];
        expect(cell.fg, equals(Theme.dark.muted.color));
      });

      test('the empty-state placeholder uses the muted default', () {
        final model = TableViewModel(rows: const <Map<String, Object?>>[], keyField: 'id', columns: _columns());

        final buffer = renderBuffer(model, width: 11, height: 3, emptyPlaceholder: Line('No data'));
        expect(buffer[(x: 0, y: 1)].fg, equals(Theme.dark.muted.color));
      });
    });

    group('per-slot override wins over derivation', () {
      test('an explicit selectedRow style wins outright', () {
        const override = Style(fg: Color.green, bg: Color.blue);
        // Select row 0, then move the cursor away so row 0 is selected but
        // not also the cursor row (which would layer a wash on top).
        final model = _model(selectionEnabled: true)
          ..update(const KeyMsg('space'))
          ..update(const KeyMsg('down'))
          ..update(const KeyMsg('down'));

        final buffer = renderBuffer(model, width: 11, height: 5, style: const TableViewStyle(selectedRow: override));
        final cell = buffer[(x: 6, y: 1)]; // column "b", no custom fg to fight with

        expect(cell.fg, equals(Color.green));
        expect(cell.bg, equals(Color.blue));
      });

      test('an explicit header style wins outright', () {
        const override = Style(fg: Color.yellow);
        final model = _model();

        final buffer = renderBuffer(model, width: 11, height: 5, style: const TableViewStyle(header: override));
        final header = buffer[(x: 0, y: 0)];

        expect(header.fg, equals(Color.yellow));
        expect(header.modifier.has(Modifier.bold), isFalse, reason: 'the override is exact — no implicit bold');
      });

      test('an explicit cursorCell style wins outright', () {
        const override = Style(fg: Color.white, bg: Color.magenta);
        // Column "a" has its own explicit red fg from its render callback,
        // which always wins over any cell-level style — move the cursor to
        // column "b" so the override is the only fg in play.
        final model = _model()..update(const KeyMsg('right'));

        final buffer = renderBuffer(model, width: 11, height: 5, style: const TableViewStyle(cursorCell: override));
        final cell = buffer[(x: 6, y: 1)];

        expect(cell.fg, equals(Color.white));
        expect(cell.bg, equals(Color.magenta));
      });
    });

    group('a column style resolves at paint', () {
      TableViewModel modelWithColumnStyle(Style Function(StyleResolver resolver) style) {
        final columns = [
          TableColumn(field: 'a', label: Line('A'), width: 5, style: style),
          TableColumn(field: 'b', label: Line('B'), width: 5),
        ];
        return TableViewModel(rows: _rows(4), keyField: 'id', columns: columns)..insertRows(_rows(4), 0);
      }

      test('a column style paints the tone and follows a theme switch', () {
        final model = modelWithColumnStyle((r) => r.ink(r.tones.success));

        // Row index 1 (screen y=2): neither the cursor row nor selected, so
        // only the row base and the column's own style land on it.
        final darkCell = renderBuffer(model, width: 11, height: 5)[(x: 0, y: 2)];
        expect(darkCell.fg, equals(Theme.dark.success.color));

        final lightCell = renderBuffer(model, width: 11, height: 5, theme: Theme.light)[(x: 0, y: 2)];
        expect(lightCell.fg, equals(Theme.light.success.color));
      });

      test('a column style that sets only a foreground keeps the row slot background', () {
        const rowStyle = Style(bg: Color.blue);
        final model = modelWithColumnStyle((r) => r.ink(r.tones.success));

        final cell = renderBuffer(
          model,
          width: 11,
          height: 5,
          style: const TableViewStyle(row: rowStyle),
        )[(x: 0, y: 2)];

        expect(cell.fg, equals(Theme.dark.success.color));
        expect(cell.bg, equals(Color.blue));
      });
    });
  });
}
