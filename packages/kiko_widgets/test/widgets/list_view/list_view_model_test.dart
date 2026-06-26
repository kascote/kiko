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
          dataView: DataView.fromList(['a', 'b', 'c']),
        );
        expect(model.cursor, equals(0));
        expect(model.getSelectedKeys(), isEmpty);
        expect(model.focused, isFalse);
        expect(model.dataView.length, equals(3));
        expect(model.cursorItem, equals('a'));
      });

      test('config fields', () {
        final model = ListViewModel<String, String>(
          dataView: DataView.fromList(['a']),
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
                dataView: DataView.fromList([
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

        expect(model.getSelectedKeys(), equals({'a'}));
      });
    });

    group('cursor movement', () {
      late ListViewModel<String, String> model;

      setUp(() {
        model = ListViewModel<String, String>(
          dataView: DataView.fromList(['a', 'b', 'c', 'd', 'e']),
          focused: true,
        )..setVisibleCount(3);
      });

      test('down moves cursor', () {
        model.update(keyMsg('down'));
        expect(model.cursor, equals(1));
        expect(model.cursorItem, equals('b'));
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
          dataView: DataView.fromList(
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
            dataView: DataView.fromList(['a', 'b', 'c']),
            focused: true,
          )..update(keyMsg('space'));
          expect(model.getSelectedKeys(), isEmpty);
        });
      });

      group('multi-select', () {
        late ListViewModel<String, String> model;

        setUp(() {
          model = ListViewModel<String, String>(
            dataView: DataView.fromList(['a', 'b', 'c', 'd', 'e']),
            multiSelect: true,
            focused: true,
          )..setVisibleCount(5);
        });

        test('space toggles check', () {
          model.update(keyMsg('space'));
          expect(model.getSelectedKeys(), equals({'a'}));
          expect(model.isSelected(0), isTrue);
          expect(model.isSelected(1), isFalse);
        });

        test('space toggles off', () {
          model
            ..update(keyMsg('space'))
            ..update(keyMsg('space'));
          expect(model.getSelectedKeys(), isEmpty);
        });

        test('multiple items can be checked', () {
          model
            ..update(keyMsg('space'))
            ..update(keyMsg('down'))
            ..update(keyMsg('space'))
            ..update(keyMsg('down'))
            ..update(keyMsg('space'));
          expect(model.getSelectedKeys(), equals({'a', 'b', 'c'}));
        });
      });

      group('range select', () {
        late ListViewModel<String, String> model;

        setUp(() {
          model = ListViewModel<String, String>(
            dataView: DataView.fromList(['a', 'b', 'c', 'd', 'e']),
            multiSelect: true,
            focused: true,
          )..setVisibleCount(5);
        });

        test('shift+down extends check range', () {
          model.update(keyMsg('shift+down'));
          expect(model.cursor, equals(1));
          expect(model.getSelectedKeys(), equals({'a', 'b'}));
        });

        test('shift+j extends check range (vim)', () {
          model.update(keyMsg('shift+j'));
          expect(model.cursor, equals(1));
          expect(model.getSelectedKeys(), equals({'a', 'b'}));
        });

        test('shift+up extends check range upward', () {
          model
            ..update(keyMsg('down'))
            ..update(keyMsg('down'))
            ..update(keyMsg('shift+up'));
          expect(model.cursor, equals(1));
          expect(model.getSelectedKeys(), equals({'b', 'c'}));
        });

        test('shift+k extends check range upward (vim)', () {
          model
            ..update(keyMsg('down'))
            ..update(keyMsg('down'))
            ..update(keyMsg('shift+k'));
          expect(model.cursor, equals(1));
          expect(model.getSelectedKeys(), equals({'b', 'c'}));
        });

        test('continued range select expands checked', () {
          model
            ..update(keyMsg('shift+down'))
            ..update(keyMsg('shift+down'))
            ..update(keyMsg('shift+down'));
          expect(model.cursor, equals(3));
          expect(model.getSelectedKeys(), equals({'a', 'b', 'c', 'd'}));
        });

        test('normal nav clears anchor', () {
          model
            ..update(keyMsg('shift+down'))
            ..update(keyMsg('down')) // clears anchor
            ..update(keyMsg('shift+down'));
          // New anchor at cursor 2
          expect(model.cursor, equals(3));
          expect(model.getSelectedKeys(), equals({'a', 'b', 'c', 'd'}));
        });

        test('safe when data source shrinks after anchor set', () {
          // Start range select at index 3
          model
            ..update(keyMsg('end')) // cursor at 4
            ..update(keyMsg('shift+up')); // anchor at 4, cursor at 3
          expect(model.getSelectedKeys(), equals({'d', 'e'}));

          // Shrink data source - anchor (4) now stale
          model
            ..dataView = DataView.fromList(['a', 'b'])
            // Range select should not crash with stale anchor
            // Loop iterates anchor..cursor but _safeItemAt returns null for invalid
            ..update(keyMsg('shift+up'));
          // Old keys remain, only valid index 1 ('b') added
          expect(model.getSelectedKeys(), equals({'d', 'e', 'b'}));
        });
      });

      group('disabled items', () {
        test('disabled items cannot be checked', () {
          final model =
              ListViewModel<String, String>(
                  dataView: DataView.fromList(['a', 'b', 'c']),
                  multiSelect: true,
                  isDisabled: (i) => i == 1,
                  focused: true,
                )
                ..setVisibleCount(5)
                ..update(keyMsg('down')) // cursor at b (disabled)
                ..update(keyMsg('space')); // should not check
          expect(model.getSelectedKeys(), isEmpty);
        });

        test('range select skips disabled', () {
          final model =
              ListViewModel<String, String>(
                  dataView: DataView.fromList(['a', 'b', 'c', 'd']),
                  multiSelect: true,
                  isDisabled: (i) => i == 1,
                  focused: true,
                )
                ..setVisibleCount(5)
                ..update(keyMsg('shift+down'))
                ..update(keyMsg('shift+down'))
                ..update(keyMsg('shift+down'));
          expect(model.getSelectedKeys(), equals({'a', 'c', 'd'})); // b skipped
        });
      });
    });

    group('commands', () {
      test('enter returns ListConfirmCmd', () {
        final model = ListViewModel<String, String>(
          dataView: DataView.fromList(['a', 'b']),
          focused: true,
        );
        final cmd = model.update(keyMsg('enter'));
        expect(cmd, isA<ListActionCmd>());
        expect((cmd! as ListActionCmd).id, equals(model.id));
      });

      test('unhandled key returns Unhandled', () {
        final model = ListViewModel<String, String>(
          dataView: DataView.fromList(['a']),
          focused: true,
        );
        final cmd = model.update(keyMsg('tab'));
        expect(cmd, isA<Unhandled>());
      });

      test('unfocused returns Unhandled', () {
        final model = ListViewModel<String, String>(
          dataView: DataView.fromList(['a']),
        );
        final cmd = model.update(keyMsg('down'));
        expect(cmd, isA<Unhandled>());
      });

      test('non-key message returns null', () {
        final model = ListViewModel<String, String>(
          dataView: DataView.fromList(['a']),
          focused: true,
        );
        final cmd = model.update(const NoneMsg());
        expect(cmd, isNull);
      });
    });

    group('load requests', () {
      ListViewModel<String, String> paginated() => ListViewModel<String, String>(
        dataView: DataBuffer<String>(['a', 'b', 'c', 'd', 'e'])..hasMore = true,
        loadMoreThreshold: 2,
        focused: true,
      )..setVisibleCount(5);

      test('returns a LoadRequest when the cursor nears the end', () {
        final model = paginated()
          ..update(keyMsg('down')) // cursor 1
          ..update(keyMsg('down')); // cursor 2

        final cmd = model.update(keyMsg('down')); // cursor 3 — within threshold
        expect(cmd, isA<LoadRequest>());
        expect((cmd! as LoadRequest).id, equals(model.id));
        expect((cmd as LoadRequest).key, equals(ListLoadKey.self));
        expect(model.isLoading(), isTrue, reason: 'the widget self-marks loading on emit');
      });

      test('does not re-request while a load is already in flight (self-dedup)', () {
        final model = paginated()
          ..update(keyMsg('down'))
          ..update(keyMsg('down'))
          ..update(keyMsg('down')); // first request emitted, slot now loading
        expect(model.isLoading(), isTrue);

        final cmd = model.update(keyMsg('down'));
        expect(cmd, isNull, reason: 'the slot is already loading');
      });

      test('not emitted when hasMore is false', () {
        final model =
            ListViewModel<String, String>(
                dataView: DataView.fromList(['a', 'b', 'c']),
                loadMoreThreshold: 2,
                focused: true,
              )
              ..setVisibleCount(5)
              ..update(keyMsg('down'))
              ..update(keyMsg('down'));

        final cmd = model.update(keyMsg('down'));
        // A static fromList view has hasMore = false, so no request.
        expect(cmd, isNull);
      });
    });

    group('load lifecycle', () {
      ListViewModel<String, String> paginated() => ListViewModel<String, String>(
        dataView: DataBuffer<String>(['a', 'b']),
        pageSize: 2,
        focused: true,
      )..setVisibleCount(5);

      test('loadFirstPage marks the slot loading and returns a request', () {
        final model = ListViewModel<String, String>(
          dataView: DataBuffer<String>(),
          pageSize: 2,
          focused: true,
        );
        final req = model.loadFirstPage();
        expect(req.id, equals(model.id));
        expect(req.key, equals(ListLoadKey.self));
        expect(model.isLoading(), isTrue);
      });

      test('applyLoad appends the page and clears the slot', () {
        final model = paginated();
        final req = model.loadFirstPage();
        model.applyLoad(LoadResult<List<String>>(req.id, key: req.key, data: const ['c', 'd']));

        expect(model.dataView.length, equals(4));
        expect(model.cursorItem, equals('a'));
        expect(model.isLoading(), isFalse);
        expect(model.dataView.hasMore, isTrue, reason: 'a full page means more may remain');
      });

      test('a short page ends pagination', () {
        final model = paginated();
        final req = model.loadFirstPage();
        model.applyLoad(LoadResult<List<String>>(req.id, key: req.key, data: const ['c']));

        expect(model.dataView.length, equals(3));
        expect(model.dataView.hasMore, isFalse);
      });

      test('a failed load records the error and is retryable', () {
        final model = paginated();
        final req = model.loadFirstPage();
        model.applyLoad(LoadResult<List<String>>(req.id, key: req.key, error: 'boom'));

        expect(model.isLoading(), isFalse);
        expect(model.errorFor(ListLoadKey.self), equals('boom'));
      });

      test('a result for an idle slot is dropped (staleness guard)', () {
        final model = paginated();
        // No loadFirstPage — the slot is idle, so this is a stale arrival.
        model.applyLoad(LoadResult<List<String>>(model.id, key: ListLoadKey.self, data: const ['x']));
        expect(model.dataView.length, equals(2), reason: 'a stale result must not append');
      });

      test('a result for another id is ignored', () {
        final model = paginated()
          ..loadFirstPage()
          ..applyLoad(const LoadResult<List<String>>('other', key: ListLoadKey.self, data: ['x']));

        expect(model.dataView.length, equals(2));
        expect(model.isLoading(), isTrue, reason: 'still waiting for its own result');
      });
    });

    group('empty list', () {
      test('handles empty data source', () {
        final model = ListViewModel<String, String>(
          dataView: DataView.fromList([]),
          focused: true,
        );
        expect(model.cursor, equals(0));
        expect(model.cursorItem, isNull);
        expect(model.dataView.length, equals(0));
      });

      test('navigation on empty list is safe', () {
        final model =
            ListViewModel<String, String>(
                dataView: DataView.fromList([]),
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
