import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';
import '../../support/viewport.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// A routed wheel/button message over the widget, at local (0, 0), on no marked
/// part.
PointerMsg pointer(PointerAction action) => PointerMsg(global: Position.origin, action: action, local: Position.origin);

/// A routed button/move message over data row [row], the way the framework
/// delivers it once the view has marked the row and the router resolved it.
PointerMsg pointerOnRow(PointerAction action, int row) =>
    PointerMsg(global: Position.origin, action: action, local: Position.origin, region: RowRegion(row));

/// A routed button/move message over the sticky header.
PointerMsg pointerOnHeader(PointerAction action) => PointerMsg(
  global: Position.origin,
  action: action,
  local: Position.origin,
  region: const TableHeaderRegion(),
);

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

/// The page requests a command carries — one demand pass can ask for several
/// pages at once, which travel as a [Batch].
List<LoadRequest> requestsIn(Cmd? cmd) => switch (cmd) {
  final LoadRequest r => [r],
  Batch(:final cmds) => cmds.whereType<LoadRequest>().toList(),
  _ => const [],
};

/// The same, for whatever an update returned.
List<LoadRequest> requestsOf(UpdateResult result) => result is Handled ? requestsIn(result.cmd) : const [];

/// The pages a command asked for, ascending.
List<int> pagesIn(Cmd? cmd) => requestsIn(cmd).map((r) => (r.key! as PageKey).page).toList()..sort();

/// The pages an update asked for, ascending.
List<int> pagesAsked(UpdateResult result) => pagesIn(result is Handled ? result.cmd : null);

/// A message no model understands: the probe for the decline path.
class _UnknownMsg extends Msg {
  const _UnknownMsg();
}

