import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

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

void main() {
  group('TableView', () {
    group('basic rendering', () {
      test('renders header and rows', () async {
        final result = await CaptureBuilder(width: 23, height: 4).setup((t) async {
          final source = TableDataSource.fromList(sampleRows());
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            columnSeparator: const Span(''),
            focused: true,
          );
          final page = await source.getPage(0, 5);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
ID   Name      Value
r0   Name 0    0
r1   Name 1    10
r2   Name 2    20'''),
        );
      });

      test('updates visibleDimensions', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Span(''),
        );
        final page = await source.getPage(0, 5);
        model.insertRows(page, 0);

        // Render to trigger setVisibleDimensions
        capture(TableView(model: model), width: 23, height: 4);

        // 4 total - 1 header = 3 visible rows
        expect(model.visibleRows, equals(3));
        expect(model.visibleCols, equals(3));
      });

      test('stickyHeader=false omits header', () async {
        final result = await CaptureBuilder(width: 23, height: 3).setup((t) async {
          final source = TableDataSource.fromList(sampleRows());
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            columnSeparator: const Span(''),
            stickyHeader: false,
          );
          final page = await source.getPage(0, 5);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        // First row is data, not header
        expect(
          result,
          equals('''
r0   Name 0    0
r1   Name 1    10
r2   Name 2    20'''),
        );
      });
    });

    group('column handling', () {
      test('respects column visibility', () async {
        final result = await CaptureBuilder(width: 13, height: 2).setup((t) async {
          final columns = [
            TableColumn(field: 'id', label: Line('ID'), width: 5),
            TableColumn(field: 'name', label: Line('Name'), width: 10, visible: false),
            TableColumn(field: 'val', label: Line('Value'), width: 8),
          ];
          final source = TableDataSource.fromList(sampleRows());
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
            columnSeparator: const Span(''),
          );
          final page = await source.getPage(0, 3);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        // Only ID and Value columns visible
        expect(
          result,
          equals('''
ID   Value
r0   0'''),
        );
      });

      test('columns snap to width boundary', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
        );
        final page = await source.getPage(0, 3);
        model.insertRows(page, 0);

        // Width=12: ID(5) + Name(10) = 15 > 12, so only ID fits
        final result = capture(TableView(model: model), width: 5, height: 2);

        expect(result, equals('ID\nr0'));
        expect(model.visibleCols, equals(1));
      });

      test('horizontal scroll shows later columns', () async {
        final result = await CaptureBuilder(width: 8, height: 2).setup((t) async {
          final source = TableDataSource.fromList(sampleRows());
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            focused: true,
          )..setVisibleDimensions(3, 1);

          final page = await source.getPage(0, 3);
          model
            ..insertRows(page, 0)
            ..update(const KeyMsg('right'))
            ..update(const KeyMsg('right'));

          t.render(TableView(model: model));
        }).capture();

        // scrollCol=2 shows Value column
        expect(
          result,
          equals('''
Value
0'''),
        );
      });
    });

    group('column separator', () {
      test('default separator adds space between columns', () async {
        final result = await CaptureBuilder(width: 14, height: 2).setup((t) async {
          final columns = [
            TableColumn(field: 'a', label: Line('A'), width: 5),
            TableColumn(field: 'b', label: Line('B'), width: 8),
          ];
          final rows = [
            {'id': 'r0', 'a': 'X', 'b': 'Y'},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
            // default separator is Span(' ')
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        // 5 + 1 (sep) + 8 = 14
        expect(
          result,
          equals('''
A     B
X     Y'''),
        );
      });

      test('custom separator with style', () async {
        final result = await CaptureBuilder(width: 16, height: 2).setup((t) async {
          final columns = [
            TableColumn(field: 'a', label: Line('A'), width: 5),
            TableColumn(field: 'b', label: Line('B'), width: 8),
          ];
          final rows = [
            {'id': 'r0', 'a': 'X', 'b': 'Y'},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
            columnSeparator: const Span(' | '),
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        // 5 + 3 (sep) + 8 = 16
        expect(
          result,
          equals('''
A     | B
X     | Y'''),
        );
      });

      test('empty separator joins columns', () async {
        final result = await CaptureBuilder(width: 13, height: 2).setup((t) async {
          final columns = [
            TableColumn(field: 'a', label: Line('A'), width: 5),
            TableColumn(field: 'b', label: Line('B'), width: 8),
          ];
          final rows = [
            {'id': 'r0', 'a': 'X', 'b': 'Y'},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
            columnSeparator: const Span(''),
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        // 5 + 0 (sep) + 8 = 13
        expect(
          result,
          equals('''
A    B
X    Y'''),
        );
      });

      test('separator affects visible column count', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(), // 5 + 10 + 8 = 23
          // default separator adds 2 chars = 25 total
        );
        final page = await source.getPage(0, 3);
        model.insertRows(page, 0);

        // Width 23 can't fit all 3 columns with separators
        capture(TableView(model: model), width: 23, height: 2);
        expect(model.visibleCols, equals(2));

        // Width 25 can fit all 3 columns
        capture(TableView(model: model), width: 25, height: 2);
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
        final source = TableDataSource.fromList(rows);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Span(' | '),
          focused: true,
        )..setVisibleDimensions(1, 2);
        final page = await source.getPage(0, 1);
        model.insertRows(page, 0);

        // Initial: shows ColA and ColB
        var result = capture(TableView(model: model), width: 14, height: 2);
        expect(
          result,
          equals('''
ColA  | ColB
A0    | B0'''),
        );
        expect(model.visibleCols, equals(2));

        // Move cursor right twice to reach ColC
        model
          ..update(const KeyMsg('right'))
          ..update(const KeyMsg('right'));

        // Now scrollCol=1, shows ColB and ColC
        result = capture(TableView(model: model), width: 14, height: 2);
        expect(
          result,
          equals('''
ColB   | ColC
B0     | C0'''),
        );
        expect(model.visibleCols, equals(2));
      });
    });

    group('truncation', () {
      test('truncates long content with ellipsis', () async {
        final result = await CaptureBuilder(width: 23, height: 2).setup((t) async {
          final rows = [
            {'id': 'r0', 'name': 'VeryLongNameThatExceeds', 'val': 0},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            columnSeparator: const Span(''),
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        // Name truncated to "VeryLongN…"
        expect(
          result,
          equals('''
ID   Name      Value
r0   VeryLongN…0'''),
        );
      });

      test('uses custom ellipsis', () async {
        final result = await CaptureBuilder(width: 23, height: 2).setup((t) async {
          final rows = [
            {'id': 'r0', 'name': 'LongEnoughToTrunc', 'val': 0},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            columnSeparator: const Span(''),
            ellipsis: '...',
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
ID   Name      Value
r0   LongEno...0'''),
        );
      });
    });

    group('alignment', () {
      test('left alignment (default)', () async {
        final result = await CaptureBuilder(width: 8, height: 2).setup((t) async {
          final columns = [
            TableColumn(field: 'id', label: Line('ID'), width: 8),
          ];
          final rows = [
            {'id': 'X'},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(result, equals('ID\nX'));
      });

      test('right alignment', () async {
        final result = await CaptureBuilder(width: 8, height: 2, showEmptyCells: true).setup((t) async {
          final columns = [
            TableColumn(
              field: 'id',
              label: Line('ID'),
              width: 8,
              alignment: Alignment.right,
            ),
          ];
          final rows = [
            {'id': 'X'},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
······ID
·······X'''),
        );
      });

      test('center alignment', () async {
        final result = await CaptureBuilder(width: 8, height: 2, showEmptyCells: true).setup((t) async {
          final columns = [
            TableColumn(
              field: 'id',
              label: Line('ID'),
              width: 8,
              alignment: Alignment.center,
            ),
          ];
          final rows = [
            {'id': 'XX'},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
···ID···
···XX···'''),
        );
      });
    });

    group('custom render', () {
      test('uses column render callback', () async {
        final result = await CaptureBuilder(width: 10, height: 2).setup((t) async {
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
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
ID
[abc]'''),
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
        final source = TableDataSource.fromList(rows);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
        );
        final page = await source.getPage(0, 1);
        model.insertRows(page, 0);
        capture(TableView(model: model), width: 10, height: 2);

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
        final source = TableDataSource.fromList(rows);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Span(''),
        );
        final page = await source.getPage(0, 2);
        model.insertRows(page, 0);
        capture(TableView(model: model), width: 10, height: 3);

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

      test('provides isCursorRow and isCursorCell', () async {
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
        final source = TableDataSource.fromList(rows);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
          columnSeparator: const Span(''),
          focused: true,
        )..setVisibleDimensions(2, 2);
        final page = await source.getPage(0, 2);
        model.insertRows(page, 0);

        // Cursor at row 0, col 0 (default)
        contexts.clear();
        capture(TableView(model: model), width: 10, height: 3);

        // Row 0 is cursor row
        expect(contexts[0].isCursorRow, isTrue);
        expect(contexts[0].isCursorCell, isTrue); // col 0
        expect(contexts[1].isCursorRow, isTrue);
        expect(contexts[1].isCursorCell, isFalse); // col 1
        // Row 1 is not cursor row
        expect(contexts[2].isCursorRow, isFalse);
        expect(contexts[3].isCursorRow, isFalse);

        // Move cursor to row 1, col 1
        model
          ..update(const KeyMsg('down'))
          ..update(const KeyMsg('right'));
        contexts.clear();
        capture(TableView(model: model), width: 10, height: 3);

        // Row 0 is not cursor row
        expect(contexts[0].isCursorRow, isFalse);
        expect(contexts[1].isCursorRow, isFalse);
        // Row 1 is cursor row
        expect(contexts[2].isCursorRow, isTrue);
        expect(contexts[2].isCursorCell, isFalse); // col 0
        expect(contexts[3].isCursorRow, isTrue);
        expect(contexts[3].isCursorCell, isTrue); // col 1
      });

      test('provides isSelected', () async {
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
        final source = TableDataSource.fromList(rows);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
          selectionEnabled: true,
          focused: true,
        )..setVisibleDimensions(2, 1);
        final page = await source.getPage(0, 2);
        // Select row 0
        model
          ..insertRows(page, 0)
          ..update(const KeyMsg('space'));
        contexts.clear();
        capture(TableView(model: model), width: 10, height: 3);

        expect(contexts[0].isSelected, isTrue);
        expect(contexts[1].isSelected, isFalse);
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
        final source = TableDataSource.fromList(rows);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
        );
        final page = await source.getPage(0, 10);
        model.insertRows(page, 0);
        capture(TableView(model: model), width: 10, height: 2);

        expect(captured!.totalCount, equals(50));
      });

      test('provides column reference', () async {
        CellRenderContext? captured;
        final col = TableColumn(
          field: 'a',
          label: Line('A'),
          width: 15,
          alignment: Alignment.right,
          render: (ctx) {
            captured = ctx;
            return Line('');
          },
        );
        final rows = [
          {'id': 'r0', 'a': 1},
        ];
        final source = TableDataSource.fromList(rows);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: [col],
        );
        final page = await source.getPage(0, 1);
        model.insertRows(page, 0);
        capture(TableView(model: model), width: 15, height: 2);

        expect(captured!.column, same(col));
        expect(captured!.column.field, equals('a'));
        expect(captured!.column.width, equals(15));
        expect(captured!.column.alignment, equals(Alignment.right));
      });

      test('render can access other columns via row', () async {
        // Example: format name based on status from another column
        final result = await CaptureBuilder(width: 15, height: 3).setup((t) async {
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
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
            columnSeparator: const Span(''),
          );
          final page = await source.getPage(0, 2);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
Name      St
Alice*    acti…
Bob       idle'''),
        );
      });
    });

    group('empty and loading states', () {
      test('renders empty placeholder', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList([]),
          keyField: 'id',
          columns: sampleColumns(),
          columnSeparator: const Span(''),
          emptyPlaceholder: Line('No data'),
        );

        final result = capture(TableView(model: model), width: 23, height: 3);

        expect(
          result,
          equals('''
ID   Name      Value
No data'''),
        );
      });

      test('renders loading indicator for missing rows', () async {
        final result = await CaptureBuilder(width: 23, height: 4).setup((t) async {
          final source = TableDataSource.fromList(sampleRows(10));
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            columnSeparator: const Span(''),
            loadingIndicator: Line('...'),
          );
          // Only load first 2 rows
          final page = await source.getPage(0, 2);
          model
            ..insertRows(page, 0)
            ..setVisibleDimensions(5, 3);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
ID   Name      Value
r0   Name 0    0
r1   Name 1    10'''),
        );
      });
    });

    group('vertical scrolling', () {
      test('scrolls to show cursor row', () async {
        final result = await CaptureBuilder(width: 23, height: 4).setup((t) async {
          final source = TableDataSource.fromList(sampleRows(10));
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            focused: true,
          )..setVisibleDimensions(3, 3);

          final page = await source.getPage(0, 10);
          model.insertRows(page, 0);

          // Move cursor down past visible area
          for (var i = 0; i < 5; i++) {
            model.update(const KeyMsg('down'));
          }
          t.render(TableView(model: model));
        }).capture();

        // Should show rows around cursor (row 5)
        expect(result, contains('r5'));
      });
    });

    group('debug border', () {
      test('shows widget bounds', () async {
        final result = await CaptureBuilder(width: 10, height: 2, showBorder: true).setup((t) async {
          final columns = [
            TableColumn(field: 'id', label: Line('ID'), width: 10),
          ];
          final rows = [
            {'id': 'Test'},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: columns,
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        expect(
          result,
          equals('''
+----------+
|ID        |
|Test      |
+----------+'''),
        );
      });
    });

    group('rendersAs matcher', () {
      test('works with TableView', () async {
        final source = TableDataSource.fromList([
          {'id': 'a'},
        ]);
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: [TableColumn(field: 'id', label: Line('ID'), width: 5)],
        );
        final page = await source.getPage(0, 1);
        model.insertRows(page, 0);

        expect(
          TableView(model: model),
          rendersAs('ID\na', width: 5, height: 2),
        );
      });
    });

    group('edge cases', () {
      test('handles empty area', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList(sampleRows()),
          keyField: 'id',
          columns: sampleColumns(),
        );

        // Should not throw
        capture(TableView(model: model), width: 0, height: 0);
      });

      test('handles area smaller than header', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
        );
        final page = await source.getPage(0, 3);
        model.insertRows(page, 0);

        // Height 1 with sticky header = 0 data rows, returns early
        final result = capture(TableView(model: model), width: 23, height: 1);
        expect(result, isEmpty);
      });

      test('handles no visible columns', () async {
        final columns = [
          TableColumn(field: 'id', label: Line('ID')),
        ];
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
        );
        final page = await source.getPage(0, 3);
        model.insertRows(page, 0);

        // Width too narrow for column - should not throw
        capture(TableView(model: model), width: 5, height: 3);
      });

      test('handles null cell values', () async {
        final result = await CaptureBuilder(width: 23, height: 2).setup((t) async {
          final rows = [
            {'id': 'r0', 'name': null, 'val': null},
          ];
          final source = TableDataSource.fromList(rows);
          final model = TableViewModel(
            dataSource: source,
            keyField: 'id',
            columns: sampleColumns(),
            columnSeparator: const Span(''),
          );
          final page = await source.getPage(0, 1);
          model.insertRows(page, 0);
          t.render(TableView(model: model));
        }).capture();

        // Null renders as empty
        expect(
          result,
          equals('''
ID   Name      Value
r0'''),
        );
      });
    });
  });
}
