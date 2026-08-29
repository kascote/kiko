import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';
import '../../support/viewport.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// A routed wheel/button message over the widget, at local (0, 0), on no marked
/// part — the shape of a pointer over a separator or the blank tail.
PointerMsg pointer(PointerAction action) => PointerMsg(global: Position.origin, action: action, local: Position.origin);

/// A routed button/move message at a given local cell, on no marked part.
PointerMsg pointerAt(PointerAction action, {int x = 0, int y = 0}) =>
    PointerMsg(global: Position(x, y), action: action, local: Position(x, y));

/// A routed button/move message over row [row], the way the framework delivers
/// it once the view has marked the row and the router has resolved it.
PointerMsg pointerOnRow(PointerAction action, int row) =>
    PointerMsg(global: Position.origin, action: action, local: Position.origin, region: RowRegion(row));

/// A message no model understands: the probe for the decline path.
class _UnknownMsg extends Msg {
  const _UnknownMsg();
}

void main() {
  group('mouse wheel + scroll', () {
    test('a wheel notch scrolls an unfocused list without moving the cursor', () {
      final model = ListViewModel<String, String>(
        items: List.generate(20, (i) => 'item$i'),
      )..viewport(rows: 5);

      final result = model.update(pointer(PointerAction.wheelDown));

      expect(result, isA<Handled>());
      expect(model.scrollOffset, equals(3), reason: 'one notch is three rows');
      expect(model.cursor, equals(0), reason: 'the wheel never touches the keyboard cursor');
    });

    test('scrollBy clamps at both ends', () {
      final model = ListViewModel<String, String>(
        items: List.generate(10, (i) => 'item$i'),
      )..viewport(rows: 4);

      expect((model..scrollBy(-5)).scrollOffset, equals(0), reason: 'cannot scroll above the first row');
      expect((model..scrollBy(100)).scrollOffset, equals(6), reason: 'stops at length - visibleCount (10 - 4)');
      expect((model..scrollBy(50)).scrollOffset, equals(6), reason: 'already at the bottom edge');
    });

    test('a horizontal wheel and a click past the last item are declined', () {
      final model = ListViewModel<String, String>(
        items: const ['a', 'b', 'c'],
        focused: true,
      )..viewport(rows: 2);

      expect(model.update(pointer(PointerAction.wheelLeft)), isA<Declined>());
      expect(model.update(pointerAt(PointerAction.down, y: 9)), isA<Declined>(), reason: 'no item under the click');
      expect(model.scrollOffset, equals(0), reason: 'neither moved the viewport');
    });

    test('a wheel toward a missing page returns a LoadRequest (unfocused)', () {
      // No threshold: the reported viewport covers page 0 exactly, so only the
      // wheel notch carries the viewport into page 1.
      final model = ListViewModel<String, String>(
        items: List.generate(5, (i) => 'item$i'),
        totalCount: 15,
        pageSize: 5,
        loadThreshold: 0,
      )..viewport(rows: 5);

      final result = model.update(pointer(PointerAction.wheelDown));

      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<LoadRequest>()));
      expect(model.isLoading(), isTrue, reason: 'wheel alone brought a missing page into demand');
    });

    group('wheel decline at the scroll limit (mikos 0175 / G2)', () {
      ListViewModel<String, String> scrollable({int items = 10, int visible = 5}) => ListViewModel<String, String>(
        items: List.generate(items, (i) => 'item$i'),
      )..viewport(rows: visible);

      test('at the top, wheel-up declines while wheel-down handles', () {
        final model = scrollable();
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Declined>());
        expect(model.scrollOffset, equals(0), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Handled>());
      });

      test('at the bottom, wheel-down declines while wheel-up handles', () {
        final model = scrollable()..scrollBy(100); // pin to the bottom edge
        final atBottom = model.scrollOffset;
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Declined>());
        expect(model.scrollOffset, equals(atBottom), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Handled>());
      });

      test('content that fits entirely declines both directions', () {
        final model = scrollable(items: 3);
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Declined>());
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Declined>());
      });

      test('a partial scroll still consumes, even though it moves fewer rows than a full notch', () {
        // scrollOffset 4, max 5 (10 items - 5 visible): a 3-row notch down can
        // only move 1 row, but 1 row is not a no-op, so it must still handle.
        final model = scrollable()..scrollBy(4);
        expect(model.scrollOffset, equals(4));

        final result = model.update(pointer(PointerAction.wheelDown));
        expect(result, isA<Handled>());
        expect(model.scrollOffset, equals(5), reason: 'moved the 1 remaining row');
      });

      test('mid-content, both directions handle', () {
        final model = scrollable()..scrollBy(2);
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Handled>());
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Handled>());
      });
    });
  });

  group('mouse click + hover', () {
    ListViewModel<String, String> menu({bool focused = true}) => ListViewModel<String, String>(
      id: 'menu',
      items: List.generate(6, (i) => 'item$i'),
      focused: focused,
    )..viewport(rows: 6);

    test('a click on row N moves the cursor there and emits ListActionCmd', () {
      final model = menu();

      final down = model.update(pointerOnRow(PointerAction.down, 3));

      expect(down, isA<Handled>().having((h) => h.cmd, 'cmd', const ListActionCmd('menu')));
      expect(model.cursor, equals(3));

      // The release half only refreshes hover — it does not fire a second time.
      final up = model.update(pointerOnRow(PointerAction.up, 3));
      expect(up, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a click on an item the window does not hold moves the cursor but emits nothing', () {
      final model = ListViewModel<String, String>(
        id: 'menu',
        totalCount: 6,
        focused: true,
      )..viewport(rows: 6);

      final down = model.update(pointerOnRow(PointerAction.down, 3));

      expect(down, isA<Handled>().having((h) => h.cmd, 'cmd', isNull), reason: 'nothing to activate, press consumed');
      expect(model.cursor, equals(3), reason: 'the cursor still moves where the user pointed');
    });

    test('a press on no marked part (a separator or the tail) is declined', () {
      expect(menu().update(pointerAt(PointerAction.down, y: 20)), isA<Declined>());
    });

    test('a click selects on an unfocused list', () {
      final model = menu(focused: false)..update(pointerOnRow(PointerAction.down, 2));

      expect(model.cursor, equals(2), reason: 'selection changes without a prior focus');
    });

    test('a pointer sets the hover row; a leave clears it', () {
      final model = menu()..update(pointerOnRow(PointerAction.move, 4));
      expect(model.hoverRow, equals(4));

      model.update(pointer(PointerAction.move));
      expect(model.hoverRow, isNull, reason: 'a move over no marked part clears the hover');

      model.update(pointerOnRow(PointerAction.move, 1));
      expect(model.hoverRow, equals(1));

      model.update(const PointerLeaveMsg('menu'));
      expect(model.hoverRow, isNull, reason: 'a leave clears the hover');
    });
  });

  group('ListViewModel', () {
    group('initialization', () {
      test('default state', () {
        final model = ListViewModel<String, String>(
          items: const ['a', 'b', 'c'],
        );
        expect(model.cursor, equals(0));
        expect(model.getSelectedKeys(), isEmpty);
        expect(model.focused, isFalse);
        expect(model.knownItemCount, equals(3), reason: 'items are taken to be all the data');
        expect(model.cursorItem, equals('a'));
      });

      test('config fields', () {
        final model = ListViewModel<String, String>(
          items: const ['a'],
          itemHeight: 2,
          multiSelect: true,
          loadThreshold: 10,
          focused: true,
        );
        expect(model.itemHeight, equals(2));
        expect(model.multiSelect, isTrue);
        expect(model.loadThreshold, equals(10));
        expect(model.focused, isTrue);
      });

      test('totalCount alongside items seeds a first page of something larger', () {
        final model = ListViewModel<String, String>(
          items: const ['a', 'b'],
          totalCount: 10,
          pageSize: 2,
        );
        expect(model.knownItemCount, equals(10));
        expect(model.itemLimit, equals(10), reason: 'navigation can reach the end before it is loaded');
        expect(model.getItem(0), equals('a'));
        expect(model.getItem(2), isNull, reason: 'a page that has not arrived reads as absent');
      });

      test('custom itemKey', () {
        final model =
            ListViewModel<Map<String, dynamic>, String>(
                items: [
                  {'id': 'a', 'name': 'Alice'},
                  {'id': 'b', 'name': 'Bob'},
                ],
                itemKey: (item) => item['id'] as String,
                multiSelect: true,
                focused: true,
              )
              ..viewport(rows: 10)
              // Select first item
              ..update(keyMsg('space'));

        expect(model.getSelectedKeys(), equals({'a'}));
      });
    });

    group('cursor movement', () {
      late ListViewModel<String, String> model;

      setUp(() {
        model = ListViewModel<String, String>(
          items: const ['a', 'b', 'c', 'd', 'e'],
          focused: true,
        )..viewport(rows: 3);
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

      test('end jumps to the addressable limit and demands the destination page', () {
        final paged = ListViewModel<String, String>(
          items: const ['a', 'b', 'c', 'd', 'e'],
          totalCount: 15,
          pageSize: 5,
          focused: true,
        )..viewport(rows: 3);

        final result = paged.update(keyMsg('end'));

        expect(paged.cursor, equals(14));
        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isNotNull),
          reason: 'the jump lands on missing pages',
        );
        expect(paged.isLoading(const PageKey(2)), isTrue, reason: 'the destination page is fetched first');
      });
    });

    group('scroll offset', () {
      late ListViewModel<String, String> model;

      setUp(() {
        model = ListViewModel<String, String>(
          items: List.generate(20, (i) => 'item$i'),
          focused: true,
        )..viewport(rows: 5);
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
            items: const ['a', 'b', 'c'],
            focused: true,
          )..update(keyMsg('space'));
          expect(model.getSelectedKeys(), isEmpty);
        });
      });

      group('multi-select', () {
        late ListViewModel<String, String> model;

        setUp(() {
          model = ListViewModel<String, String>(
            items: const ['a', 'b', 'c', 'd', 'e'],
            multiSelect: true,
            focused: true,
          )..viewport(rows: 5);
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
            items: const ['a', 'b', 'c', 'd', 'e'],
            multiSelect: true,
            focused: true,
          )..viewport(rows: 5);
        });

        test('shift+down extends check range', () {
          model.update(keyMsg('shift+down'));
          expect(model.cursor, equals(1));
          expect(model.getSelectedKeys(), equals({'a', 'b'}));
        });

        test('shift+j extends check range (vim)', () {
          // A real Shift+J keystroke arrives already folded by toSpec() at
          // intake, so the KeyMsg carries 'J', never 'shift+j'.
          model.update(keyMsg('J'));
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
          // A real Shift+K keystroke arrives already folded by toSpec() at
          // intake, so the KeyMsg carries 'K', never 'shift+k'.
          model
            ..update(keyMsg('down'))
            ..update(keyMsg('down'))
            ..update(keyMsg('K'));
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
      });

      group('range completes itself over arriving pages', () {
        ListViewModel<String, String> paged() => ListViewModel<String, String>(
          items: const ['a', 'b'],
          totalCount: 6,
          pageSize: 2,
          loadThreshold: 0,
          multiSelect: true,
          focused: true,
        )..viewport(rows: 2);

        test('a page landing inside an active range contributes its keys', () {
          final model = paged()
            ..update(keyMsg('shift+down')) // anchor 0, cursor 1: selects a, b
            ..update(keyMsg('shift+down')); // cursor 2 — its page is missing, requested now
          expect(model.getSelectedKeys(), equals({'a', 'b'}), reason: 'row 2 cannot be captured yet');
          expect(model.isLoading(const PageKey(1)), isTrue);

          model.update(LoadResult<List<String>>(model.id, key: const PageKey(1), data: const ['c', 'd']));

          expect(
            model.getSelectedKeys(),
            equals({'a', 'b', 'c'}),
            reason: 'row 2 was inside the range; row 3 was not',
          );
        });

        test('a page landing after the anchor cleared contributes nothing', () {
          final model = paged()
            ..update(keyMsg('shift+down'))
            ..update(keyMsg('shift+down')) // requests page 1
            ..update(keyMsg('down')); // clears the anchor
          expect(model.isLoading(const PageKey(1)), isTrue);

          model.update(LoadResult<List<String>>(model.id, key: const PageKey(1), data: const ['c', 'd']));

          expect(model.getSelectedKeys(), equals({'a', 'b'}), reason: 'no active range to complete');
        });
      });

      group('disabled items', () {
        test('disabled items cannot be checked', () {
          final model =
              ListViewModel<String, String>(
                  items: const ['a', 'b', 'c'],
                  multiSelect: true,
                  isDisabled: (i) => i == 1,
                  focused: true,
                )
                ..viewport(rows: 5)
                ..update(keyMsg('down')) // cursor at b (disabled)
                ..update(keyMsg('space')); // should not check
          expect(model.getSelectedKeys(), isEmpty);
        });

        test('range select skips disabled', () {
          final model =
              ListViewModel<String, String>(
                  items: const ['a', 'b', 'c', 'd'],
                  multiSelect: true,
                  isDisabled: (i) => i == 1,
                  focused: true,
                )
                ..viewport(rows: 5)
                ..update(keyMsg('shift+down'))
                ..update(keyMsg('shift+down'))
                ..update(keyMsg('shift+down'));
          expect(model.getSelectedKeys(), equals({'a', 'c', 'd'})); // b skipped
        });
      });
    });

    group('commands', () {
      test('enter returns ListActionCmd', () {
        final model = ListViewModel<String, String>(
          items: const ['a', 'b'],
          focused: true,
        );
        final result = model.update(keyMsg('enter'));
        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isA<ListActionCmd>()),
        );
        final cmd = (result as Handled).cmd;
        expect((cmd! as ListActionCmd).id, equals(model.id));
      });

      test('enter on an item the window does not hold is consumed and emits nothing', () {
        final model = ListViewModel<String, String>(
          totalCount: 4,
          focused: true,
        )..viewport(rows: 4);

        final result = model.update(keyMsg('enter'));

        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'a declined confirm would fire the app fallback bindings',
        );
      });

      test('unhandled key declines', () {
        final model = ListViewModel<String, String>(
          items: const ['a'],
          focused: true,
        );
        final result = model.update(keyMsg('tab'));
        expect(result, isA<Declined>());
      });

      test('unfocused declines', () {
        final model = ListViewModel<String, String>(
          items: const ['a'],
        );
        final result = model.update(keyMsg('down'));
        expect(result, isA<Declined>());
      });

      test('declines a message it does not know', () {
        final model = ListViewModel<String, String>(
          items: const ['a'],
          focused: true,
        );
        final result = model.update(const _UnknownMsg());
        expect(result, isA<Declined>());
      });
    });

    group('load requests', () {
      // Viewport of 2 over one held page of 5, in a data set of 15: demand keys
      // on the viewport plus the threshold, so scrolling has to bring the
      // window's edge near the page boundary before anything is asked for.
      ListViewModel<String, String> paginated() => ListViewModel<String, String>(
        items: const ['a', 'b', 'c', 'd', 'e'],
        totalCount: 15,
        pageSize: 5,
        loadThreshold: 2,
        focused: true,
      )..viewport(rows: 2);

      test('returns a LoadRequest when the viewport nears a missing page', () {
        final model = paginated()
          ..update(keyMsg('down')) // cursor 1
          ..update(keyMsg('down')); // cursor 2

        final result = model.update(keyMsg('down')); // cursor 3 — threshold reaches page 1
        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isA<LoadRequest>()),
        );
        final cmd = (result as Handled).cmd;
        expect((cmd! as LoadRequest).id, equals(model.id));
        expect((cmd as LoadRequest).key, equals(const PageKey(1)));
        expect(model.isLoading(), isTrue, reason: 'the widget self-marks loading on emit');
      });

      test('does not re-request while the page is already in flight (self-dedup)', () {
        final model = paginated()
          ..update(keyMsg('down'))
          ..update(keyMsg('down'))
          ..update(keyMsg('down')); // first request emitted, page 1 now loading
        expect(model.isLoading(), isTrue);

        final result = model.update(keyMsg('down'));
        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'the page is already on its way',
        );
      });

      test('a fully held list never requests', () {
        final model =
            ListViewModel<String, String>(
                items: const ['a', 'b', 'c'],
                loadThreshold: 2,
                focused: true,
              )
              ..viewport(rows: 5)
              ..update(keyMsg('down'))
              ..update(keyMsg('down'));

        final result = model.update(keyMsg('down'));
        // Items seeded with no totalCount are all the data: no page is missing.
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
      });
    });

    group('viewport reports', () {
      // Five of fifteen items held; a viewport of two reaches nothing more,
      // a viewport of ten reaches page 1.
      ListViewModel<String, String> paged() => ListViewModel<String, String>(
        id: 'list',
        items: const ['a', 'b', 'c', 'd', 'e'],
        totalCount: 15,
        pageSize: 5,
        loadThreshold: 0,
      );

      test('a report equal to the stored count is consumed with no command', () {
        final model = paged()..viewport(rows: 2);

        final verdict = model.update(const ViewportChanged('list', rows: 2));

        expect(verdict, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(model.visibleCount, equals(2));
      });

      test('a changed count is stored and returns the demand for the pages it reveals', () {
        final model = paged()..viewport(rows: 2);

        final verdict = model.update(const ViewportChanged('list', rows: 10));

        expect(model.visibleCount, equals(10));
        expect(
          verdict,
          isA<Handled>().having((h) => h.cmd, 'cmd', isA<LoadRequest>().having((r) => r.key, 'key', const PageKey(1))),
          reason: 'the taller viewport reaches page 1',
        );
        expect(model.isLoading(const PageKey(1)), isTrue);
      });

      test('a report addressed to another id is declined', () {
        final model = paged();

        expect(model.update(const ViewportChanged('other', rows: 10)), isA<Declined>());
        expect(model.visibleCount, equals(0));
      });

      test("a report carrying this id's path under a scope is the list's own", () {
        final model = paged();

        expect(model.update(const ViewportChanged('combo/list', rows: 2)), isA<Handled>());
        expect(model.visibleCount, equals(2));
      });
    });

    group('load lifecycle', () {
      // A cold list before its first frame: the app's init fetch precedes any
      // viewport report, so nothing but what a test asks for is in flight.
      ListViewModel<String, String> paged() => ListViewModel<String, String>(
        pageSize: 2,
        focused: true,
      );

      test('loadFirstPage marks page 0 loading and returns a request', () {
        final model = paged();
        final req = model.loadFirstPage();
        expect(req.id, equals(model.id));
        expect(req.key, equals(const PageKey(0)));
        expect(model.isLoading(const PageKey(0)), isTrue);
      });

      test('update(LoadResult) installs the page, clears the slot, and returns the next demand pass', () {
        final model = paged();
        final req = model.loadFirstPage();
        final verdict = model.update(LoadResult<List<String>>(req.id, key: req.key, data: const ['a', 'b']));

        expect(model.getItem(0), equals('a'));
        expect(model.cursorItem, equals('a'));
        expect(model.isLoading(const PageKey(0)), isFalse, reason: 'the slot is cleared');
        expect(model.knownItemCount, isNull, reason: 'a full page says nothing about where the data ends');
        expect(
          verdict,
          isA<Handled>().having((h) => h.cmd, 'cmd', isNotNull),
          reason: 'the install freed a slot: the pass asks for the pages past the one that landed',
        );
        expect(model.isLoading(const PageKey(1)), isTrue);
      });

      test('a short page records where the data ends', () {
        final model = paged();
        final req = model.loadFirstPage();
        model.update(LoadResult<List<String>>(req.id, key: req.key, data: const ['a']));

        expect(model.knownItemCount, equals(1));
        expect(model.itemLimit, equals(1));
      });

      test('a failed load records the error and is retryable', () {
        final model = paged();
        final req = model.loadFirstPage();
        model.update(LoadResult<List<String>>(req.id, key: req.key, error: 'boom'));

        expect(model.isLoading(), isFalse);
        expect(model.errorFor(const PageKey(0)), equals('boom'));
        expect(model.demand(), isNotNull, reason: 'the next demand pass retries');
        expect(model.isLoading(const PageKey(0)), isTrue, reason: 'the failed page is asked for again');
      });

      test('a refused load clears the slot and installs nothing', () {
        final model = paged();
        final req = model.loadFirstPage();
        model.update(LoadResult<List<String>>.cancelled(req.id, key: req.key));

        expect(model.isLoading(), isFalse, reason: 'the slot returns to idle, so the page can be asked for again');
        expect(model.errorFor(const PageKey(0)), isNull, reason: 'nothing failed');
        expect(model.cachedItemCount, equals(0), reason: 'no items were installed');
        expect(model.knownItemCount, isNull, reason: 'a refusal teaches the list nothing about where data ends');
      });

      test('a refusal or a failure returns no demand pass', () {
        final model = paged();
        final req = model.loadFirstPage();

        expect(
          model.update(LoadResult<List<String>>.cancelled(req.id, key: req.key)),
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'a standing refusal must never become a request storm',
        );
        model.loadFirstPage();
        expect(
          model.update(LoadResult<List<String>>(req.id, key: req.key, error: 'boom')),
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'a failure is retried by the next pass the app runs, not by itself',
        );
      });

      test('a result for a page not in flight is dropped (staleness guard)', () {
        final model = paged();
        // No loadFirstPage — the page is not in flight, so this is a stale arrival.
        model.update(LoadResult<List<String>>(model.id, key: const PageKey(0), data: const ['x']));
        expect(model.cachedItemCount, equals(0), reason: 'a stale result must not install');
      });

      test('a result for another id is declined and ignored', () {
        final model = paged()..loadFirstPage();
        final verdict = model.update(const LoadResult<List<String>>('other', key: PageKey(0), data: ['x']));

        expect(verdict, isA<Declined>(), reason: 'a message addressed elsewhere is not one this list understands');
        expect(model.cachedItemCount, equals(0));
        expect(model.isLoading(), isTrue, reason: 'still waiting for its own result');
      });

      test('every result addressed to the list is consumed, installed or not', () {
        final model = paged();
        final req = model.loadFirstPage();

        expect(model.update(LoadResult<List<String>>(req.id, key: req.key, data: const ['a'])), isA<Handled>());
        expect(
          model.update(LoadResult<List<String>>(model.id, key: const PageKey(7), data: const ['x'])),
          isA<Handled>(),
          reason: "a stale page is dropped, but the message was the list's own",
        );
        expect(model.update(LoadResult<List<String>>(model.id, key: 'not a page', data: const ['x'])), isA<Handled>());
      });
    });

    group('the end landing closer than navigation reached', () {
      // One held page of 5, end unknown: pages past it are presumed to exist,
      // so navigation runs ahead into rows whose fetch is still out.
      ListViewModel<String, String> ranAhead() {
        // Seed through insertItems, not `items:` — a constructor seed is taken
        // to be all the data, and this scenario needs the end unknown.
        final model =
            ListViewModel<String, String>(
                pageSize: 5,
                loadThreshold: 2,
                focused: true,
              )
              ..insertItems(const ['a', 'b', 'c', 'd', 'e'], 0)
              ..viewport(rows: 3)
              ..update(keyMsg('pageDown')) // cursor 3 — demand puts page 1 in flight
              ..update(keyMsg('pageDown')) // cursor 6, into the pending page
              ..update(keyMsg('pageDown')); // cursor 9, scroll 7
        expect(model.cursor, equals(9));
        expect(model.scrollOffset, equals(7));
        return model;
      }

      test('a short page pulls the cursor and viewport back to the real end', () {
        final model = ranAhead();
        final short = LoadResult<List<String>>(model.id, key: const PageKey(1), data: const ['f']);
        model.update(short);

        expect(model.knownItemCount, equals(6));
        expect(model.cursor, equals(5), reason: 'the rows past the end stopped existing');
        expect(model.scrollOffset, equals(3), reason: 'the last item lands on the bottom row (6 - 3 visible)');
        expect(model.cursorItem, equals('f'));
      });

      test('a count landing closer than the cursor pulls both back', () {
        final model = ranAhead()..totalCount = 6;

        expect(model.cursor, equals(5));
        expect(model.scrollOffset, equals(3));
      });
    });

    group('wholesale replacement', () {
      test('reset + insertItems + totalCount swaps the data and rewinds the view', () {
        final model =
            ListViewModel<String, String>(
                items: const ['a', 'b', 'c', 'd', 'e'],
                multiSelect: true,
                focused: true,
              )
              ..viewport(rows: 3)
              ..update(keyMsg('space'))
              ..update(keyMsg('end'));
        expect(model.getSelectedKeys(), isNotEmpty);
        expect(model.cursor, equals(4));

        const filtered = ['b', 'd'];
        model
          ..reset()
          ..insertItems(filtered, 0)
          ..totalCount = filtered.length;

        expect(model.cursor, equals(0));
        expect(model.scrollOffset, equals(0));
        expect(model.getSelectedKeys(), isEmpty);
        expect(model.knownItemCount, equals(2));
        expect(model.getItem(0), equals('b'));
        expect(model.demand(), isNull, reason: 'the new length says where the data ends');
      });
    });

    group('empty list', () {
      test('handles empty data source', () {
        final model = ListViewModel<String, String>(
          items: const [],
          focused: true,
        );
        expect(model.cursor, equals(0));
        expect(model.cursorItem, isNull);
        expect(model.knownItemCount, equals(0));
        expect(model.itemLimit, equals(0));
      });

      test('navigation on empty list is safe', () {
        final model =
            ListViewModel<String, String>(
                items: const [],
                focused: true,
              )
              ..viewport(rows: 5)
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
