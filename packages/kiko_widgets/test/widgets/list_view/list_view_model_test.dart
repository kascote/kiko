import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

void main() {
  group('ListViewModel', () {
    group('initialization', () {
      test('default state', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c']),
        );
        expect(model.cursor, equals(0));
        expect(model.getChecked(), isEmpty);
        expect(model.focused, isFalse);
        expect(model.dataSource.length, equals(3));
        expect(model.getCursorItem(), equals('a'));
      });

      test('config fields', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a']),
          itemHeight: 2,
          multiSelect: true,
          loadMoreThreshold: 10,
          focused: true,
        );
        expect(model.itemHeight, equals(2));
        expect(model.multiSelect, isTrue);
        expect(model.loadMoreThreshold, equals(10));
        expect(model.focused, isTrue);
      });

      test('custom itemKey', () {
        final model =
            ListViewModel<Map<String, dynamic>, String>(
                dataSource: ListDataSource.fromList([
                  {'id': 'a', 'name': 'Alice'},
                  {'id': 'b', 'name': 'Bob'},
                ]),
                itemKey: (item) => item['id'] as String,
                multiSelect: true,
                focused: true,
              )
              ..setVisibleCount(10)
              // Select first item
              ..update(keyMsg('space'));

        expect(model.getChecked(), equals({'a'}));
      });
    });

    group('cursor movement', () {
      late ListViewModel<String, String> model;

      setUp(() {
        model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b', 'c', 'd', 'e']),
          focused: true,
        )..setVisibleCount(3);
      });

      test('down moves cursor', () {
        model.update(keyMsg('down'));
        expect(model.cursor, equals(1));
        expect(model.getCursorItem(), equals('b'));
      });

      test('j moves cursor down (vim)', () {
        model.update(keyMsg('j'));
        expect(model.cursor, equals(1));
      });

      test('up moves cursor', () {
        model
          ..update(keyMsg('down'))
          ..update(keyMsg('up'));
        expect(model.cursor, equals(0));
      });

      test('k moves cursor up (vim)', () {
        model
          ..update(keyMsg('j'))
          ..update(keyMsg('k'));
        expect(model.cursor, equals(0));
      });

      test('up at first item stays at 0', () {
        model.update(keyMsg('up'));
        expect(model.cursor, equals(0));
      });

      test('down at last item stays at end', () {
        for (var i = 0; i < 10; i++) {
          model.update(keyMsg('down'));
        }
        expect(model.cursor, equals(4));
      });

      test('home moves to first', () {
        model
          ..update(keyMsg('down'))
          ..update(keyMsg('down'))
          ..update(keyMsg('home'));
        expect(model.cursor, equals(0));
      });

      test('end moves to last', () {
        model.update(keyMsg('end'));
        expect(model.cursor, equals(4));
      });

      test('G moves to last (vim)', () {
        model.update(keyMsg('G'));
        expect(model.cursor, equals(4));
      });

      test('pageDown moves by visible count', () {
        model.update(keyMsg('pageDown'));
        expect(model.cursor, equals(3));
      });

      test('pageUp moves by visible count', () {
        model
          ..update(keyMsg('end'))
          ..update(keyMsg('pageUp'));
        expect(model.cursor, equals(1));
      });
    });

    group('scroll offset', () {
      late ListViewModel<String, String> model;

      setUp(() {
        model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(
            List.generate(20, (i) => 'item$i'),
          ),
          focused: true,
        )..setVisibleCount(5);
      });

      test('scrollOffset adjusts when cursor moves below visible', () {
        for (var i = 0; i < 6; i++) {
          model.update(keyMsg('down'));
        }
        expect(model.cursor, equals(6));
        expect(model.scrollOffset, equals(2));
      });

      test('scrollOffset adjusts when cursor moves above visible', () {
        // Move down then up
        for (var i = 0; i < 10; i++) {
          model.update(keyMsg('down'));
        }
        for (var i = 0; i < 8; i++) {
          model.update(keyMsg('up'));
        }
        expect(model.cursor, equals(2));
        expect(model.scrollOffset, equals(2));
      });

      test('scrollState returns correct values', () {
        final state = model.getScrollState();
        expect(state.visible, equals(5));
        expect(state.total, equals(20));
        expect(state.offset, equals(0));
      });
    });

    group('selection', () {
      group('single select disabled by default', () {
        test('space does nothing without multiSelect', () {
          final model = ListViewModel<String, String>(
            dataSource: ListDataSource.fromList(['a', 'b', 'c']),
            focused: true,
          )..update(keyMsg('space'));
          expect(model.getChecked(), isEmpty);
        });
      });

      group('multi-select', () {
        late ListViewModel<String, String> model;

        setUp(() {
          model = ListViewModel<String, String>(
            dataSource: ListDataSource.fromList(['a', 'b', 'c', 'd', 'e']),
            multiSelect: true,
            focused: true,
          )..setVisibleCount(5);
        });

        test('space toggles check', () {
          model.update(keyMsg('space'));
          expect(model.getChecked(), equals({'a'}));
          expect(model.isChecked(0), isTrue);
          expect(model.isChecked(1), isFalse);
        });

        test('space toggles off', () {
          model
            ..update(keyMsg('space'))
            ..update(keyMsg('space'));
          expect(model.getChecked(), isEmpty);
        });

        test('multiple items can be checked', () {
          model
            ..update(keyMsg('space'))
            ..update(keyMsg('down'))
            ..update(keyMsg('space'))
            ..update(keyMsg('down'))
            ..update(keyMsg('space'));
          expect(model.getChecked(), equals({'a', 'b', 'c'}));
          expect(model.getCheckedItems(), equals(['a', 'b', 'c']));
        });
      });

      group('range select', () {
        late ListViewModel<String, String> model;

        setUp(() {
          model = ListViewModel<String, String>(
            dataSource: ListDataSource.fromList(['a', 'b', 'c', 'd', 'e']),
            multiSelect: true,
            focused: true,
          )..setVisibleCount(5);
        });

        test('shift+down extends check range', () {
          model.update(keyMsg('shift+down'));
          expect(model.cursor, equals(1));
          expect(model.getChecked(), equals({'a', 'b'}));
        });

        test('shift+j extends check range (vim)', () {
          model.update(keyMsg('shift+j'));
          expect(model.cursor, equals(1));
          expect(model.getChecked(), equals({'a', 'b'}));
        });

        test('shift+up extends check range upward', () {
          model
            ..update(keyMsg('down'))
            ..update(keyMsg('down'))
            ..update(keyMsg('shift+up'));
          expect(model.cursor, equals(1));
          expect(model.getChecked(), equals({'b', 'c'}));
        });

        test('shift+k extends check range upward (vim)', () {
          model
            ..update(keyMsg('down'))
            ..update(keyMsg('down'))
            ..update(keyMsg('shift+k'));
          expect(model.cursor, equals(1));
          expect(model.getChecked(), equals({'b', 'c'}));
        });

        test('continued range select expands checked', () {
          model
            ..update(keyMsg('shift+down'))
            ..update(keyMsg('shift+down'))
            ..update(keyMsg('shift+down'));
          expect(model.cursor, equals(3));
          expect(model.getChecked(), equals({'a', 'b', 'c', 'd'}));
        });

        test('normal nav clears anchor', () {
          model
            ..update(keyMsg('shift+down'))
            ..update(keyMsg('down')) // clears anchor
            ..update(keyMsg('shift+down'));
          // New anchor at cursor 2
          expect(model.cursor, equals(3));
          expect(model.getChecked(), equals({'a', 'b', 'c', 'd'}));
        });

        test('safe when data source shrinks after anchor set', () {
          // Start range select at index 3
          model
            ..update(keyMsg('end')) // cursor at 4
            ..update(keyMsg('shift+up')); // anchor at 4, cursor at 3
          expect(model.getChecked(), equals({'d', 'e'}));

          // Shrink data source - anchor (4) now stale
          model
            ..dataSource = ListDataSource.fromList(['a', 'b'])
            // Range select should not crash with stale anchor
            // Loop iterates anchor..cursor but _safeItemAt returns null for invalid
            ..update(keyMsg('shift+up'));
          // Old keys remain, only valid index 1 ('b') added
          expect(model.getChecked(), equals({'d', 'e', 'b'}));
        });
      });

      group('disabled items', () {
        test('disabled items cannot be checked', () {
          final model =
              ListViewModel<String, String>(
                  dataSource: ListDataSource.fromList(['a', 'b', 'c']),
                  multiSelect: true,
                  isDisabled: (i) => i == 1,
                  focused: true,
                )
                ..setVisibleCount(5)
                ..update(keyMsg('down')) // cursor at b (disabled)
                ..update(keyMsg('space')); // should not check
          expect(model.getChecked(), isEmpty);
        });

        test('range select skips disabled', () {
          final model =
              ListViewModel<String, String>(
                  dataSource: ListDataSource.fromList(['a', 'b', 'c', 'd']),
                  multiSelect: true,
                  isDisabled: (i) => i == 1,
                  focused: true,
                )
                ..setVisibleCount(5)
                ..update(keyMsg('shift+down'))
                ..update(keyMsg('shift+down'))
                ..update(keyMsg('shift+down'));
          expect(model.getChecked(), equals({'a', 'c', 'd'})); // b skipped
        });
      });
    });

    group('commands', () {
      test('enter returns ListConfirmCmd', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a', 'b']),
          focused: true,
        );
        final cmd = model.update(keyMsg('enter'));
        expect(cmd, isA<ListConfirmCmd<String, String>>());
        expect((cmd! as ListConfirmCmd).source, same(model));
      });

      test('unhandled key returns Unhandled', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a']),
          focused: true,
        );
        final cmd = model.update(keyMsg('tab'));
        expect(cmd, isA<Unhandled>());
      });

      test('unfocused returns Unhandled', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a']),
        );
        final cmd = model.update(keyMsg('down'));
        expect(cmd, isA<Unhandled>());
      });

      test('non-key message returns null', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList(['a']),
          focused: true,
        );
        final cmd = model.update(const NoneMsg());
        expect(cmd, isNull);
      });
    });

    group('LoadMoreCmd', () {
      test('emitted when near end with hasMore', () {
        final source = _PaginatedSource(['a', 'b', 'c', 'd', 'e']);
        final model =
            ListViewModel<String, String>(
                dataSource: source,
                loadMoreThreshold: 2,
                focused: true,
              )
              ..setVisibleCount(5)
              // Move to index 3 (2 from end)
              ..update(keyMsg('down'))
              ..update(keyMsg('down'))
              ..update(keyMsg('down'));

        final cmd = model.update(keyMsg('down'));
        expect(cmd, isA<LoadMoreCmd<String, String>>());
      });

      test('not emitted when hasMore is false', () {
        final model =
            ListViewModel<String, String>(
                dataSource: ListDataSource.fromList(['a', 'b', 'c']),
                loadMoreThreshold: 2,
                focused: true,
              )
              ..setVisibleCount(5)
              ..update(keyMsg('down'))
              ..update(keyMsg('down'));

        final cmd = model.update(keyMsg('down'));
        // fromList has hasMore = false, so no LoadMoreCmd
        expect(cmd, isNull);
      });
    });

    group('empty list', () {
      test('handles empty data source', () {
        final model = ListViewModel<String, String>(
          dataSource: ListDataSource.fromList([]),
          focused: true,
        );
        expect(model.cursor, equals(0));
        expect(model.getCursorItem(), isNull);
        expect(model.dataSource.length, equals(0));
      });

      test('navigation on empty list is safe', () {
        final model =
            ListViewModel<String, String>(
                dataSource: ListDataSource.fromList([]),
                focused: true,
              )
              ..setVisibleCount(5)
              // Should not throw
              ..update(keyMsg('down'))
              ..update(keyMsg('up'))
              ..update(keyMsg('home'))
              ..update(keyMsg('end'));

        expect(model.cursor, equals(0));
      });
    });
  });

  group('ListDataSource', () {
    test('fromList creates adapter', () {
      final source = ListDataSource.fromList(['a', 'b', 'c']);
      expect(source.length, equals(3));
      expect(source.itemAt(0), equals('a'));
      expect(source.itemAt(2), equals('c'));
      expect(source.hasMore, isFalse);
    });
  });

  group('ScrollState', () {
    test('progress calculation', () {
      const state = ScrollState(offset: 5, visible: 10, total: 20);
      expect(state.progress, equals(0.5));
    });

    test('progress null when total unknown', () {
      const state = ScrollState(offset: 0, visible: 10, total: null);
      expect(state.progress, isNull);
    });

    test('progress null when all visible', () {
      const state = ScrollState(offset: 0, visible: 10, total: 5);
      expect(state.progress, isNull);
    });

    test('thumbSize calculation', () {
      const state = ScrollState(offset: 0, visible: 10, total: 100);
      expect(state.thumbSize, equals(0.1));
    });

    test('thumbSize minimum 0.1', () {
      const state = ScrollState(offset: 0, visible: 1, total: 1000);
      expect(state.thumbSize, equals(0.1));
    });
  });
}

/// Test data source with hasMore = true.
class _PaginatedSource implements ListDataSource<String> {
  final List<String> _items;
  _PaginatedSource(this._items);

  @override
  int get length => _items.length;

  @override
  String itemAt(int index) => _items[index];

  @override
  bool get hasMore => true;
}
