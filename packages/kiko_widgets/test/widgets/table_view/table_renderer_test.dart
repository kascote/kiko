import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';
import '../../support/viewport.dart';

/// Sample rows for testing.
List<Map<String, Object?>> sampleRows([int count = 5]) => List.generate(
  count,
  (i) => {'id': 'r$i', 'name': 'Name $i', 'val': i * 10},
);

/// Sample columns for testing.
List<TableColumn> sampleColumns() => [
  TableColumn(field: 'id', label: Line('ID'), width: 5),
  TableColumn(field: 'name', label: Line('Name'), width: 10),
  TableColumn(field: 'val', label: Line('Value'), width: 8),
];

/// Paints [model] through a [TableRenderer] into a fresh buffer and dumps
/// the result as plain text (blank surrounding lines stripped, trailing
/// whitespace trimmed per line — matching what the old widget-capture
/// harness presented).
String render(
  TableViewModel model, {
  required int width,
  required int height,
  bool showEmptyCells = false,
  TextMeasurer measurer = const TermUnicodeMeasurer(),
  Line? emptyPlaceholder,
  Line Function(int index)? pendingBuilder,
}) {
  final buffer = Buffer.empty(
    Rect.create(x: 0, y: 0, width: width, height: height),
    measurer: measurer,
  );
  final surface = BufferSurface(buffer);
  TableRenderer(
    model,
    Theme.dark,
    measurer: measurer,
    emptyPlaceholder: emptyPlaceholder,
    pendingBuilder: pendingBuilder,
  ).paint(buffer.area, surface);
  // Paint reports the viewport it showed; the runtime delivers the report to
  // the model once the frame commits. Do the same here.
  surface.reports.forEach(model.update);
  return _dump(buffer, showEmptyCells: showEmptyCells);
}

String _dump(Buffer buffer, {required bool showEmptyCells}) {
  final area = buffer.area;
  final lines = <String>[];
  for (var y = 0; y < area.height; y++) {
    final row = StringBuffer();
    for (var x = 0; x < area.width; x++) {
      final cell = buffer[(x: area.x + x, y: area.y + y)];
      if (cell.skip) continue;
      final symbol = cell.symbol;
      row.write(showEmptyCells && symbol == ' ' ? '·' : symbol);
    }
    lines.add(row.toString().trimRight());
  }

  var start = 0;
  while (start < lines.length && lines[start].isEmpty) {
    start++;
  }
  var end = lines.length - 1;
  while (end >= start && lines[end].isEmpty) {
    end--;
  }
  if (start > end) return '';
  return lines.sublist(start, end + 1).join('\n');
}

