import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// A routed wheel/button message over the widget, at local (0, 0).
PointerMsg pointer(MouseButton button) => PointerMsg(MouseEvent(0, 0, button), local: Position.origin);

/// A model with [viewportRows] of [contentRows] installed, as the view's
/// measurement callback would push in after a real frame.
ScrollViewModel scrollable({int contentRows = 10, int viewportRows = 5, bool focused = false}) =>
    ScrollViewModel(focused: focused)
      ..setViewportMetrics(viewportRows: viewportRows, contentRows: contentRows, tagRanges: const {});

void main() {
  group('initialization', () {
    test('auto-generates an id with the scrollview prefix when none is given', () {
      final model = ScrollViewModel();
      expect(model.id, startsWith('scrollview-'));
    });

    test('accepts an explicit id', () {
      final model = ScrollViewModel(id: 'sidebar');
      expect(model.id, equals('sidebar'));
    });

    test('starts unfocused by default', () {
      expect(ScrollViewModel().focused, isFalse);
    });

    test('starts with no geometry until the view measures a frame', () {
      final model = ScrollViewModel();
      expect(model.scrollOffset, equals(0));
      expect(model.viewportRows, equals(0));
      expect(model.contentRows, equals(0));
      expect(model.visibleCount, equals(0), reason: 'the shared scrollable surface reads viewportRows');
    });
  });

  group('mouse wheel + scroll', () {
    test('a wheel notch scrolls an unfocused view', () {
      final model = scrollable();
      final result = model.update(pointer(MouseButton.wheelDown()));

      expect(result, isA<Handled>());
      expect(model.scrollOffset, equals(3), reason: 'one notch is three rows');
    });

    test('scrollBy clamps at both ends', () {
      final model = scrollable(viewportRows: 4);

      expect((model..scrollBy(-5)).scrollOffset, equals(0), reason: 'cannot scroll above the first row');
      expect((model..scrollBy(100)).scrollOffset, equals(6), reason: 'stops at contentRows - viewportRows (10 - 4)');
      expect((model..scrollBy(50)).scrollOffset, equals(6), reason: 'already at the bottom edge');
    });

    test('scrollBy reports rows actually moved', () {
      final model = scrollable(viewportRows: 4);
      expect(model.scrollBy(2), equals(2));
      expect(model.scrollBy(100), equals(4), reason: 'only 4 more rows were left to move (6 - 2)');
      expect(model.scrollBy(1), equals(0), reason: 'already at the edge');
    });

    test('localToRow maps a local position to the content row', () {
      final model = scrollable()..scrollBy(2);

      expect(model.localToRow(Position.origin), equals(2));
      expect(model.localToRow(const Position(3, 3)), equals(5), reason: 'row = scrollOffset + local.y');
      expect(model.localToRow(const Position(0, -1)), isNull, reason: 'above the first row');
      expect(model.localToRow(const Position(0, 8)), isNull, reason: 'past the last content row');
    });

    test('a horizontal wheel is declined so it passes through to composed children', () {
      final model = scrollable();
      expect(model.update(pointer(MouseButton.wheelLeft())), isA<Declined>());
      expect(model.update(pointer(MouseButton.wheelRight())), isA<Declined>());
    });

    group('wheel decline at the scroll limit (mikos 0176 / G2)', () {
      test('at the top, wheel-up declines while wheel-down handles', () {
        final model = scrollable();
        expect(model.update(pointer(MouseButton.wheelUp())), isA<Declined>());
        expect(model.scrollOffset, equals(0), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(MouseButton.wheelDown())), isA<Handled>());
      });

      test('at the bottom, wheel-down declines while wheel-up handles', () {
        final model = scrollable()..scrollBy(100); // pin to the bottom edge
        final atBottom = model.scrollOffset;
        expect(model.update(pointer(MouseButton.wheelDown())), isA<Declined>());
        expect(model.scrollOffset, equals(atBottom), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(MouseButton.wheelUp())), isA<Handled>());
      });

      test('content that fits entirely declines both directions', () {
        final model = scrollable(contentRows: 3);
        expect(model.update(pointer(MouseButton.wheelUp())), isA<Declined>());
        expect(model.update(pointer(MouseButton.wheelDown())), isA<Declined>());
      });

      test('a partial scroll still consumes, even though it moves fewer rows than a full notch', () {
        // scrollOffset 4, max 5 (10 rows - 5 viewport): a 3-row notch down can
        // only move 1 row, but 1 row is not a no-op, so it must still handle.
        final model = scrollable()..scrollBy(4);
        expect(model.scrollOffset, equals(4));

        final result = model.update(pointer(MouseButton.wheelDown()));
        expect(result, isA<Handled>());
        expect(model.scrollOffset, equals(5), reason: 'moved the 1 remaining row');
      });

      test('mid-content, both directions handle', () {
        final model = scrollable()..scrollBy(2);
        expect(model.update(pointer(MouseButton.wheelDown())), isA<Handled>());
        expect(model.update(pointer(MouseButton.wheelUp())), isA<Handled>());
      });
    });
  });

  group('pointer pass-through', () {
    test('a click, drag, and move are all declined so children resolve them', () {
      final model = scrollable(focused: true);
      expect(model.update(pointer(MouseButton.down())), isA<Declined>());
      expect(model.update(pointer(MouseButton.drag())), isA<Declined>());
      expect(model.update(pointer(MouseButton.moved())), isA<Declined>());
    });

    test('leave and cancel are declined', () {
      final model = scrollable(focused: true);
      expect(model.update(const PointerLeaveMsg('scrollview-1')), isA<Declined>());
      expect(model.update(const PointerCancelMsg('scrollview-1')), isA<Declined>());
    });
  });

  group('keyboard', () {
    test('unfocused declines every key', () {
      final model = scrollable();
      expect(model.update(keyMsg('down')), isA<Declined>());
    });

    test('an unbound key is declined even when focused', () {
      final model = scrollable(focused: true);
      expect(model.update(keyMsg('x')), isA<Declined>());
    });

    test('up/down move one row, page up/down move one viewport', () {
      final model = scrollable(contentRows: 20, focused: true)..scrollBy(5);

      expect(model.update(keyMsg('down')), isA<Handled>());
      expect(model.scrollOffset, equals(6));
      expect(model.update(keyMsg('up')), isA<Handled>());
      expect(model.scrollOffset, equals(5));
      expect(model.update(keyMsg('pageDown')), isA<Handled>());
      expect(model.scrollOffset, equals(10));
      expect(model.update(keyMsg('pageUp')), isA<Handled>());
      expect(model.scrollOffset, equals(5));
    });

    test('vim aliases j/k mirror down/up', () {
      final model = scrollable(contentRows: 20, focused: true)..scrollBy(5);
      expect(model.update(keyMsg('j')), isA<Handled>());
      expect(model.scrollOffset, equals(6));
      expect(model.update(keyMsg('k')), isA<Handled>());
      expect(model.scrollOffset, equals(5));
    });

    test('home/g and end/G jump to the top and bottom', () {
      final model = scrollable(contentRows: 20, focused: true)..scrollBy(5);

      expect(model.update(keyMsg('home')), isA<Handled>());
      expect(model.scrollOffset, equals(0));
      expect(model.update(keyMsg('end')), isA<Handled>());
      expect(model.scrollOffset, equals(15));

      expect(model.update(keyMsg('g')), isA<Handled>());
      expect(model.scrollOffset, equals(0));
      expect(model.update(keyMsg('G')), isA<Handled>());
      expect(model.scrollOffset, equals(15));
    });

    test('a custom keyBinding overrides the defaults', () {
      final binding = defaultScrollViewBindings.copy()..map(['ctrl+f'], ScrollViewAction.pageDown);
      final model = ScrollViewModel(focused: true, keyBinding: binding)
        ..setViewportMetrics(viewportRows: 5, contentRows: 20, tagRanges: const {});

      expect(model.update(keyMsg('ctrl+f')), isA<Handled>());
      expect(model.scrollOffset, equals(5));
    });

    test('unbind removes a default binding', () {
      final binding = defaultScrollViewBindings.copy()..unbind(ScrollViewAction.lineDown);
      final model = ScrollViewModel(focused: true, keyBinding: binding)
        ..setViewportMetrics(viewportRows: 5, contentRows: 20, tagRanges: const {});

      expect(model.update(keyMsg('down')), isA<Declined>());
      expect(model.update(keyMsg('j')), isA<Declined>());
    });
  });

  group('setViewportMetrics', () {
    test('installs viewportRows and contentRows, readable through visibleCount too', () {
      final model = ScrollViewModel()..setViewportMetrics(viewportRows: 4, contentRows: 9, tagRanges: const {});
      expect(model.viewportRows, equals(4));
      expect(model.visibleCount, equals(4));
      expect(model.contentRows, equals(9));
    });

    test('re-clamps a scroll offset the new geometry can no longer support', () {
      final model = scrollable(contentRows: 20)..scrollBy(15);
      expect(model.scrollOffset, equals(15));

      // The content shrank (e.g. a filter removed rows) — re-measuring must
      // pull the offset back in, not leave it pointing past the new content.
      model.setViewportMetrics(viewportRows: 5, contentRows: 8, tagRanges: const {});
      expect(model.scrollOffset, equals(3));
    });
  });

  group('ensureVisible', () {
    ScrollViewModel withRanges(Map<String, ScrollViewTagRange> ranges, {int offset = 0}) => ScrollViewModel()
      ..setViewportMetrics(viewportRows: 5, contentRows: 20, tagRanges: ranges)
      ..scrollBy(offset);

    test('a fully visible range is a no-op', () {
      final model = withRanges({'field': (top: 6, height: 2)}, offset: 5)..ensureVisible('field');
      expect(model.scrollOffset, equals(5));
    });

    test('a range above the window scrolls up to its top', () {
      final model = withRanges({'field': (top: 1, height: 2)}, offset: 5)..ensureVisible('field');
      expect(model.scrollOffset, equals(1));
    });

    test('a range below the window scrolls the minimum to bring its bottom into view', () {
      final model = withRanges({'field': (top: 6, height: 2)})..ensureVisible('field');
      expect(model.scrollOffset, equals(3), reason: 'top + height - viewportRows = 6 + 2 - 5');
    });

    test('a range taller than the viewport top-aligns instead of centering', () {
      final model = withRanges({'field': (top: 2, height: 7)})..ensureVisible('field');
      expect(model.scrollOffset, equals(2));
    });

    test('an id absent from the last measured frame is a no-op', () {
      final model = withRanges({'other': (top: 0, height: 1)}, offset: 5)..ensureVisible('missing');
      expect(model.scrollOffset, equals(5), reason: 'the one-frame lag makes absence transiently normal');
    });
  });

  group('getScrollState', () {
    test('mirrors the offset, viewportRows, and contentRows the view last measured', () {
      final model = scrollable(contentRows: 20)..scrollBy(3);
      final state = model.getScrollState();
      expect(state.offset, equals(3));
      expect(state.viewportRows, equals(5));
      expect(state.contentRows, equals(20));
      expect(state.progress, closeTo(0.2, 0.0001), reason: '3 / (20 - 5)');
      expect(state.thumbSize, closeTo(0.25, 0.0001), reason: '5 / 20');
    });

    test('content that fits entirely reports zero progress and a full thumb', () {
      final model = scrollable(contentRows: 3);
      final state = model.getScrollState();
      expect(state.progress, equals(0));
      expect(state.thumbSize, equals(1));
    });
  });
}
