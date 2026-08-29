import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

import '../../support/reports.dart';

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

      first.deliverReports(model); // the model learns its extent before it can scroll
      model.scrollBy(3);
      final second = _frame(6, 4)..render(view);
      expect(second.hits.hitId(0, 0), 'b', reason: 'the window now starts at content row 3');
      expect(second.hits.rectOf('a'), isNull, reason: 'a has scrolled entirely above the window');
    });

    test('paint reports a ScrollMetrics addressed to the model, and writes nothing into it', () {
      final model = ScrollViewModel(id: 'panel');
      final frame = _frame(6, 4)..render(ScrollView(model: model, child: _taggedRows(6)));

      expect(model.viewportRows, equals(0), reason: 'paint reports; the model learns the fact from the report');
      expect(model.contentRows, equals(0));
      final report = frame.reports.single;
      expect(report, isA<ScrollMetrics>());
      expect(report.id, 'panel');
      final metrics = report as ScrollMetrics;
      expect(metrics.viewportRows, equals(4));
      expect(metrics.contentRows, equals(9));
      expect(metrics.tagRanges, {
        'a': (top: 0, height: 3),
        'b': (top: 3, height: 3),
        'c': (top: 6, height: 3),
      });
    });

    test('the delivered report installs viewportRows and contentRows into the model', () {
      final model = ScrollViewModel();
      _frame(6, 4)
        ..render(ScrollView(model: model, child: _taggedRows(6)))
        ..deliverReports(model);

      expect(model.viewportRows, equals(4));
      expect(model.contentRows, equals(9));
    });

    test('a paint whose geometry the model already holds reports nothing', () {
      final model = ScrollViewModel();
      final view = ScrollView(model: model, child: _taggedRows(6));
      _frame(6, 4)
        ..render(view)
        ..deliverReports(model);

      final second = _frame(6, 4)..render(view);
      expect(second.reports, isEmpty, reason: 'the model holds the geometry, so the frame a report causes settles');

      model.scrollBy(3);
      final scrolled = _frame(6, 4)..render(view);
      expect(scrolled.reports, isEmpty, reason: 'ranges are content-relative, so scrolling changes nothing');

      final resized = _frame(6, 5)..render(view);
      expect((resized.reports.single as ScrollMetrics).viewportRows, equals(5), reason: 'a new extent is news again');
    });

    test('ensureVisible works against the ranges the view reported', () {
      final model = ScrollViewModel();
      final view = ScrollView(model: model, child: _taggedRows(6));
      _frame(6, 4)
        ..render(view)
        ..deliverReports(model);

      model.ensureVisible('c');
      expect(model.scrollOffset, equals(5), reason: 'c spans [6,9); top+height-viewportRows = 6+3-4');
    });

    test('an untagged region reports no range, so ensureVisible on it is a no-op', () {
      final model = ScrollViewModel();
      _frame(6, 4)
        ..render(ScrollView(model: model, child: _taggedRows(6)))
        ..deliverReports(model);

      model.ensureVisible('no-such-tag');
      expect(model.scrollOffset, equals(0));
    });
  });

  group('ensureVisible with scoped tag ranges', () {
    // A scope named 'field' wrapping chrome (an untagged 3-row label/border)
    // around a content leaf tagged 'field' too — the E-split recipe scopes
    // enable: the bare id 'field' names the whole frame, 'field/field' names
    // just the content.
    View framedField() => const Tagged.scope(
      'field',
      Column(
        children: [
          SizedBox(width: 6, height: 3),
          Tagged('field', SizedBox(width: 6, height: 2)),
        ],
      ),
    );

    test('a bare scope name brings the whole framed chrome into view', () {
      final model = ScrollViewModel();
      final content = Column(children: [const SizedBox(width: 6, height: 5), framedField()]);
      _frame(6, 3)
        ..render(ScrollView(model: model, child: content))
        ..deliverReports(model);

      model.ensureVisible('field');
      expect(model.scrollOffset, equals(5), reason: 'the frame spans [5,10), taller than the viewport, top-aligns');
    });

    test("the 'id/id' leaf path brings only the content leaf into view", () {
      final model = ScrollViewModel();
      final content = Column(children: [const SizedBox(width: 6, height: 5), framedField()]);
      _frame(6, 3)
        ..render(ScrollView(model: model, child: content))
        ..deliverReports(model);

      model.ensureVisible('field/field');
      expect(model.scrollOffset, equals(7), reason: 'the leaf spans [8,10); top+height-viewportRows = 8+2-3');
    });

    test('a repeated scope path unions its rows across every occurrence', () {
      final model = ScrollViewModel();
      const content = Column(
        children: [
          SizedBox(width: 6, height: 1),
          Tagged.scope('group', SizedBox(width: 6, height: 2)), // [1, 3)
          SizedBox(width: 6, height: 6),
          Tagged.scope('group', SizedBox(width: 6, height: 2)), // [9, 11)
        ],
      );
      _frame(6, 3)
        ..render(ScrollView(model: model, child: content))
        ..deliverReports(model);

      model.ensureVisible('group');
      expect(
        model.scrollOffset,
        equals(1),
        reason: 'the union spans [1,11), taller than the viewport, top-aligns to the first occurrence',
      );
    });
  });

  group('a ScrollView under a scope', () {
    // The scroll view sits under an app scope 'outer'. Every key the view
    // reports carries that scope too, so a key is the path the hit map
    // records for the descendant, and ensureVisible takes the same string a
    // pointer event delivers.
    View framedField() => const Tagged.scope(
      'field',
      Column(
        children: [
          SizedBox(width: 6, height: 3),
          Tagged('field', SizedBox(width: 6, height: 2)),
        ],
      ),
    );

    test('the report is addressed to the scoped path, and the model accepts it by leaf', () {
      final model = ScrollViewModel(id: 'panel');
      final content = Column(children: [const SizedBox(width: 6, height: 5), framedField()]);
      final frame = _frame(6, 3)
        ..render(
          Tagged.scope(
            'outer',
            Container(
              child: ScrollView(model: model, child: content),
            ),
          ),
        );

      final report = frame.reports.single as ScrollMetrics;
      expect(report.id, 'outer/panel');
      expect(frame.hits.hitId(0, 0), 'outer/panel', reason: 'the same path the hit map records');
      expect(model.update(report), isA<Handled>());
      expect(model.viewportRows, equals(3));
    });

    test('tagRanges keys carry every enclosing scope, the one above the scroll view included', () {
      final model = ScrollViewModel(id: 'panel');
      final content = Column(children: [const SizedBox(width: 6, height: 5), framedField()]);
      final frame = _frame(6, 3)
        ..render(
          Tagged.scope(
            'outer',
            Container(
              child: ScrollView(model: model, child: content),
            ),
          ),
        );

      final metrics = frame.reports.single as ScrollMetrics;
      expect(metrics.tagRanges, {
        'outer/field': (top: 5, height: 5),
        'outer/field/field': (top: 8, height: 2),
      });
    });

    test('ensureVisible takes the full hit path', () {
      final model = ScrollViewModel(id: 'panel');
      final content = Column(children: [const SizedBox(width: 6, height: 5), framedField()]);
      _frame(6, 3)
        ..render(
          Tagged.scope(
            'outer',
            Container(
              child: ScrollView(model: model, child: content),
            ),
          ),
        )
        ..deliverReports(model);

      model.ensureVisible('outer/field/field');
      expect(model.scrollOffset, equals(7), reason: 'the leaf spans [8,10); top+height-viewportRows = 8+2-3');

      model.ensureVisible('field/field');
      expect(model.scrollOffset, equals(7), reason: 'a viewport-relative key is not a hit path: no range, no scroll');
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
      final list = ListViewModel<String, String>(id: 'inner-list', items: _items);

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

      // Both models learn their viewport from the frame's reports: the outer
      // its extent, the list its visible rows. Each declines the other's.
      final frame = _frame(10, 5)
        ..render(ScrollView(model: outer, child: content))
        ..deliverReports(outer)
        ..deliverReports(list);
      return (outer: outer, list: list, hits: frame.hits);
    }

    PointerMsg wheelDownOn(String targetId, Rect rect) => PointerMsg(
      global: Position(rect.x, rect.y),
      action: PointerAction.wheelDown,
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