void main() {
  group('mouse wheel + scroll', () {
    test('a wheel notch scrolls an unfocused table without moving the cursor', () {
      final model =
          TableViewModel(
              rows: sampleRows(20),
              keyField: 'id',
              columns: sampleColumns(),
            )
            ..viewport(rows: 5, cols: 3)
            ..insertRows(sampleRows(20), 0);

      final result = model.update(pointer(PointerAction.wheelDown));

      expect(result, isA<Handled>());
      expect(model.scrollRow, equals(3), reason: 'one notch is three rows');
      expect(model.cursorRow, equals(0), reason: 'the wheel never touches the keyboard cursor');
    });

    test('scrollBy clamps to the loaded window', () {
      final model =
          TableViewModel(
              rows: sampleRows(10),
              keyField: 'id',
              columns: sampleColumns(),
            )
            ..viewport(rows: 4, cols: 3)
            ..insertRows(sampleRows(10), 0);

      expect((model..scrollBy(-5)).scrollRow, equals(0), reason: 'cannot scroll above the first row');
      expect((model..scrollBy(100)).scrollRow, equals(6), reason: 'stops at loadedEnd - visibleRows (10 - 4)');
    });

    test('a horizontal wheel and other pointers are declined', () {
      final model =
          TableViewModel(
              rows: sampleRows(10),
              keyField: 'id',
              columns: sampleColumns(),
              focused: true,
            )
            ..viewport(rows: 4, cols: 3)
            ..insertRows(sampleRows(10), 0);

      expect(model.update(pointer(PointerAction.wheelLeft)), isA<Declined>());
      expect(model.update(pointer(PointerAction.down)), isA<Declined>());
      expect(model.scrollRow, equals(0), reason: 'neither moved the viewport');
    });

    test('a wheel toward the bottom edge asks for the page it is heading into (unfocused)', () {
      final model =
          TableViewModel(
              totalCount: 120,
              keyField: 'id',
              columns: sampleColumns(),
              pageSize: 10,
              loadThreshold: 3,
            )
            ..viewport(rows: 5, cols: 3)
            ..insertRows(sampleRows(10), 0);

      // One notch carries the viewport's bottom edge within the threshold of
      // page 1, and demand asks for the page the viewport now covers.
      final result = model.update(pointer(PointerAction.wheelDown));

      expect(pagesAsked(result), equals([1]));
      expect(model.isLoading(const PageKey(1)), isTrue, reason: 'wheel alone crossed the load threshold');
    });

    group('wheel decline at the scroll limit (mikos 0175 / G2)', () {
      TableViewModel scrollable({int rows = 10, int visible = 5}) =>
          TableViewModel(
              rows: sampleRows(rows),
              keyField: 'id',
              columns: sampleColumns(),
            )
            ..viewport(rows: visible, cols: 3)
            ..insertRows(sampleRows(rows), 0);

      test('at the top, wheel-up declines while wheel-down handles', () {
        final model = scrollable();
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Declined>());
        expect(model.scrollRow, equals(0), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Handled>());
      });

      test('at the bottom, wheel-down declines while wheel-up handles', () {
        final model = scrollable()..scrollBy(100); // pin to the bottom edge
        final atBottom = model.scrollRow;
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Declined>());
        expect(model.scrollRow, equals(atBottom), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Handled>());
      });

      test('content that fits entirely declines both directions', () {
        final model = scrollable(rows: 3);
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Declined>());
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Declined>());
      });

      test('a partial scroll still consumes, even though it moves fewer rows than a full notch', () {
        // scrollRow 4, max 5 (10 loaded - 5 visible): a 3-row notch down can
        // only move 1 row, but 1 row is not a no-op, so it must still handle.
        final model = scrollable()..scrollBy(4);
        expect(model.scrollRow, equals(4));

        final result = model.update(pointer(PointerAction.wheelDown));
        expect(result, isA<Handled>());
        expect(model.scrollRow, equals(5), reason: 'moved the 1 remaining row');
      });

      test('mid-content, both directions handle', () {
        final model = scrollable()..scrollBy(2);
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Handled>());
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Handled>());
      });
    });
  });

  group('mouse click + hover', () {
    TableViewModel table({bool focused = true}) =>
        TableViewModel(
            id: 'grid',
            rows: sampleRows(10),
            keyField: 'id',
            columns: sampleColumns(),
            focused: focused,
          )
          ..viewport(rows: 6, cols: 3)
          ..insertRows(sampleRows(10), 0);

    test('a click on a data row moves the cursor there and emits TableActionCmd', () {
      final model = table();

      final down = model.update(pointerOnRow(PointerAction.down, 2));

      expect(down, isA<Handled>().having((h) => h.cmd, 'cmd', const TableActionCmd('grid', 'primary')));
      expect(model.cursorRow, equals(2));
    });

    test('a click on a row the window does not hold moves the cursor but emits nothing', () {
      final model = TableViewModel(
        id: 'grid',
        totalCount: 6,
        keyField: 'id',
        columns: sampleColumns(),
        focused: true,
      )..viewport(rows: 6, cols: 3);

      final down = model.update(pointerOnRow(PointerAction.down, 3));

      expect(down, isA<Handled>().having((h) => h.cmd, 'cmd', isNull), reason: 'nothing to activate, press consumed');
      expect(model.cursorRow, equals(3), reason: 'the cursor still moves where the user pointed');
    });

    test('a press on the sticky header declines and never moves the cursor', () {
      final model = table();

      expect(model.update(pointerOnHeader(PointerAction.down)), isA<Declined>());
      expect(model.cursorRow, equals(0), reason: 'the header is not a data row');
    });

    test('a press on no marked part is declined', () {
      expect(table().update(pointer(PointerAction.down)), isA<Declined>());
    });

    test('a click selects on an unfocused table', () {
      final model = table(focused: false)..update(pointerOnRow(PointerAction.down, 1));

      expect(model.cursorRow, equals(1), reason: 'selection changes without a prior focus');
    });

    test('a pointer sets the hover row; a header or leave clears it', () {
      final model = table()..update(pointerOnRow(PointerAction.move, 2));
      expect(model.hoverRow, equals(2));

      model.update(pointerOnHeader(PointerAction.move));
      expect(model.hoverRow, isNull, reason: 'a move over the header clears the hover');

      model.update(const PointerLeaveMsg('grid'));
      expect(model.hoverRow, isNull);
    });
  });

  group('TableViewModel', () {
    group('initialization', () {
      test('default state', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
        );
        expect(model.cursorRow, equals(0));
        expect(model.cursorCol, equals(0));
        expect(model.getSelectedKeys(), isEmpty);
        expect(model.focused, isFalse);
        expect(model.isLoading(), isFalse);
      });

      test('config fields', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 100,
          keepPages: 2,
          loadThreshold: 20,
          maxConcurrentLoads: 1,
          stickyHeader: false,
          showCrosshair: true,
          selectionEnabled: true,
          focused: true,
        );
        expect(model.pageSize, equals(100));
        expect(model.keepPages, equals(2));
        expect(model.loadThreshold, equals(20));
        expect(model.maxConcurrentLoads, equals(1));
        expect(model.stickyHeader, isFalse);
        expect(model.showCrosshair, isTrue);
        expect(model.selectionEnabled, isTrue);
        expect(model.focused, isTrue);
      });

      test('showCrosshair defaults to false and is mutable', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
        );
        expect(model.showCrosshair, isFalse);

        model.showCrosshair = true;
        expect(model.showCrosshair, isTrue);
      });

      test('a static table knows its own row count', () {
        final model = TableViewModel(
          rows: sampleRows(10),
          keyField: 'id',
          columns: sampleColumns(),
        );
        expect(model.totalCount, equals(10));
      });
    });

    group('data management', () {
      test('insertRows seeds the window as whole pages', () async {
        final model = TableViewModel(
          rows: sampleRows(100).take(10).toList(),
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 10,
        );

        expect(model.cachedRowCount, equals(10));
        expect(model.cachedPages, equals([0]));
        expect(model.getRow(0)?['id'], equals('row0'));
        expect(model.getRow(9)?['id'], equals('row9'));
      });

      test('insertRows splits more rows than a page holds', () {
        final model = TableViewModel(
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: 10,
          totalCount: 100,
        )..insertRows(sampleRows(25), 0);

        expect(model.cachedRowCount, equals(25));
        expect(model.cachedPages, equals([0, 1, 2]), reason: 'rows land on page boundaries, not wherever they fall');
        expect(model.getRow(24)?['id'], equals('row24'));
      });

      test('eviction drops whole pages, and never one the viewport needs', () {
        final model =
            TableViewModel(
                totalCount: 120,
                keyField: 'id',
                columns: sampleColumns(),
                pageSize: 10,
                keepPages: 0, // keep exactly what the viewport asks for
                loadThreshold: 0,
                focused: true,
              )
              ..viewport(rows: 5, cols: 3)
              ..insertRows(sampleRows(10), 0);

        // Jump to the end: the viewport now needs page 11, and asks for it.
        expect(pagesAsked(model.update(keyMsg('end'))), equals([11]));

        model.update(
          LoadResult<List<Map<String, Object?>>>(model.id, key: const PageKey(11), data: sampleRows(10)),
        );

        expect(model.cachedPages, equals([11]), reason: 'page 0 is whole pages away from the viewport');
        expect(model.cachedRowCount, equals(10), reason: 'a page is evicted whole, never row by row');
      });

      test('reset clears state', () async {
        final model =
            TableViewModel(
                rows: sampleRows(20).take(10).toList(),
                keyField: 'id',
                columns: sampleColumns(),
                selectionEnabled: true,
                focused: true,
              )
              ..viewport(rows: 10, cols: 3)
              ..update(keyMsg('down'))
              ..update(keyMsg('space'));

        expect(model.cursorRow, equals(1));
        expect(model.getSelectedKeys().length, equals(1));

        model.reset();

        expect(model.cursorRow, equals(0));
        expect(model.cursorCol, equals(0));
        expect(model.getSelectedKeys(), isEmpty);
        expect(model.cachedRowCount, equals(0));
      });
    });

    group('the end landing closer than navigation reached', () {
      // One held page of 5, end unknown: pages past it are presumed to exist,
      // so navigation runs ahead into rows whose fetch is still out.
      TableViewModel ranAhead() {
        final model =
            TableViewModel(
                keyField: 'id',
                columns: sampleColumns(),
                pageSize: 5,
                loadThreshold: 2,
                focused: true,
              )
              ..insertRows(sampleRows(), 0)
              ..viewport(rows: 3, cols: 3)
              ..update(keyMsg('pageDown')) // cursor 3 — demand puts page 1 in flight
              ..update(keyMsg('pageDown')) // cursor 6, into the pending page
              ..update(keyMsg('pageDown')); // cursor 9, scroll 7
        expect(model.cursorRow, equals(9));
        expect(model.scrollRow, equals(7));
        return model;
      }

      test('a short page pulls the cursor and viewport back to the real end', () {
        final model = ranAhead();
        final short = LoadResult<List<Map<String, Object?>>>(
          model.id,
          key: const PageKey(1),
          data: const [
            {'id': 'row5', 'name': 'Name 5', 'value': 50},
          ],
        );
        model.update(short);

        expect(model.knownRowCount, equals(6));
        expect(model.cursorRow, equals(5), reason: 'the rows past the end stopped existing');
        expect(model.scrollRow, equals(3), reason: 'the last row lands on the bottom line (6 - 3 visible)');
        expect(model.cursorRowKey, equals('row5'));
      });

      test('a count landing closer than the cursor pulls both back', () {
        final model = ranAhead()..totalCount = 6;

        expect(model.cursorRow, equals(5));
        expect(model.scrollRow, equals(3));
      });
    });

    group('cursor movement - vertical', () {
      late TableViewModel model;

      setUp(() async {
        model = TableViewModel(
          rows: sampleRows(20),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..viewport(rows: 5, cols: 3);
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
        model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..viewport(rows: 5, cols: 2);
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
        model = TableViewModel(
          rows: sampleRows(50),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..viewport(rows: 5, cols: 2);
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

      test('getScrollState returns correct values', () {
        final state = model.getScrollState();
        expect(state.visible, equals(5));
        expect(state.total, equals(50));
        expect(state.offset, equals(0));
      });
    });

    group('selection', () {
      test('space does nothing without selectionEnabled', () async {
        final model =
            TableViewModel(
                rows: sampleRows(),
                keyField: 'id',
                columns: sampleColumns(),
                focused: true,
              )
              ..viewport(rows: 5, cols: 3)
              ..update(keyMsg('space'));

        expect(model.getSelectedKeys(), isEmpty);
      });

      test('space toggles selection', () async {
        final model =
            TableViewModel(
                rows: sampleRows(),
                keyField: 'id',
                columns: sampleColumns(),
                selectionEnabled: true,
                focused: true,
              )
              ..viewport(rows: 5, cols: 3)
              ..update(keyMsg('space'));

        expect(model.getSelectedKeys(), equals({'row0'}));
        expect(model.isSelected(0), isTrue);
        expect(model.isSelected(1), isFalse);
      });

      test('space toggles off', () async {
        final model =
            TableViewModel(
                rows: sampleRows(),
                keyField: 'id',
                columns: sampleColumns(),
                selectionEnabled: true,
                focused: true,
              )
              ..viewport(rows: 5, cols: 3)
              ..update(keyMsg('space'))
              ..update(keyMsg('space'));

        expect(model.getSelectedKeys(), isEmpty);
      });

      test('multiple rows can be selected', () async {
        final model =
            TableViewModel(
                rows: sampleRows(),
                keyField: 'id',
                columns: sampleColumns(),
                selectionEnabled: true,
                focused: true,
              )
              ..viewport(rows: 5, cols: 3)
              ..update(keyMsg('space'))
              ..update(keyMsg('down'))
              ..update(keyMsg('space'))
              ..update(keyMsg('down'))
              ..update(keyMsg('space'));

        expect(model.getSelectedKeys(), equals({'row0', 'row1', 'row2'}));
      });

      test('selection persists after eviction', () {
        final model =
            TableViewModel(
                totalCount: 120,
                keyField: 'id',
                columns: sampleColumns(),
                selectionEnabled: true,
                pageSize: 10,
                keepPages: 0,
                loadThreshold: 0,
                focused: true,
              )
              ..viewport(rows: 5, cols: 3)
              ..insertRows(sampleRows(10), 0)
              ..update(keyMsg('space')) // select row0
              ..update(keyMsg('end'));

        model.update(
          LoadResult<List<Map<String, Object?>>>(model.id, key: const PageKey(11), data: sampleRows(10)),
        );

        // The row itself was evicted; the selection is keyed, not indexed.
        expect(model.getRow(0), isNull);
        expect(model.getSelectedKeys(), contains('row0'));
      });
    });

    group('cursor getters', () {
      late TableViewModel model;

      setUp(() async {
        model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..viewport(rows: 5, cols: 3);
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
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..viewport(rows: 5, cols: 3);

        final result = model.update(keyMsg('enter'));
        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isA<TableActionCmd>()),
        );
        final actionCmd = (result as Handled).cmd! as TableActionCmd;
        expect(actionCmd.id, equals(model.id));
        expect(actionCmd.action, 'primary');
      });

      test('enter on a row the window does not hold is consumed and emits nothing', () {
        final model = TableViewModel(
          totalCount: 4,
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        )..viewport(rows: 4, cols: 3);

        final result = model.update(keyMsg('enter'));

        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'a declined confirm would fire the app fallback bindings',
        );
      });

      test('declines unhandled key', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        );
        final result = model.update(keyMsg('tab'));
        expect(result, isA<Declined>());
      });

      test('declines when unfocused', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
        );
        final result = model.update(keyMsg('down'));
        expect(result, isA<Declined>());
      });

      test('declines a message it does not know', () {
        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: sampleColumns(),
          focused: true,
        );
        final result = model.update(const _UnknownMsg());
        expect(result, isA<Declined>());
      });

      test('navigation continues while a page is loading', () {
        // The blanket input-freeze is gone: a load in flight no longer stops the
        // cursor from moving.
        final model =
            TableViewModel(
                totalCount: 120,
                keyField: 'id',
                columns: sampleColumns(),
                pageSize: 10,
                loadThreshold: 8,
                focused: true,
              )
              ..viewport(rows: 5, cols: 2)
              ..insertRows(sampleRows(10), 0);

        // Reach the end to start loading the pages there.
        final result = model.update(keyMsg('end'));
        expect(requestsOf(result), isNotEmpty);
        expect(model.isLoading(), isTrue);

        final rowBefore = model.cursorRow;
        model.update(keyMsg('up'));
        expect(model.cursorRow, equals(rowBefore - 1));
        expect(model.isLoading(), isTrue, reason: 'load still in flight');
      });
    });

    group('LoadRequest', () {
      test('emitted when the viewport reaches into a page it does not have', () {
        final model = TableViewModel(
          rows: sampleRows(10),
          totalCount: 20,
          keyField: 'id',
          columns: sampleColumns(),
          loadThreshold: 5,
          pageSize: 10,
          focused: true,
        )..viewport(rows: 5, cols: 3);

        // Walk down until the viewport, widened by the threshold, reaches into
        // page 1 — the fifth step, where the bottom edge is row 5.
        var result = const Handled() as UpdateResult;
        for (var i = 0; i < 5; i++) {
          result = model.update(keyMsg('down'));
        }

        final asked = requestsOf(result);
        expect(asked, hasLength(1));
        expect(asked.single.id, equals(model.id));
        expect(asked.single.key, equals(const PageKey(1)));
        expect(model.isLoading(const PageKey(1)), isTrue, reason: 'self-marks on emit');
      });

      test('not emitted again while the same page is loading', () {
        final model = TableViewModel(
          rows: sampleRows(10),
          totalCount: 40,
          keyField: 'id',
          columns: sampleColumns(),
          loadThreshold: 5,
          pageSize: 10,
          focused: true,
        )..viewport(rows: 5, cols: 3);

        var result = const Handled() as UpdateResult;
        for (var i = 0; i < 5; i++) {
          result = model.update(keyMsg('down'));
        }
        // The viewport reaching into page 1 requests it.
        expect(pagesAsked(result), equals([1]));
        // Further near-end keypresses do not re-request it while it is in flight.
        expect(pagesAsked(model.update(keyMsg('down'))), isEmpty);
        expect(pagesAsked(model.update(keyMsg('up'))), isEmpty);
      });

      test('not emitted when hasMore is false', () async {
        final model = TableViewModel(
          rows: sampleRows(10).take(5).toList(),
          keyField: 'id',
          columns: sampleColumns(),
          loadThreshold: 3,
          focused: true,
        )..viewport(rows: 5, cols: 3);

        // Move to near end
        for (var i = 0; i < 8; i++) {
          model.update(keyMsg('down'));
        }

        final result = model.update(keyMsg('down'));
        // fromList has hasMore = false
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
      });

      test('a jump asks for the page it lands on, not the one after the loaded edge', () {
        final model =
            TableViewModel(
                totalCount: 500,
                keyField: 'id',
                columns: sampleColumns(),
                focused: true,
              )
              ..viewport(rows: 20, cols: 3)
              ..insertRows(sampleRows(50), 0);

        // Row 0 → row 499 in one step. Demand follows the viewport, so the
        // destination is fetched first and the eight pages in between are never
        // requested at all.
        final asked = pagesAsked(model.update(keyMsg('end')));

        expect(asked, contains(9), reason: 'the page the cursor landed on');
        expect(asked, isNot(contains(1)), reason: 'the page after the loaded edge is nowhere near the viewport');
        expect(requestsOf(model.update(keyMsg('end'))), isEmpty, reason: 'nothing is asked for twice');
      });
    });

    group('viewport reports', () {
      // One page of ten held out of forty; a viewport of five reaches nothing
      // more, a viewport of twenty reaches page 1.
      TableViewModel paged() => TableViewModel(
        id: 'grid',
        rows: sampleRows(10),
        totalCount: 40,
        keyField: 'id',
        columns: sampleColumns(),
        pageSize: 10,
        loadThreshold: 0,
      );

      test('a report equal to the stored rows and columns is consumed with no command', () {
        final model = paged()..viewport(rows: 5, cols: 3);

        final verdict = model.update(const ViewportChanged('grid', rows: 5, cols: 3));

        expect(verdict, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(model.visibleRows, equals(5));
        expect(model.visibleCols, equals(3));
      });

      test('changed rows are stored and return the demand for the pages they reveal', () {
        final model = paged()..viewport(rows: 5, cols: 3);

        final verdict = model.update(const ViewportChanged('grid', rows: 20, cols: 3));

        expect(model.visibleRows, equals(20));
        expect(pagesAsked(verdict), equals([1]));
      });

      test('changed columns are stored; a report with no column count keeps the stored one', () {
        final model = paged()..viewport(rows: 5, cols: 3);

        expect(model.update(const ViewportChanged('grid', rows: 5, cols: 2)), isA<Handled>());
        expect(model.visibleCols, equals(2));

        expect(model.update(const ViewportChanged('grid', rows: 5)), isA<Handled>());
        expect(model.visibleCols, equals(2), reason: 'a rows-only report says nothing about columns');
      });

      test('a report addressed to another id is declined', () {
        final model = paged();

        expect(model.update(const ViewportChanged('other', rows: 20, cols: 3)), isA<Declined>());
        expect(model.visibleRows, equals(0));
      });

      test("a report carrying this id's path under a scope is the table's own", () {
        final model = paged();

        expect(model.update(const ViewportChanged('form/grid', rows: 5, cols: 3)), isA<Handled>());
        expect(model.visibleRows, equals(5));
      });
    });

    group('load lifecycle', () {
      // A cold table before its first frame: the app's init fetch precedes any
      // viewport report, so nothing but what a test asks for is in flight. A
      // test that navigates reports the viewport first, as the first frame
      // would.
      TableViewModel paginated({int loadThreshold = 8}) => TableViewModel(
        totalCount: 120,
        keyField: 'id',
        columns: sampleColumns(),
        pageSize: 10,
        loadThreshold: loadThreshold,
        focused: true,
      );

      test('loadFirstPage begins page 0 and requests it', () {
        final model = paginated();
        final req = model.loadFirstPage();

        expect(req.id, equals(model.id));
        expect(req.key, equals(const PageKey(0)));
        expect(model.isLoading(const PageKey(0)), isTrue);

        model.update(LoadResult<List<Map<String, Object?>>>(model.id, key: req.key, data: sampleRows(10)));

        expect(model.cachedRowCount, equals(10));
        expect(model.cachedPages, equals([0]));
        expect(model.isLoading(const PageKey(0)), isFalse);
      });

      test('update(LoadResult) installs a page at the offset its key names', () {
        final model = paginated()
          ..insertRows(sampleRows(10), 0)
          ..viewport(rows: 5, cols: 2);

        model.update(
          LoadResult<List<Map<String, Object?>>>(
            model.id,
            key: const PageKey(3),
            data: sampleRows(10),
          ),
        );
        expect(model.cachedPages, equals([0]), reason: 'a page nobody asked for is stale, not installed');

        final req = requestsOf(model.update(keyMsg('end'))).first;
        final page = (req.key! as PageKey).page;
        expect(model.isLoading(req.key! as PageKey), isTrue);

        model.update(LoadResult<List<Map<String, Object?>>>(model.id, key: req.key, data: sampleRows(10)));

        expect(model.isLoading(req.key! as PageKey), isFalse);
        expect(model.cachedPages, contains(page));
        expect(model.getRow(page * 10)?['id'], equals('row0'));
      });

      test('update(LoadResult) takes a PageResult, count and end-of-data included', () {
        final model = paginated();
        final req = model.loadFirstPage();

        model.update(
          LoadResult<PageResult<Map<String, Object?>>>(
            model.id,
            key: req.key,
            data: PageResult<Map<String, Object?>>(sampleRows(10), totalCount: 20, hasMore: true),
          ),
        );

        expect(model.cachedPages, equals([0]));
        expect(model.totalCount, equals(20), reason: 'the envelope carried the count');

        // The first frame reports five rows; with the threshold that reaches
        // page 1. The next page says the data stops there, even though it is
        // full.
        expect(pagesAsked(model.viewport(rows: 5, cols: 2)), equals([1]));
        model.update(
          LoadResult<PageResult<Map<String, Object?>>>(
            model.id,
            key: const PageKey(1),
            data: PageResult<Map<String, Object?>>(sampleRows(10), hasMore: false),
          ),
        );
        expect(model.demand(), isNull, reason: 'nothing exists past the last page');
      });

      test('update(LoadResult) records an error, leaving the page retryable', () {
        final model = paginated()
          ..insertRows(sampleRows(10), 0)
          ..viewport(rows: 5, cols: 2);

        final req = requestsOf(model.update(keyMsg('end'))).first;
        final key = req.key! as PageKey;
        final boom = StateError('boom');
        model.update(LoadResult<List<Map<String, Object?>>>(model.id, key: key, error: boom));

        expect(model.isLoading(key), isFalse);
        expect(model.errorFor(key), same(boom));
        expect(model.cachedRowCount, equals(10), reason: 'nothing installed on failure');

        // The page is no longer in flight, so the next demand pass retries it.
        expect(model.demand(), isNotNull);
        expect(model.isLoading(key), isTrue);
        expect(model.errorFor(key), isNull, reason: 'retry clears the error');
      });

      test('update(LoadResult) returns no demand pass after a refusal or a failure', () {
        final model = paginated();
        final req = model.loadFirstPage();

        expect(
          model.update(LoadResult<List<Map<String, Object?>>>.cancelled(req.id, key: req.key)),
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'a standing refusal must never become a request storm',
        );
        model.loadFirstPage();
        expect(
          model.update(LoadResult<List<Map<String, Object?>>>(req.id, key: req.key, error: StateError('boom'))),
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'a failure is retried by the next pass the app runs, not by itself',
        );
      });

      test('update(LoadResult) drops a result for a page that is not loading', () {
        final model = paginated()..insertRows(sampleRows(10), 0);

        // Nothing was requested, so this result is stale.
        model.update(
          LoadResult<List<Map<String, Object?>>>(model.id, key: const PageKey(1), data: sampleRows(10)),
        );

        expect(model.cachedRowCount, equals(10));
        expect(model.isLoading(const PageKey(1)), isFalse);
      });

      test('update(LoadResult) declines a result for another model', () {
        final model = paginated()
          ..insertRows(sampleRows(10), 0)
          ..viewport(rows: 5, cols: 2);
        final key = requestsOf(model.update(keyMsg('end'))).first.key! as PageKey;
        final verdict = model.update(LoadResult<List<Map<String, Object?>>>('other', key: key, data: sampleRows(10)));

        expect(verdict, isA<Declined>(), reason: 'a message addressed elsewhere is not one this table understands');
        expect(model.cachedRowCount, equals(10));
        expect(model.isLoading(key), isTrue, reason: 'slot untouched');
      });

      test('every result addressed to the table is consumed, installed or not', () {
        final model = paginated();
        final req = model.loadFirstPage();

        expect(
          model.update(LoadResult<List<Map<String, Object?>>>(req.id, key: req.key, data: sampleRows(10))),
          isA<Handled>(),
        );
        expect(
          model.update(LoadResult<List<Map<String, Object?>>>(model.id, key: const PageKey(7), data: sampleRows(10))),
          isA<Handled>(),
          reason: "a stale page is dropped, but the message was the table's own",
        );
      });

      test('pages above and below the viewport load at once', () {
        // Rows 10..29 are held; the viewport sits inside them with a missing
        // page on each side, both within reach of the threshold.
        final model = paginated(loadThreshold: 12)
          ..insertRows(sampleRows(10), 1)
          ..insertRows(sampleRows(10), 2)
          ..scrollBy(15);

        expect(
          pagesAsked(model.viewport(rows: 5, cols: 2)),
          equals([0, 3]),
          reason: 'one pass asks for both, as a batch',
        );
        expect(model.isLoading(), isTrue);
        expect(model.isLoadingAbove, isTrue, reason: 'page 0 sits above the viewport');
        expect(model.isLoadingBelow, isTrue, reason: 'page 3 sits below it');
      });

      test('reset clears in-flight load slots', () {
        final model = paginated()
          ..insertRows(sampleRows(10), 0)
          ..viewport(rows: 5, cols: 2)
          ..update(keyMsg('end'));
        expect(model.isLoading(), isTrue);

        model.reset();

        expect(model.isLoading(), isFalse);
        expect(model.cachedRowCount, equals(0));
      });
    });

    // The failures spec 0264 exists to remove, driven through the model with no
    // terminal: hold a navigation key, answer the requests with latency, and
    // require that nothing is left permanently unloadable.
    group('held navigation keys', () {
      const totalRows = 120;
      const size = 10;
      const visible = 5;

      TableViewModel held({int keepPages = 1, int loadThreshold = 3}) => TableViewModel(
        totalCount: totalRows,
        keyField: 'id',
        columns: sampleColumns(),
        pageSize: size,
        keepPages: keepPages,
        loadThreshold: loadThreshold,
        focused: true,
      )..viewport(rows: visible, cols: 3);

      test('bottom, top and back down leaves no permanently blank tail', () {
        final model = held();
        final ferry = _Ferry(model, totalRows, size)..take(model.loadFirstPage());

        // Down to the bottom, up to the top, down again — each burst held long
        // enough that pages land mid-flight, which is when the old edge-following
        // bookkeeping lost the tail for good.
        for (final key in ['pageDown', 'pageUp', 'pageDown']) {
          for (var i = 0; i < 40; i++) {
            ferry.take(model.update(keyMsg(key)));
            if (i.isEven) ferry.deliverOne();
            expectNeverStuck(model, 'after $key step $i');
          }
        }
        ferry.drain();

        expect(model.cursorRow, equals(totalRows - 1), reason: 'the cursor reached the last row');
        expect(model.viewportStatus, SliceStatus.ready);
        expect(ferry.missingVisibleRows(), isEmpty, reason: 'the tail is loadable again, not blank forever');
      });

      test('reversing direction with a page in flight leaves no permanent hole', () {
        final model = held();
        final ferry = _Ferry(model, totalRows, size)..take(model.loadFirstPage());

        // A seeded walk that reverses direction constantly while answers lag —
        // the shape that used to strand a page-sized hole inside the window.
        var seed = 12345;
        int next(int mod) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) % mod;
        for (var step = 0; step < 200; step++) {
          final key = switch (next(4)) {
            0 => 'down',
            1 => 'up',
            2 => 'pageDown',
            _ => 'pageUp',
          };
          ferry.take(model.update(keyMsg(key)));
          // Answer roughly every other request, out of order.
          if (next(2) == 0) ferry.deliverOne();
          expectNeverStuck(model, 'at step $step ($key)');
        }
        ferry.drain();

        expect(model.viewportStatus, SliceStatus.ready);
        expect(ferry.missingVisibleRows(), isEmpty, reason: 'no hole survives a demand pass');
        expect(model.demand(), isNull, reason: 'nothing is left to ask for');
      });

      test('a refused page is asked for again once the app runs demand — and not before', () {
        final model = held();
        _Ferry(model, totalRows, size)
          ..take(model.loadFirstPage())
          ..drain();

        // Walk to the edge of page 1 so it is requested, then refuse it.
        final asked = <int>[];
        for (var i = 0; i < 20 && asked.isEmpty; i++) {
          asked.addAll(pagesAsked(model.update(keyMsg('down'))));
        }
        expect(asked, isNotEmpty);
        final refused = asked.first;
        model.update(LoadResult<List<Map<String, Object?>>>.cancelled(model.id, key: PageKey(refused)));

        expect(model.isLoading(PageKey(refused)), isFalse, reason: 'the slot is idle again');
        expect(model.errorFor(PageKey(refused)), isNull, reason: 'a refusal is not a failure');
        expect(
          model.viewport(rows: visible, cols: 3),
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'an unchanged viewport report runs no pass: a refusal never re-requests on its own',
        );

        // The app's gate lifts and it runs the pass itself: the page is asked for again.
        expect(pagesIn(model.demand()), contains(refused));
      });

      test('a taller terminal demands the revealed pages from its viewport report', () {
        final model = held();
        _Ferry(model, totalRows, size)
          ..take(model.loadFirstPage())
          ..drain();
        expect(model.demand(), isNull, reason: 'the short viewport is fully loaded');

        // The view paints the taller viewport and reports it. Nothing else
        // happens — no key, no pointer.
        final revealed = pagesAsked(model.viewport(rows: 40, cols: 3));

        expect(revealed, isNotEmpty, reason: 'the rows a taller terminal revealed are demanded');
        expect(model.viewportStatus, SliceStatus.filling, reason: 'the report leaves nothing stalled');
        expect(
          model.viewport(rows: 40, cols: 3),
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'the same viewport reported again runs no pass',
        );
      });

      test('the in-flight cap bounds requests, and the rest drain on later passes', () {
        final model = TableViewModel(
          totalCount: totalRows,
          keyField: 'id',
          columns: sampleColumns(),
          pageSize: size,
          loadThreshold: 30,
          maxConcurrentLoads: 1,
          focused: true,
        );
        final ferry = _Ferry(model, totalRows, size);

        // The first frame's report reaches three pages; the cap lets one out.
        expect(
          pagesAsked(model.viewport(rows: visible, cols: 3)),
          hasLength(1),
          reason: 'one at a time, as configured',
        );
        expect(model.demand(), isNull, reason: 'the cap is spent');

        // Answering one frees the slot, and the landing page's update returns
        // the next pass, so the window drains with no input at all.
        final landed = model.update(
          LoadResult<List<Map<String, Object?>>>(model.id, key: const PageKey(0), data: sampleRows(size)),
        );
        expect(pagesAsked(landed), hasLength(1));
        ferry.take(landed);
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

        final model = TableViewModel(
          rows: sampleRows(),
          keyField: 'id',
          columns: columns,
          focused: true,
        )..viewport(rows: 5, cols: 3);

        expect(model.totalColumns, equals(2)); // id and name only
        expect(model.cursorColField, equals('id'));
        model.update(keyMsg('right'));
        expect(model.cursorColField, equals('name')); // Skipped hidden
      });
    });

    group('empty table', () {
      test('handles empty data source', () {
        final model = TableViewModel(
          rows: const <Map<String, Object?>>[],
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
                rows: const <Map<String, Object?>>[],
                keyField: 'id',
                columns: sampleColumns(),
                focused: true,
              )
              ..viewport(rows: 5, cols: 3)
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

/// Requires that [model] is never stuck: rows it is about to paint may be
/// missing only while some fetch is still outstanding, because a fetch landing
/// re-triggers demand and fills them. Missing rows with nothing at all in flight is
/// the permanent failure this whole arc exists to remove.
void expectNeverStuck(TableViewModel model, String when) {
  if (model.viewportStatus != SliceStatus.stalled) return;
  expect(model.isLoading(), isTrue, reason: 'rows missing with nothing in flight, $when');
}

/// Stands in for the app: collects the pages a table asks for and answers them,
/// with the latency of a real fetch — a request lands whenever the test says so,
/// not when it was made.
class _Ferry {
  _Ferry(this.model, this.totalRows, this.pageSize);

  final TableViewModel model;
  final int totalRows;
  final int pageSize;
  final List<int> _outstanding = [];

  /// Records every page a command (or an update's command) asked for.
  void take(Object? source) {
    final cmd = switch (source) {
      Handled(:final cmd) => cmd,
      final Cmd c => c,
      _ => null,
    };
    _outstanding.addAll(pagesIn(cmd));
  }

  /// Answers the oldest outstanding request, if any.
  void deliverOne() {
    if (_outstanding.isEmpty) return;
    final page = _outstanding.removeAt(0);
    final start = page * pageSize;
    final rows = start >= totalRows
        ? const <Map<String, Object?>>[]
        : sampleRows(totalRows).sublist(start, (start + pageSize).clamp(0, totalRows));
    // A page that lands returns the next demand pass; the app fetches it.
    take(model.update(LoadResult<List<Map<String, Object?>>>(model.id, key: PageKey(page), data: rows)));
  }

  /// Answers everything outstanding, then keeps running demand passes until the
  /// model stops asking — what a running app does over the next few frames.
  void drain() {
    for (var round = 0; round < 50; round++) {
      while (_outstanding.isNotEmpty) {
        deliverOne();
      }
      final more = model.demand();
      if (more == null) return;
      take(more);
    }
    fail('the table never stopped asking for pages');
  }

  /// The visible rows whose pages are still missing.
  List<int> missingVisibleRows() => [
    for (var row = model.scrollRow; row < model.scrollRow + model.visibleRows && row < model.rowLimit; row++)
      if (model.getRow(row) == null) row,
  ];
}
