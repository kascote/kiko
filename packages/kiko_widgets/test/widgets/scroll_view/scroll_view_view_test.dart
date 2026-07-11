import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// Three stacked, individually tagged rows — 'a', 'b', 'c' — each 3 rows
/// tall, [w] wide, for a 9-row content total.
View _taggedRows(int w) => Column(
  children: [
    Tagged('a', SizedBox(width: w, height: 3)),
    Tagged('b', SizedBox(width: w, height: 3)),
    Tagged('c', SizedBox(width: w, height: 3)),
  ],
);

void main() {
  group('ScrollView view', () {
    test('the content is tagged with the model id', () {
      final model = ScrollViewModel(id: 'panel');
      const child = SizedBox(width: 6, height: 3);
      final frame = _frame(6, 3)..render(ScrollView(model: model, child: child));

      expect(frame.hits.hitId(0, 0), 'panel');
    });

    test('windows a shorter view onto a taller composed region', () {
      final model = ScrollViewModel();
      final view = ScrollView(model: model, child: _taggedRows(6));

      final first = _frame(6, 4)..render(view);
      expect(first.hits.hitId(0, 0), 'a');
      expect(first.hits.hitId(0, 3), 'b', reason: "b's first row is the window's last row");
      expect(first.hits.rectOf('c'), isNull, reason: 'c is scrolled below the 4-row window');

      model.scrollBy(3);
      final second = _frame(6, 4)..render(view);
      expect(second.hits.hitId(0, 0), 'b', reason: 'the window now starts at content row 3');
      expect(second.hits.rectOf('a'), isNull, reason: 'a has scrolled entirely above the window');
    });

    test('installs viewportRows and contentRows into the model after paint', () {
      final model = ScrollViewModel();
      _frame(6, 4).render(ScrollView(model: model, child: _taggedRows(6)));

      expect(model.viewportRows, equals(4));
      expect(model.contentRows, equals(9));
    });

    test('ensureVisible works against the ranges the view measured', () {
      final model = ScrollViewModel();
      final view = ScrollView(model: model, child: _taggedRows(6));
      _frame(6, 4).render(view);

      model.ensureVisible('c');
      expect(model.scrollOffset, equals(5), reason: 'c spans [6,9); top+height-viewportRows = 6+3-4');
    });

    test('an untagged region reports no range, so ensureVisible on it is a no-op', () {
      final model = ScrollViewModel();
      _frame(6, 4).render(ScrollView(model: model, child: _taggedRows(6)));

      model.ensureVisible('no-such-tag');
      expect(model.scrollOffset, equals(0));
    });
  });

  group('pointer pass-through', () {
    test('a point over a tagged child resolves to the child, not the ScrollView', () {
      final model = ScrollViewModel(id: 'panel');
      final frame = _frame(6, 4)..render(ScrollView(model: model, child: _taggedRows(6)));

      expect(frame.hits.hitId(0, 0), 'a', reason: 'the innermost tag wins');
    });

    test('a point over a gap between children still resolves to the ScrollView', () {
      final model = ScrollViewModel(id: 'panel');
      const content = Column(
        children: [
          Tagged('a', SizedBox(width: 6, height: 2)),
          SizedBox(width: 6, height: 1), // an untagged gap
          Tagged('b', SizedBox(width: 6, height: 2)),
        ],
      );
      final frame = _frame(6, 5)..render(ScrollView(model: model, child: content));

      expect(frame.hits.hitId(0, 2), 'panel', reason: 'the gap is inside the content area — finding E, killed');
    });
  });

  group('nested scrolling (offerOutward, mikos 0176)', () {
    // A ListView (its own ScrollableModel) composed inside a ScrollView. The
    // outer content is header(2) + list(3) + footer(2) = 7 rows, shown
    // through a 5-row outer viewport (contentRows 7 > viewportRows 5, so the
    // outer can scroll too). The list shows 3 of its own 6 items at a time.
    ({ScrollViewModel outer, ListViewModel<String, String> list, HitMap hits}) build() {
      final outer = ScrollViewModel(id: 'outer');
      final list = ListViewModel<String, String>(id: 'inner-list', dataView: DataView.fromList(_items));

      final content = Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          const Tagged('header', SizedBox(width: 10, height: 2)),
          ConstrainedBox(
            additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
            child: ListView<String, String>(model: list, theme: Theme.dark, itemBuilder: (item, i, s) => [Line(item)]),
          ),
          const Tagged('footer', SizedBox(width: 10, height: 2)),
        ],
      );

      final frame = _frame(10, 5)..render(ScrollView(model: outer, child: content));
      return (outer: outer, list: list, hits: frame.hits);
    }

    PointerMsg wheelDownOn(String targetId, Rect rect) => PointerMsg(
      MouseEvent(rect.x, rect.y, MouseButton.wheelDown()),
      targetId: targetId,
      local: Position.origin,
      targetRect: rect,
    );

    test('mid-content, the inner list handles the wheel and the outer never moves', () {
      final m = build()..list.scrollBy(1); // off both edges: offset 1 of max 3
      final listRect = m.hits.rectOf('inner-list')!;

      expect(m.list.update(wheelDownOn('inner-list', listRect)), isA<Handled>());
      expect(m.outer.scrollOffset, equals(0), reason: 'the list consumed it — the outer was never even asked');
    });

    test('at the list bottom, the list declines and offerOutward scrolls the enclosing ScrollView', () {
      final m = build()..list.scrollBy(100); // pin the list to its own bottom edge
      final listRect = m.hits.rectOf('inner-list')!;
      final msg = wheelDownOn('inner-list', listRect);

      expect(m.list.update(msg), isA<Declined>(), reason: 'the list has nothing left to scroll down');

      final ctx = UpdateContext(hits: m.hits, area: Rect.create(x: 0, y: 0, width: 10, height: 5));
      final targets = <String, Component>{'inner-list': m.list, 'outer': m.outer};
      final result = offerOutward(msg, ctx, targets);

      expect(result, isA<Handled>());
      expect(m.outer.scrollOffset, equals(2), reason: 'clamped to contentRows(7) - viewportRows(5)');
    });
  });
}

final List<String> _items = List.generate(6, (i) => 'item$i');