void main() {
  group('TableRenderer', () {
    group('basic rendering', () {
      test('renders header and rows', () async {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
          focused: true,
        );

        expect(
          render(model, width: 23, height: 4),
          equals(
            '''
ID   Name      Value
r0   Name 0    0
r1   Name 1    10
r2   Name 2    20''',
          ),
        );
      });

      test('a paint whose viewport the model already holds reports nothing', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
        );
        final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 23, height: 4));
        final first = BufferSurface(buffer);
        TableRenderer(model, Theme.dark).paint(buffer.area, first);
        first.reports.forEach(model.update);
        expect(model.visibleRows, equals(3));

        final second = BufferSurface(buffer);
        TableRenderer(model, Theme.dark).paint(buffer.area, second);

        expect(second.reports, isEmpty, reason: 'the model holds the viewport, so the frame a report causes settles');
      });

      test('reports the visible dimensions', () async {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
        );
        final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 23, height: 4));
        final surface = BufferSurface(buffer);

        TableRenderer(model, Theme.dark).paint(buffer.area, surface);

        // 4 total - 1 header = 3 visible rows
        final report = surface.reports.single as ViewportChanged;
        expect(report.id, model.id);
        expect(report.rows, equals(3));
        expect(report.cols, equals(3));
        expect(model.visibleRows, equals(0), reason: 'paint reports; it never writes into the model');

        model.update(report);
        expect(model.visibleRows, equals(3));
        expect(model.visibleCols, equals(3));
      });

      test('stickyHeader=false omits header', () async {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
          stickyHeader: false,
        );

        // First row is data, not header
        expect(
          render(model, width: 23, height: 3),
          equals(
            '''
r0   Name 0    0
r1   Name 1    10
r2   Name 2    20''',
          ),
        );
      });
    });

    group('column handling', () {
      test('respects column visibility', () async {
        final columns = [
          TableColumn(field: 'id', label: Line('ID'), width: 5),
          TableColumn(field: 'name', label: Line('Name'), width: 10, visible: false),
          TableColumn(field: 'val', label: Line('Value'), width: 8),
        ];
        final model = TableViewModel(
          rows: sampleRows().take(3).toList(),
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
        );

        // Only ID and Value columns visible
        expect(
          render(model, width: 13, height: 2),
          equals(
            '''
ID   Value
r0   0''',
          ),
        );
      });

      test('columns snap to width boundary', () async {
        final model = TableViewModel(
          rows: sampleRows().take(3).toList(),
          keyField: 'id',
          columns: sampleColumns(),
        );

        // Width=5: ID(5) + Name(10) = 15 > 5, so only ID fits
        final result = render(model, width: 5, height: 2);

        expect(result, equals('ID\nr0'));
        expect(model.visibleCols, equals(1));
      });

      test('horizontal scroll shows later columns', () async {
        final model =
            TableViewModel(
                rows: sampleRows().take(3).toList(),
                keyField: 'id',
                columns: sampleColumns(),
                focused: true,
              )
              ..viewport(rows: 3, cols: 1)
              ..update(const KeyMsg('right'))
              ..update(const KeyMsg('right'));

        // scrollCol=2 shows Value column
        expect(
          render(model, width: 8, height: 2),
          equals(
            '''
Value
0''',
          ),
        );
      });
    });

    group('column separator', () {
      test('default separator adds space between columns', () async {
        final columns = [
          TableColumn(field: 'a', label: Line('A'), width: 5),
          TableColumn(field: 'b', label: Line('B'), width: 8),
        ];
        final rows = [
          {'id': 'r0', 'a': 'X', 'b': 'Y'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          // default separator is Text(' ')
        );

        // 5 + 1 (sep) + 8 = 14
        expect(
          render(model, width: 14, height: 2),
          equals(
            '''
A     B
X     Y''',
          ),
        );
      });

      test('custom separator with style', () async {
        final columns = [
          TableColumn(field: 'a', label: Line('A'), width: 5),
          TableColumn(field: 'b', label: Line('B'), width: 8),
        ];
        final rows = [
          {'id': 'r0', 'a': 'X', 'b': 'Y'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(' | '),
        );

        // 5 + 3 (sep) + 8 = 16
        expect(
          render(model, width: 16, height: 2),
          equals(
            '''
A     | B
X     | Y''',
          ),
        );
      });

      test('empty separator joins columns', () async {
        final columns = [
          TableColumn(field: 'a', label: Line('A'), width: 5),
          TableColumn(field: 'b', label: Line('B'), width: 8),
        ];
        final rows = [
          {'id': 'r0', 'a': 'X', 'b': 'Y'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
        );

        // 5 + 0 (sep) + 8 = 13
        expect(
          render(model, width: 13, height: 2),
          equals(
            '''
A    B
X    Y''',
          ),
        );
      });

      test('separator affects visible column count', () async {
        final model = TableViewModel(
          rows: sampleRows().take(3).toList(),
          keyField: 'id',
          columns: sampleColumns(), // 5 + 10 + 8 = 23
          // default separator adds 2 chars = 25 total
        );

        // Width 23 can't fit all 3 columns with separators
        render(model, width: 23, height: 2);
        expect(model.visibleCols, equals(2));

        // Width 25 can fit all 3 columns
        render(model, width: 25, height: 2);
        expect(model.visibleCols, equals(3));
      });

      test('horizontal scroll with separator', () async {
        // 3 columns: A(5) + sep(3) + B(6) + sep(3) + C(5) = 22 total
        // Width 14 fits only 2 cols: A(5) + sep(3) + B(6) = 14
        final columns = [
          TableColumn(field: 'a', label: Line('ColA'), width: 5),
          TableColumn(field: 'b', label: Line('ColB'), width: 6),
          TableColumn(field: 'c', label: Line('ColC'), width: 5),
        ];
        final rows = [
          {'id': 'r0', 'a': 'A0', 'b': 'B0', 'c': 'C0'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(' | '),
          focused: true,
        )..viewport(rows: 1, cols: 2);

        // Initial: shows ColA and ColB
        var result = render(model, width: 14, height: 2);
        expect(
          result,
          equals(
            '''
ColA  | ColB
A0    | B0''',
          ),
        );
        expect(model.visibleCols, equals(2));

        // Move cursor right twice to reach ColC
        model
          ..update(const KeyMsg('right'))
          ..update(const KeyMsg('right'));

        // Now scrollCol=1, shows ColB and ColC
        result = render(model, width: 14, height: 2);
        expect(
          result,
          equals(
            '''
ColB   | ColC
B0     | C0''',
          ),
        );
        expect(model.visibleCols, equals(2));
      });
    });

    group('truncation', () {
      test('truncates long content with ellipsis', () async {
        final rows = [
          {'id': 'r0', 'name': 'VeryLongNameThatExceeds', 'val': 0},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
        );

        // Name truncated to "VeryLongN…"
        expect(
          render(model, width: 23, height: 2),
          equals(
            '''
ID   Name      Value
r0   VeryLongN…0''',
          ),
        );
      });

      test('uses custom ellipsis', () async {
        final rows = [
          {'id': 'r0', 'name': 'LongEnoughToTrunc', 'val': 0},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
          ellipsis: '...',
        );

        expect(
          render(model, width: 23, height: 2),
          equals(
            '''
ID   Name      Value
r0   LongEno...0''',
          ),
        );
      });

      test('an ambiguous-width value truncates and aligns to fill the column under either measurer', () async {
        // '°' is ambiguous-width: 1 cell under a default measurer, 2 under a
        // cjk one. Whichever measurer is in effect, the cell must still land
        // on the column boundary exactly — no overflow into the next column,
        // no short fill.
        final columns = [
          TableColumn(field: 'val', label: Line(''), width: 5),
          TableColumn(field: 'next', label: Line(''), width: 3),
        ];
        final rows = [
          {'id': 'r0', 'val': '°°°°°°°°°°', 'next': 'XYZ'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
          ellipsis: '.',
          stickyHeader: false,
        );

        // Default: '°' is 1 cell wide, so 4 fit before the ellipsis.
        expect(
          render(model, width: 8, height: 1),
          equals('°°°°.XYZ'),
        );

        // cjk: '°' is 2 cells wide, so only 2 fit — but the column still
        // ends up exactly 5 cells wide, so ColB starts at the same offset.
        expect(
          render(model, width: 8, height: 1, measurer: const TermUnicodeMeasurer(cjk: true)),
          equals('°°.XYZ'),
        );
      });
    });

    group('grapheme-safe truncation', () {
      test('keeps a multi-codepoint grapheme cluster whole when it fits exactly', () async {
        // Thumbs-up + skin-tone modifier is one grapheme cluster, 2 cells
        // wide (not 4 — the old codepoint-walking loop summed each
        // codepoint's own width and cut the cluster in half).
        const skinToneThumbsUp = '\u{1F44D}\u{1F3FD}';
        final columns = [
          TableColumn(field: 'val', label: Line(''), width: 3),
        ];
        final rows = [
          {'id': 'r0', 'val': '${skinToneThumbsUp}AB'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
          ellipsis: '.',
          stickyHeader: false,
        );

        // Column width 3, ellipsis 1 cell → 2 cells left for content, exactly
        // the emoji's width: it is kept whole (with its modifier), not
        // trimmed to a bare thumbs-up.
        expect(render(model, width: 3, height: 1), equals('$skinToneThumbsUp.'));
      });

      test('drops a multi-codepoint grapheme cluster whole when it does not fit', () async {
        const skinToneThumbsUp = '\u{1F44D}\u{1F3FD}';
        final columns = [
          TableColumn(field: 'val', label: Line(''), width: 2),
        ];
        final rows = [
          {'id': 'r0', 'val': '${skinToneThumbsUp}Z'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
          ellipsis: '.',
          stickyHeader: false,
        );

        // Column width 2, ellipsis 1 cell → only 1 cell left, too narrow for
        // the 2-cell-wide emoji: it is dropped whole, leaving no stray
        // codepoint from the cluster in the output.
        expect(
          render(model, width: 2, height: 1, showEmptyCells: true),
          equals('.·'),
        );
      });
    });

    group('alignment', () {
      test('left alignment (default)', () async {
        final columns = [
          TableColumn(field: 'id', label: Line('ID'), width: 8),
        ];
        final rows = [
          {'id': 'X'},
        ];
        final model = TableViewModel(rows: rows, keyField: 'id', columns: columns);

        expect(render(model, width: 8, height: 2), equals('ID\nX'));
      });

      test('right alignment', () async {
        final columns = [
          TableColumn(field: 'id', label: Line('ID'), width: 8, alignment: TextAlign.end),
        ];
        final rows = [
          {'id': 'X'},
        ];
        final model = TableViewModel(rows: rows, keyField: 'id', columns: columns);

        expect(
          render(model, width: 8, height: 2, showEmptyCells: true),
          equals(
            '''
······ID
·······X''',
          ),
        );
      });

      test('center alignment', () async {
        final columns = [
          TableColumn(field: 'id', label: Line('ID'), width: 8, alignment: TextAlign.center),
        ];
        final rows = [
          {'id': 'XX'},
        ];
        final model = TableViewModel(rows: rows, keyField: 'id', columns: columns);

        expect(
          render(model, width: 8, height: 2, showEmptyCells: true),
          equals(
            '''
···ID···
···XX···''',
          ),
        );
      });
    });

    group('custom render', () {
      test('uses column render callback', () async {
        final columns = [
          TableColumn(
            field: 'id',
            label: Line('ID'),
            width: 10,
            render: (ctx) => Line('[${ctx.value ?? '?'}]'),
          ),
        ];
        final rows = [
          {'id': 'abc'},
        ];
        final model = TableViewModel(rows: rows, keyField: 'id', columns: columns);

        expect(
          render(model, width: 10, height: 2),
          equals(
            '''
ID
[abc]''',
          ),
        );
      });
    });

    group('CellRenderContext', () {
      test('provides value and row data', () async {
        CellRenderContext? captured;
        final columns = [
          TableColumn(
            field: 'name',
            label: Line('Name'),
            width: 10,
            render: (ctx) {
              captured = ctx;
              return Line(ctx.value.toString());
            },
          ),
        ];
        final rows = [
          {'id': 'r0', 'name': 'Alice', 'score': 100},
        ];
        final model = TableViewModel(rows: rows, keyField: 'id', columns: columns);
        render(model, width: 10, height: 2);

        expect(captured, isNotNull);
        expect(captured!.value, equals('Alice'));
        expect(captured!.row['id'], equals('r0'));
        expect(captured!.row['score'], equals(100));
      });

      test('provides rowIndex and colIndex', () async {
        final contexts = <CellRenderContext>[];
        final columns = [
          TableColumn(
            field: 'a',
            label: Line('A'),
            width: 5,
            render: (ctx) {
              contexts.add(ctx);
              return Line('');
            },
          ),
          TableColumn(
            field: 'b',
            label: Line('B'),
            width: 5,
            render: (ctx) {
              contexts.add(ctx);
              return Line('');
            },
          ),
        ];
        final rows = [
          {'id': 'r0', 'a': 1, 'b': 2},
          {'id': 'r1', 'a': 3, 'b': 4},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
        );
        render(model, width: 10, height: 3);

        // 2 rows x 2 cols = 4 contexts
        expect(contexts.length, equals(4));
        // Row 0, Col 0
        expect(contexts[0].rowIndex, equals(0));
        expect(contexts[0].colIndex, equals(0));
        // Row 0, Col 1
        expect(contexts[1].rowIndex, equals(0));
        expect(contexts[1].colIndex, equals(1));
        // Row 1, Col 0
        expect(contexts[2].rowIndex, equals(1));
        expect(contexts[2].colIndex, equals(0));
        // Row 1, Col 1
        expect(contexts[3].rowIndex, equals(1));
        expect(contexts[3].colIndex, equals(1));
      });

      test('provides cursorRow and cursorCell', () async {
        final contexts = <CellRenderContext>[];
        final columns = [
          TableColumn(
            field: 'a',
            label: Line('A'),
            width: 5,
            render: (ctx) {
              contexts.add(ctx);
              return Line('');
            },
          ),
          TableColumn(
            field: 'b',
            label: Line('B'),
            width: 5,
            render: (ctx) {
              contexts.add(ctx);
              return Line('');
            },
          ),
        ];
        final rows = [
          {'id': 'r0', 'a': 1, 'b': 2},
          {'id': 'r1', 'a': 3, 'b': 4},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
          focused: true,
        )..viewport(rows: 2, cols: 2);

        // Cursor at row 0, col 0 (default)
        contexts.clear();
        render(model, width: 10, height: 3);

        // Row 0 is cursor row
        expect(contexts[0].cursorRow, isTrue);
        expect(contexts[0].cursorCell, isTrue); // col 0
        expect(contexts[1].cursorRow, isTrue);
        expect(contexts[1].cursorCell, isFalse); // col 1
        // Row 1 is not cursor row
        expect(contexts[2].cursorRow, isFalse);
        expect(contexts[3].cursorRow, isFalse);

        // Move cursor to row 1, col 1
        model
          ..update(const KeyMsg('down'))
          ..update(const KeyMsg('right'));
        contexts.clear();
        render(model, width: 10, height: 3);

        // Row 0 is not cursor row
        expect(contexts[0].cursorRow, isFalse);
        expect(contexts[1].cursorRow, isFalse);
        // Row 1 is cursor row
        expect(contexts[2].cursorRow, isTrue);
        expect(contexts[2].cursorCell, isFalse); // col 0
        expect(contexts[3].cursorRow, isTrue);
        expect(contexts[3].cursorCell, isTrue); // col 1
      });

      test('provides selected', () async {
        final contexts = <CellRenderContext>[];
        final columns = [
          TableColumn(
            field: 'a',
            label: Line('A'),
            width: 10,
            render: (ctx) {
              contexts.add(ctx);
              return Line('');
            },
          ),
        ];
        final rows = [
          {'id': 'r0', 'a': 1},
          {'id': 'r1', 'a': 2},
        ];
        final model =
            TableViewModel(
                rows: rows,
                keyField: 'id',
                columns: columns,
                selectionEnabled: true,
                focused: true,
              )
              // Select row 0
              ..viewport(rows: 2, cols: 1)
              ..update(const KeyMsg('space'));
        contexts.clear();
        render(model, width: 10, height: 3);

        expect(contexts[0].selected, isTrue);
        expect(contexts[1].selected, isFalse);
      });

      test('provides hover', () async {
        final contexts = <CellRenderContext>[];
        final columns = [
          TableColumn(
            field: 'a',
            label: Line('A'),
            width: 10,
            render: (ctx) {
              contexts.add(ctx);
              return Line('');
            },
          ),
        ];
        final rows = [
          {'id': 'r0', 'a': 1},
          {'id': 'r1', 'a': 2},
        ];
        final model = TableViewModel(rows: rows, keyField: 'id', columns: columns)
          ..viewport(rows: 2, cols: 1)
          ..hoverRow = 1;
        render(model, width: 10, height: 3);

        expect(contexts[0].hover, isFalse);
        expect(contexts[1].hover, isTrue);
      });

      test('provides totalCount', () async {
        CellRenderContext? captured;
        final columns = [
          TableColumn(
            field: 'a',
            label: Line('A'),
            width: 10,
            render: (ctx) {
              captured = ctx;
              return Line('');
            },
          ),
        ];
        final rows = List.generate(50, (i) => {'id': 'r$i', 'a': i});
        final model = TableViewModel(rows: rows, keyField: 'id', columns: columns);
        render(model, width: 10, height: 2);

        expect(captured!.totalCount, equals(50));
      });

      test('provides column reference', () async {
        CellRenderContext? captured;
        final col = TableColumn(
          field: 'a',
          label: Line('A'),
          width: 15,
          alignment: TextAlign.end,
          render: (ctx) {
            captured = ctx;
            return Line('');
          },
        );
        final rows = [
          {'id': 'r0', 'a': 1},
        ];
        final model = TableViewModel(rows: rows, keyField: 'id', columns: [col]);
        render(model, width: 15, height: 2);

        expect(captured!.column, same(col));
        expect(captured!.column.field, equals('a'));
        expect(captured!.column.width, equals(15));
        expect(captured!.column.alignment, equals(TextAlign.end));
      });

      test('render can access other columns via row', () async {
        // Example: format name based on status from another column
        final columns = [
          TableColumn(
            field: 'name',
            label: Line('Name'),
            width: 10,
            render: (ctx) {
              final status = ctx.row['status']! as String;
              final name = ctx.value! as String;
              return Line(status == 'active' ? '$name*' : name);
            },
          ),
          TableColumn(field: 'status', label: Line('St'), width: 5),
        ];
        final rows = [
          {'id': 'r0', 'name': 'Alice', 'status': 'active'},
          {'id': 'r1', 'name': 'Bob', 'status': 'idle'},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Text(''),
        );

        expect(
          render(model, width: 15, height: 3),
          equals(
            '''
Name      St
Alice*    acti…
Bob       idle''',
          ),
        );
      });
    });

    group('empty and loading states', () {
      test('renders empty placeholder', () {
        final model = TableViewModel(
          rows: const <Map<String, Object?>>[],
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
        );

        expect(
          render(model, width: 23, height: 3, emptyPlaceholder: Line('No data')),
          equals(
            '''
ID   Name      Value
No data''',
          ),
        );
      });

      test('renders loading indicator for missing rows', () async {
        final model = TableViewModel(
          rows: sampleRows(10).take(2).toList(),
          totalCount: 10,
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
        )..viewport(rows: 5, cols: 3);

        expect(
          render(model, width: 23, height: 4, pendingBuilder: (_) => Line('...')),
          equals(
            '''
ID   Name      Value
r0   Name 0    0
r1   Name 1    10
...''',
          ),
        );
      });
    });

    group('filling and stalled', () {
      /// A table over a 120-row source holding only its first page, with the
      /// viewport parked on rows 20-22 — inside a page it does not have.
      TableViewModel parkedOffPage() =>
          TableViewModel(
              totalCount: 120,
              keyField: 'id',
              columns: sampleColumns(),
              columnSeparator: const Text(''),
              pageSize: 10,
            )
            ..insertRows(sampleRows(10), 0)
            ..viewport(rows: 3, cols: 3)
            ..scrollBy(20);

      test('while a fetch is in flight the nearest held rows paint, not skeletons', () {
        // page 2 (and its neighbours) go on their way
        final model = parkedOffPage()..demand();

        expect(model.viewportStatus, SliceStatus.filling);
        expect(
          render(model, width: 23, height: 4),
          equals('''
ID   Name      Value
r7   Name 7    70
r8   Name 8    80
r9   Name 9    90'''),
          reason: 'the last complete range keeps the table readable during the jump',
        );
      });

      test('with nothing coming the rows paint as skeletons at the real position', () {
        final model = parkedOffPage();

        expect(model.viewportStatus, SliceStatus.stalled);
        final painted = render(model, width: 23, height: 4);
        expect(painted, contains('░'), reason: 'a skeleton keeps the row shape');
        expect(painted, isNot(contains('r7')), reason: 'no stale rows once nothing is coming');
      });

      test('a skeleton keeps the columns and separators of a real row', () {
        final model = TableViewModel(totalCount: 20, keyField: 'id', columns: sampleColumns(), pageSize: 10);

        // Nothing is held, so every visible row is a skeleton.
        final painted = render(model, width: 25, height: 3);
        expect(painted.split('\n').length, equals(3), reason: 'header plus two skeleton rows');
        for (final line in painted.split('\n').skip(1)) {
          expect(line, matches(RegExp(r'^░+ +░+ +░+$')), reason: 'one dim run per column: $line');
        }
      });

      test('a pendingBuilder still replaces the skeleton with its own line', () {
        final model = TableViewModel(totalCount: 20, keyField: 'id', columns: sampleColumns(), pageSize: 10);

        expect(
          render(model, width: 25, height: 2, pendingBuilder: (_) => Line('Loading...')),
          endsWith('Loading...'),
        );
      });
    });

    group('vertical scrolling', () {
      test('scrolls to show cursor row', () async {
        final model = TableViewModel(
          rows: sampleRows(10),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..viewport(rows: 3, cols: 3);

        // Move cursor down past visible area
        for (var i = 0; i < 5; i++) {
          model.update(const KeyMsg('down'));
        }

        // Should show rows around cursor (row 5)
        expect(render(model, width: 23, height: 4), contains('r5'));
      });
    });

    group('edge cases', () {
      test('handles empty area', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
        );

        // Should not throw
        expect(() => render(model, width: 0, height: 0), returnsNormally);
      });

      test('handles area smaller than header', () async {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
        );

        // Height 1 with sticky header = 0 data rows, returns early
        expect(render(model, width: 23, height: 1), isEmpty);
      });

      test('handles no visible columns', () async {
        final columns = [
          TableColumn(field: 'id', label: Line('ID')),
        ];
        final model = TableViewModel(rows: sampleRows(), keyField: 'id', columns: columns);

        // Width too narrow for column - should not throw
        expect(() => render(model, width: 5, height: 3), returnsNormally);
      });

      test('handles null cell values', () async {
        final rows = [
          {'id': 'r0', 'name': null, 'val': null},
        ];
        final model = TableViewModel(
          rows: rows,
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Text(''),
        );

        // Null renders as empty
        expect(
          render(model, width: 23, height: 2),
          equals(
            '''
ID   Name      Value
r0''',
          ),
        );
      });
    });
  });
}
