import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to get cell symbol at position.
String cellAt(Buffer buf, int x, int y) => buf.cellAtPos(Position(x, y))!.symbol;

void main() {
  group('ListView', () {
    group('basic rendering', () {
      test('renders items', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['Apple', 'Banana', 'Cherry']),
          focused: true,
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 5));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        expect(cellAt(buf, 0, 0), 'A');
        expect(cellAt(buf, 0, 1), 'B');
        expect(cellAt(buf, 0, 2), 'C');
      });

      test('updates visibleCount on model', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c', 'd', 'e']),
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        expect(model.getScrollState().visible, equals(3));
      });

      test('respects itemHeight', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c']),
          itemHeight: 2,
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 6));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        // With itemHeight=2, visible count should be 3 (6/2)
        expect(model.getScrollState().visible, equals(3));
        // Items at y=0, y=2, y=4
        expect(cellAt(buf, 0, 0), 'a');
        expect(cellAt(buf, 0, 2), 'b');
        expect(cellAt(buf, 0, 4), 'c');
      });
    });

    group('empty state', () {
      test('renders nothing when empty and no placeholder', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList([]),
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        // Buffer should be empty (spaces)
        expect(cellAt(buf, 0, 0), ' ');
      });

      test('renders placeholder when empty', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList([]),
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
          emptyPlaceholder: Line('No items'),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        expect(cellAt(buf, 0, 0), 'N');
        expect(cellAt(buf, 1, 0), 'o');
      });
    });

    group('separator', () {
      test('renders separators between items', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c']),
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
          separatorBuilder: () => Line('-'),
        );

        // Height 4: fits 2 items (effectiveRowHeight=2)
        // Layout: a (y=0), - (y=1), b (y=2), no trailing separator
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 4));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        expect(cellAt(buf, 0, 0), 'a');
        expect(cellAt(buf, 0, 1), '-');
        expect(cellAt(buf, 0, 2), 'b');
        // y=3 is empty (no separator after last visible)
        expect(cellAt(buf, 0, 3), ' ');
      });

      test('calculates visibleCount with separator', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c', 'd', 'e']),
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
          separatorBuilder: () => Line('-'),
        );

        // Height 5: fits 3 items (3*1) + 2 separators = 5 lines
        // Last item doesn't need separator, so (5+1)~/2 = 3
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 5));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        expect(model.getScrollState().visible, equals(3));
      });
    });

    group('itemBuilder parameters', () {
      test('passes correct focused state', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c']),
          focused: true,
        );

        final focusedItems = <int>[];
        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, index, state) {
            if (state.focused) focusedItems.add(index);
            return Line(item);
          },
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        // Cursor at index 0
        expect(focusedItems, equals([0]));
      });

      test('passes correct checked state', () {
        final model =
            ListViewModel<String, String>(
                dataSource: ListDataSource.fromList(['a', 'b', 'c']),
                multiSelect: true,
                focused: true,
              )
              ..setVisibleCount(3)
              ..update(const KeyMsg('space'));

        final checkedItems = <int>[];
        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, index, state) {
            if (state.checked) checkedItems.add(index);
            return Line(item);
          },
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        expect(checkedItems, equals([0]));
      });

      test('passes correct disabled state', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c']),
          isDisabled: (i) => i == 1,
        );

        final disabledItems = <int>[];
        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, index, state) {
            if (state.disabled) disabledItems.add(index);
            return Line(item);
          },
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        expect(disabledItems, equals([1]));
      });
    });

    group('scrolling', () {
      test('renders from scrollOffset', () {
        final model =
            ListViewModel<String, String>(
                dataSource: ListDataSource.fromList(['a', 'b', 'c', 'd', 'e']),
                focused: true,
              )
              ..setVisibleCount(2)
              ..update(const KeyMsg('down'))
              ..update(const KeyMsg('down'))
              ..update(const KeyMsg('down'));

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 2));
        listView.render(buf.area, Frame(buf.area, buf, 0));

        // Cursor at index 3, scroll should show 'c' and 'd' (offset 2)
        expect(cellAt(buf, 0, 0), 'c');
        expect(cellAt(buf, 0, 1), 'd');
      });
    });

    group('edge cases', () {
      test('handles empty area', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a']),
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 0, height: 0));
        // Should not throw
        listView.render(buf.area, Frame(buf.area, buf, 0));
      });

      test('handles height less than itemHeight', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a']),
          itemHeight: 3,
        );

        final listView = ListView<String, String>(
          model: model,
          itemBuilder: (item, _, _) => Line(item),
        );

        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 2));
        // Should not throw, visibleCount = 0
        listView.render(buf.area, Frame(buf.area, buf, 0));
      });
    });
  });
}
