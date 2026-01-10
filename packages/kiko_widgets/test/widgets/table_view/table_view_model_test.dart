import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// Sample rows for testing.
List<Map<String, Object?>> sampleRows([int count = 5]) => List.generate(
  count,
  (i) => {'id': 'row$i', 'name': 'Name $i', 'value': i * 10},
);

/// Sample columns for testing.
List<TableColumn> sampleColumns() => [
  TableColumn(field: 'id', label: Line('ID')),
  TableColumn(field: 'name', label: Line('Name')),
  TableColumn(field: 'value', label: Line('Value')),
];

void main() {
  group('TableViewModel', () {
    group('initialization', () {
      test('default state', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList(sampleRows()),
          keyField: 'id',
          columns: sampleColumns(),
        );
        expect(model.cursorRow, equals(0));
        expect(model.cursorCol, equals(0));
        expect(model.selectedKeys, isEmpty);
        expect(model.focused, isFalse);
        expect(model.isLoading, isFalse);
      });

      test('config fields', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList(sampleRows()),
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 100,
          windowSize: 500,
          loadThreshold: 20,
          stickyHeader: false,
          selectionEnabled: true,
          focused: true,
        );
        expect(model.pageSize, equals(100));
        expect(model.windowSize, equals(500));
        expect(model.loadThreshold, equals(20));
        expect(model.stickyHeader, isFalse);
        expect(model.selectionEnabled, isTrue);
        expect(model.focused, isTrue);
      });

      test('totalCount from dataSource', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList(sampleRows(10)),
          keyField: 'id',
          columns: sampleColumns(),
        );
        expect(model.totalCount, equals(10));
      });
    });

    group('data management', () {
      test('insertRows adds to cache', () async {
        final source = TableDataSource.fromList(sampleRows(100));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 10,
        );

        final page = await source.getPage(0, 10);
        model.insertRows(page, 0);

        expect(model.cachedRowCount, equals(10));
        expect(model.loadedRange, equals((0, 10)));
        expect(model.getRow(0)?['id'], equals('row0'));
        expect(model.getRow(9)?['id'], equals('row9'));
      });

      test('insertRows updates loaded range', () async {
        final source = TableDataSource.fromList(sampleRows(100));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 10,
        );

        final page0 = await source.getPage(0, 10);
        final page1 = await source.getPage(1, 10);
        model
          ..insertRows(page0, 0)
          ..insertRows(page1, 1);

        expect(model.cachedRowCount, equals(20));
        expect(model.loadedRange, equals((0, 20)));
      });

      test('window eviction removes furthest rows', () async {
        final source = TableDataSource.fromList(sampleRows(100));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 10,
          windowSize: 15, // Small window to force eviction
        );

        final page0 = await source.getPage(0, 10);
        final page1 = await source.getPage(1, 10);
        model
          ..insertRows(page0, 0)
          ..insertRows(page1, 1);

        // Window size is 15, so 5 rows should be evicted
        expect(model.cachedRowCount, equals(15));
      });

      test('reset clears state', () async {
        final source = TableDataSource.fromList(sampleRows(20));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          selectionEnabled: true,
          focused: true,
        )..setVisibleDimensions(10, 3);

        final page = await source.getPage(0, 10);
        model
          ..insertRows(page, 0)
          ..update(keyMsg('down'))
          ..update(keyMsg('space'));

        expect(model.cursorRow, equals(1));
        expect(model.selectedKeys.length, equals(1));

        model.reset();

        expect(model.cursorRow, equals(0));
        expect(model.cursorCol, equals(0));
        expect(model.selectedKeys, isEmpty);
        expect(model.cachedRowCount, equals(0));
      });
    });

    group('cursor movement - vertical', () {
      late TableViewModel model;

      setUp(() async {
        final source = TableDataSource.fromList(sampleRows(20));
        model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 20);
        model.insertRows(page, 0);
      });

      test('down moves cursor', () {
        model.update(keyMsg('down'));
        expect(model.cursorRow, equals(1));
      });

      test('j moves cursor down (vim)', () {
        model.update(keyMsg('j'));
        expect(model.cursorRow, equals(1));
      });

      test('up moves cursor', () {
        model
          ..update(keyMsg('down'))
          ..update(keyMsg('up'));
        expect(model.cursorRow, equals(0));
      });

      test('k moves cursor up (vim)', () {
        model
          ..update(keyMsg('j'))
          ..update(keyMsg('k'));
        expect(model.cursorRow, equals(0));
      });

      test('up at first row stays at 0', () {
        model.update(keyMsg('up'));
        expect(model.cursorRow, equals(0));
      });

      test('down at last row stays at end', () {
        for (var i = 0; i < 30; i++) {
          model.update(keyMsg('down'));
        }
        expect(model.cursorRow, equals(19));
      });

      test('home moves to first loaded', () {
        model
          ..update(keyMsg('down'))
          ..update(keyMsg('down'))
          ..update(keyMsg('home'));
        expect(model.cursorRow, equals(0));
      });

      test('end moves to last loaded', () {
        model.update(keyMsg('end'));
        expect(model.cursorRow, equals(19));
      });

      test('pageDown moves by visible count', () {
        model.update(keyMsg('pageDown'));
        expect(model.cursorRow, equals(5));
      });

      test('pageUp moves by visible count', () {
        model
          ..update(keyMsg('end'))
          ..update(keyMsg('pageUp'));
        expect(model.cursorRow, equals(14));
      });
    });

    group('cursor movement - horizontal', () {
      late TableViewModel model;

      setUp(() async {
        final source = TableDataSource.fromList(sampleRows());
        model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..setVisibleDimensions(5, 2);

        final page = await source.getPage(0, 5);
        model.insertRows(page, 0);
      });

      test('right moves cursor', () {
        model.update(keyMsg('right'));
        expect(model.cursorCol, equals(1));
      });

      test('l moves cursor right (vim)', () {
        model.update(keyMsg('l'));
        expect(model.cursorCol, equals(1));
      });

      test('left moves cursor', () {
        model
          ..update(keyMsg('right'))
          ..update(keyMsg('left'));
        expect(model.cursorCol, equals(0));
      });

      test('h moves cursor left (vim)', () {
        model
          ..update(keyMsg('l'))
          ..update(keyMsg('h'));
        expect(model.cursorCol, equals(0));
      });

      test('left at first col stays at 0', () {
        model.update(keyMsg('left'));
        expect(model.cursorCol, equals(0));
      });

      test('right at last col stays at end', () {
        for (var i = 0; i < 10; i++) {
          model.update(keyMsg('right'));
        }
        expect(model.cursorCol, equals(2)); // 3 columns, index 2
      });

      test('ctrl+left moves to first col', () {
        model
          ..update(keyMsg('right'))
          ..update(keyMsg('right'))
          ..update(keyMsg('ctrl+left'));
        expect(model.cursorCol, equals(0));
      });

      test('ctrl+right moves to last col', () {
        model.update(keyMsg('ctrl+right'));
        expect(model.cursorCol, equals(2));
      });
    });

    group('scroll offset', () {
      late TableViewModel model;

      setUp(() async {
        final source = TableDataSource.fromList(sampleRows(50));
        model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..setVisibleDimensions(5, 2);

        final page = await source.getPage(0, 50);
        model.insertRows(page, 0);
      });

      test('scrollRow adjusts when cursor moves below visible', () {
        for (var i = 0; i < 6; i++) {
          model.update(keyMsg('down'));
        }
        expect(model.cursorRow, equals(6));
        expect(model.scrollRow, equals(2));
      });

      test('scrollRow adjusts when cursor moves above visible', () {
        // Move down then up
        for (var i = 0; i < 10; i++) {
          model.update(keyMsg('down'));
        }
        for (var i = 0; i < 8; i++) {
          model.update(keyMsg('up'));
        }
        expect(model.cursorRow, equals(2));
        expect(model.scrollRow, equals(2));
      });

      test('scrollCol adjusts when cursor moves right', () {
        model
          ..update(keyMsg('right'))
          ..update(keyMsg('right'));
        expect(model.cursorCol, equals(2));
        expect(model.scrollCol, equals(1)); // 2 visible cols
      });

      test('verticalScroll returns correct values', () {
        final state = model.verticalScroll;
        expect(state.visible, equals(5));
        expect(state.total, equals(50));
        expect(state.offset, equals(0));
      });
    });

    group('selection', () {
      test('space does nothing without selectionEnabled', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 5);
        model
          ..insertRows(page, 0)
          ..update(keyMsg('space'));

        expect(model.selectedKeys, isEmpty);
      });

      test('space toggles selection', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          selectionEnabled: true,
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 5);
        model
          ..insertRows(page, 0)
          ..update(keyMsg('space'));

        expect(model.selectedKeys, equals({'row0'}));
        expect(model.isSelected(0), isTrue);
        expect(model.isSelected(1), isFalse);
      });

      test('space toggles off', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          selectionEnabled: true,
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 5);
        model
          ..insertRows(page, 0)
          ..update(keyMsg('space'))
          ..update(keyMsg('space'));

        expect(model.selectedKeys, isEmpty);
      });

      test('multiple rows can be selected', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          selectionEnabled: true,
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 5);
        model
          ..insertRows(page, 0)
          ..update(keyMsg('space'))
          ..update(keyMsg('down'))
          ..update(keyMsg('space'))
          ..update(keyMsg('down'))
          ..update(keyMsg('space'));

        expect(model.selectedKeys, equals({'row0', 'row1', 'row2'}));
      });

      test('selection persists after eviction', () async {
        final source = TableDataSource.fromList(sampleRows(100));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          selectionEnabled: true,
          pageSize: 10,
          windowSize: 15,
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page0 = await source.getPage(0, 10);
        model
          ..insertRows(page0, 0)
          ..update(keyMsg('space')); // Select row0

        // Load more pages to trigger eviction
        final page1 = await source.getPage(1, 10);
        final page2 = await source.getPage(2, 10);
        model
          ..insertRows(page1, 1)
          ..insertRows(page2, 2);

        // Selection should persist even if row was evicted
        expect(model.selectedKeys, contains('row0'));
      });
    });

    group('cursor getters', () {
      late TableViewModel model;

      setUp(() async {
        final source = TableDataSource.fromList(sampleRows());
        model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 5);
        model.insertRows(page, 0);
      });

      test('cursorRowKey returns key', () {
        expect(model.cursorRowKey, equals('row0'));
        model.update(keyMsg('down'));
        expect(model.cursorRowKey, equals('row1'));
      });

      test('cursorColField returns field name', () {
        expect(model.cursorColField, equals('id'));
        model.update(keyMsg('right'));
        expect(model.cursorColField, equals('name'));
      });

      test('cursorCellValue returns value', () {
        expect(model.cursorCellValue, equals('row0'));
        model.update(keyMsg('right'));
        expect(model.cursorCellValue, equals('Name 0'));
      });

      test('cursorRowData returns full row', () {
        final row = model.cursorRowData;
        expect(row?['id'], equals('row0'));
        expect(row?['name'], equals('Name 0'));
        expect(row?['value'], equals(0));
      });
    });

    group('commands', () {
      test('enter returns TableActionCmd with primary action', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 5);
        model.insertRows(page, 0);

        final cmd = model.update(keyMsg('enter'));
        expect(cmd, isA<TableActionCmd>());
        final actionCmd = cmd! as TableActionCmd;
        expect(actionCmd.source, same(model));
        expect(actionCmd.action, 'primary');
      });

      test('unhandled key returns Unhandled', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList(sampleRows()),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        );
        final cmd = model.update(keyMsg('tab'));
        expect(cmd, isA<Unhandled>());
      });

      test('unfocused returns Unhandled', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList(sampleRows()),
          keyField: 'id',
          columns: sampleColumns(),
        );
        final cmd = model.update(keyMsg('down'));
        expect(cmd, isA<Unhandled>());
      });

      test('non-key message returns null', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList(sampleRows()),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        );
        final cmd = model.update(const NoneMsg());
        expect(cmd, isNull);
      });

      test('loading state ignores input', () async {
        final source = TableDataSource.fromList(sampleRows());
        final model =
            TableViewModel(
                dataSource: source,
                keyField: 'id',
                columns: sampleColumns(),
                focused: true,
              )
              ..setVisibleDimensions(5, 3)
              ..isLoading = true;

        final page = await source.getPage(0, 5);
        model.insertRows(page, 0);

        final cmd = model.update(keyMsg('down'));
        expect(cmd, isNull);
        expect(model.cursorRow, equals(0)); // Didn't move
      });
    });

    group('LoadPageCmd', () {
      test('emitted when near end with hasMore', () async {
        final source = _PaginatedSource(sampleRows(20));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          loadThreshold: 5,
          pageSize: 10,
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 10);
        model.insertRows(page, 0);

        // Move cursor near end of loaded data
        for (var i = 0; i < 6; i++) {
          model.update(keyMsg('down'));
        }

        final cmd = model.update(keyMsg('down'));
        expect(cmd, isA<LoadPageCmd>());
        expect((cmd! as LoadPageCmd).direction, equals(LoadDirection.forward));
      });

      test('not emitted when hasMore is false', () async {
        final source = TableDataSource.fromList(sampleRows(10));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          loadThreshold: 3,
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 10);
        model.insertRows(page, 0);

        // Move to near end
        for (var i = 0; i < 8; i++) {
          model.update(keyMsg('down'));
        }

        final cmd = model.update(keyMsg('down'));
        // fromList has hasMore = false
        expect(cmd, isNull);
      });

      test('nextPageNum returns correct value', () async {
        final source = TableDataSource.fromList(sampleRows(100));
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 10,
          focused: true,
        );

        final page0 = await source.getPage(0, 10);
        model.insertRows(page0, 0);

        expect(model.nextPageNum, equals(1));

        final page1 = await source.getPage(1, 10);
        model.insertRows(page1, 1);

        expect(model.nextPageNum, equals(2));
      });
    });

    group('visible columns', () {
      test('hidden columns are excluded', () async {
        final columns = [
          TableColumn(field: 'id', label: Line('ID'), width: 10),
          TableColumn(
            field: 'hidden',
            label: Line('Hidden'),
            visible: false,
          ),
          TableColumn(field: 'name', label: Line('Name')),
        ];

        final source = TableDataSource.fromList(sampleRows());
        final model = TableViewModel(
          dataSource: source,
          keyField: 'id',
          columns: columns,
          focused: true,
        )..setVisibleDimensions(5, 3);

        final page = await source.getPage(0, 5);
        model.insertRows(page, 0);

        expect(model.totalColumns, equals(2)); // id and name only
        expect(model.cursorColField, equals('id'));
        model.update(keyMsg('right'));
        expect(model.cursorColField, equals('name')); // Skipped hidden
      });
    });

    group('empty table', () {
      test('handles empty data source', () {
        final model = TableViewModel(
          dataSource: TableDataSource.fromList([]),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        );
        expect(model.cursorRow, equals(0));
        expect(model.cursorRowKey, isNull);
        expect(model.cachedRowCount, equals(0));
      });

      test('navigation on empty table is safe', () {
        final model =
            TableViewModel(
                dataSource: TableDataSource.fromList([]),
                keyField: 'id',
                columns: sampleColumns(),
                focused: true,
              )
              ..setVisibleDimensions(5, 3)
              // Should not throw
              ..update(keyMsg('down'))
              ..update(keyMsg('up'))
              ..update(keyMsg('home'))
              ..update(keyMsg('end'))
              ..update(keyMsg('right'))
              ..update(keyMsg('left'));

        expect(model.cursorRow, equals(0));
        expect(model.cursorCol, equals(0));
      });
    });
  });

  group('TableDataSource', () {
    test('fromList creates adapter', () async {
      final source = TableDataSource.fromList(sampleRows(10));
      expect(source.totalCount, equals(10));
      expect(source.hasMore, isFalse);

      final page = await source.getPage(0, 5);
      expect(page.length, equals(5));
      expect(page[0]['id'], equals('row0'));
    });

    test('getPage handles out of bounds', () async {
      final source = TableDataSource.fromList(sampleRows());
      final page = await source.getPage(10, 5); // Way past end
      expect(page, isEmpty);
    });

    test('getPage returns partial page at end', () async {
      final source = TableDataSource.fromList(sampleRows(7));
      final page = await source.getPage(1, 5); // Starts at 5, only 2 left
      expect(page.length, equals(2));
    });
  });

  group('TableScrollState', () {
    test('progress calculation', () {
      const state = TableScrollState(offset: 5, visible: 10, total: 20);
      expect(state.progress, equals(0.5));
    });

    test('progress null when total unknown', () {
      const state = TableScrollState(offset: 0, visible: 10, total: null);
      expect(state.progress, isNull);
    });

    test('progress null when all visible', () {
      const state = TableScrollState(offset: 0, visible: 10, total: 5);
      expect(state.progress, isNull);
    });

    test('thumbSize calculation', () {
      const state = TableScrollState(offset: 0, visible: 10, total: 100);
      expect(state.thumbSize, equals(0.1));
    });

    test('thumbSize minimum 0.1', () {
      const state = TableScrollState(offset: 0, visible: 1, total: 1000);
      expect(state.thumbSize, equals(0.1));
    });
  });
}

/// Test data source with hasMore = true.
class _PaginatedSource implements TableDataSource {
  final List<Map<String, Object?>> _rows;
  _PaginatedSource(this._rows);

  @override
  Future<List<Map<String, Object?>>> getPage(int pageNum, int pageSize) async {
    final start = pageNum * pageSize;
    if (start >= _rows.length) return [];
    final end = (start + pageSize).clamp(0, _rows.length);
    return _rows.sublist(start, end);
  }

  @override
  bool get hasMore => true;

  @override
  int? get totalCount => _rows.length;
}
