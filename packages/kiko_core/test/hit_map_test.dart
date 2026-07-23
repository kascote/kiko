import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

/// A frame over a fresh [width]×[height] buffer.
Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// A bordered box tagged [tag], sized by whatever lays it out.
plume.RenderNode<PaintToken> _box(String label, Object? tag) =>
    Container(border: BorderType.plain, child: Line(label)).build()..tag = tag;

/// The ids of a hit path, outermost first.
List<String> _ids(List<Hit> path) => path.map((h) => h.id).toList();

/// A fixed [w]×[h] leaf tagged [tag], for building Viewport content directly
/// with plume nodes.
plume.RenderNode<PaintToken> _leaf(Object? tag, int w, int h) =>
    plume.SizedBox<PaintToken>(width: w, height: h)..tag = tag;

/// Three stacked rows — 'a', 'b', 'c' — each 3 rows tall and [w] wide, for a
/// 9-row content total.
plume.RenderNode<PaintToken> _threeRows(int w) =>
    plume.Column<PaintToken>(children: [_leaf('a', w, 3), _leaf('b', w, 3), _leaf('c', w, 3)]);

/// A [w]×[h] frame with a plume Viewport of [_threeRows] scrolled [scrollOffset]
/// rows.
Frame _viewportFrame(int w, int h, int scrollOffset) =>
    _frame(w, h)..renderNode(plume.Viewport<PaintToken>(scrollOffset: scrollOffset, child: _threeRows(w)));

/// A region naming a whole row, the shape all three data widgets share.
@immutable
class _Row implements Region {
  const _Row(this.index);

  final int index;

  @override
  bool operator ==(Object other) => other is _Row && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => '_Row($index)';
}

/// A region naming a row's expand indicator — a smaller part painted over the
/// row, for the overlap case.
@immutable
class _Indicator implements Region {
  const _Indicator(this.index);

  final int index;

  @override
  bool operator ==(Object other) => other is _Indicator && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => '_Indicator($index)';
}

/// A leaf tagged with an id that marks a fixed set of regions when it paints,
/// each rect given relative to the leaf's own top-left and translated to
/// absolute — the shape a data widget's viewport takes.
class _MarkingLeaf extends plume.RenderNode<PaintToken> {
  _MarkingLeaf(String id, {required this.w, required this.h, required this.marks}) {
    tag = id;
  }

  final int w;
  final int h;
  final List<(Region, plume.Rect)> marks;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) =>
      constraints.constrain(plume.Size(w, h));

  @override
  void paintSelf(plume.Surface<PaintToken> surface) {
    for (final (region, r) in marks) {
      markRegion(region, plume.Rect(rect.x + r.x, rect.y + r.y, r.width, r.height));
    }
  }
}

void main() {
  group('hitId', () {
    test('resolves a point to the innermost tagged widget', () {
      final inner = _box('i', 'inner');
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner)..tag = 'outer';
      final frame = _frame(6, 5)..renderNode(outer);

      expect(frame.hits.hitId(2, 2), 'inner');
      expect(frame.hits.hitId(0, 0), 'outer');
    });

    test('a later root wins an overlap, matching what the viewer sees', () {
      final frame = _frame(4, 3)
        ..renderNode(_box('U', 'under'))
        ..renderNode(_box('O', 'over'));

      expect(frame.hits.hitId(1, 1), 'over');
    });

    test('returns null off the tree', () {
      final frame = _frame(4, 3)..renderNode(_box('A', 'a'));

      expect(frame.hits.hitId(20, 20), isNull);
    });

    test('resolves a rect placed at the origin', () {
      final frame = _frame(4, 3)..renderNode(_box('A', 'a'));

      expect(frame.hits.hitId(0, 0), 'a');
      expect(frame.hits.rectOf('a'), Rect.create(x: 0, y: 0, width: 4, height: 3));
    });

    test('ignores a non-string tag rather than letting it shadow a string one', () {
      // Plume's `tag` is an opaque Object?. An inner node tagged with something
      // that is not an id must not hide the addressable widget enclosing it.
      final inner = _box('i', 42);
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner)..tag = 'outer';
      final frame = _frame(6, 5)..renderNode(outer);

      expect(frame.hits.hitId(2, 2), 'outer');
    });

    test('an untagged node painted on top does not swallow the widget beneath', () {
      final tagged = _box('T', 'tagged');
      final plain = _box('P', null);
      final frame = _frame(4, 3)
        ..renderNode(tagged)
        ..renderNode(plain);

      expect(frame.hits.hitId(1, 1), 'tagged');
    });
  });

  group('rectOf', () {
    test('is total for a placed tag and null for an unknown one', () {
      final a = _box('A', 'btn-a');
      final b = _box('B', 'btn-b');
      final frame = _frame(6, 3)..renderNode(plume.Row<PaintToken>(children: <plume.RenderNode<PaintToken>>[a, b]));

      expect(frame.hits.rectOf('btn-a'), Rect.create(x: 0, y: 0, width: 3, height: 3));
      expect(frame.hits.rectOf('btn-b'), Rect.create(x: 3, y: 0, width: 3, height: 3));
      expect(frame.hits.rectOf('btn-z'), isNull);
    });

    test('answers for the outer box, not the innermost node covering it', () {
      // The whole point of tag uniqueness: a caller anchoring to the box it
      // tagged gets that box's rect, not a descendant's.
      final inner = _box('i', 'inner');
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner)..tag = 'outer';
      final frame = _frame(6, 5)..renderNode(outer);

      expect(frame.hits.rectOf('outer'), Rect.create(x: 0, y: 0, width: 6, height: 5));
      expect(frame.hits.rectOf('inner'), Rect.create(x: 1, y: 1, width: 4, height: 3));
    });
  });

  group('hitPath', () {
    test('reports tagged ancestors outermost first', () {
      final inner = _box('i', 'inner');
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner)..tag = 'outer';
      final frame = _frame(6, 5)..renderNode(outer);

      expect(_ids(frame.hits.hitPath(2, 2)), ['outer', 'inner']);
    });

    test('its last entry is the id hitId names', () {
      final inner = _box('i', 'inner');
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner)..tag = 'outer';
      final frame = _frame(6, 5)..renderNode(outer);

      final path = frame.hits.hitPath(2, 2);
      expect(path.last.id, frame.hits.hitId(2, 2));
    });

    test('carries the rect of each entry', () {
      final inner = _box('i', 'inner');
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner)..tag = 'outer';
      final frame = _frame(6, 5)..renderNode(outer);

      expect(frame.hits.hitPath(2, 2), [
        Hit('outer', Rect.create(x: 0, y: 0, width: 6, height: 5)),
        Hit('inner', Rect.create(x: 1, y: 1, width: 4, height: 3)),
      ]);
    });

    test('skips untagged nodes along the way', () {
      final inner = _box('i', 'inner');
      final middle = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner);
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: middle)..tag = 'outer';
      final frame = _frame(8, 7)..renderNode(outer);

      expect(_ids(frame.hits.hitPath(3, 3)), ['outer', 'inner']);
    });

    test('is empty off the tree', () {
      final frame = _frame(4, 3)..renderNode(_box('A', 'a'));

      expect(frame.hits.hitPath(20, 20), isEmpty);
    });

    test('never spans roots: it stays inside the topmost tree that hits', () {
      // Two independent trees, both covering the point. The path describes the
      // one on top; the one beneath is not its ancestor.
      final under = _box('U', 'under');
      final overInner = _box('i', 'over-inner');
      final over = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: overInner)
        ..tag = 'over-outer';
      final frame = _frame(6, 5)
        ..renderNode(under)
        ..renderNode(over);

      expect(_ids(frame.hits.hitPath(2, 2)), ['over-outer', 'over-inner']);
    });
  });

  group('tag uniqueness', () {
    test('a duplicate id trips an assert, because rectOf could not choose', () {
      final a = _box('A', 'dup');
      final b = _box('B', 'dup');
      final frame = _frame(6, 3)..renderNode(plume.Row<PaintToken>(children: <plume.RenderNode<PaintToken>>[a, b]));

      expect(() => frame.hits, throwsA(isA<AssertionError>()));
    });

    test('a duplicate across roots trips it too', () {
      final frame = _frame(4, 3)
        ..renderNode(_box('A', 'dup'))
        ..renderNode(_box('B', 'dup'));

      expect(() => frame.hits, throwsA(isA<AssertionError>()));
    });

    test('the same id on two frames is fine — uniqueness is per frame', () {
      final first = _frame(4, 3)..renderNode(_box('A', 'same'));
      final second = _frame(4, 3)..renderNode(_box('B', 'same'));

      expect(first.hits.rectOf('same'), isNotNull);
      expect(second.hits.rectOf('same'), isNotNull);
    });
  });

  group('HitMap.empty', () {
    test('answers null and empty for everything', () {
      const map = HitMap.empty();

      expect(map.hitId(0, 0), isNull);
      expect(map.rectOf('anything'), isNull);
      expect(map.hitPath(0, 0), isEmpty);
    });
  });

  group('Frame.hits', () {
    test('is empty before anything is rendered', () {
      final frame = _frame(4, 3);

      expect(frame.hits.hitId(0, 0), isNull);
      expect(frame.hits.rectOf('a'), isNull);
    });

    test('sees only what has rendered so far, so ordering enforces itself', () {
      final frame = _frame(4, 3);
      expect(frame.hits.rectOf('a'), isNull);

      frame.renderNode(_box('A', 'a'));
      expect(frame.hits.rectOf('a'), isNotNull);
    });

    test('a map handed out earlier does not see a root rendered later', () {
      // The map is frozen: it copies the root list rather than aliasing the
      // frame's, so holding one across a render is safe.
      final frame = _frame(4, 3)..renderNode(_box('A', 'a'));
      final before = frame.hits;

      frame.renderNode(_box('B', 'b'));

      expect(before.rectOf('b'), isNull);
      expect(frame.hits.rectOf('b'), isNotNull);
    });
  });

  group('presence across a clipping viewport (clipsHits)', () {
    test('a row fully scrolled past the top is absent — rectOf is null', () {
      // Content is 9 rows; scrolled fully past a 4-row window.
      final frame = _viewportFrame(6, 4, 9);

      expect(frame.hits.rectOf('a'), isNull);
      expect(frame.hits.rectOf('b'), isNull);
      expect(frame.hits.rectOf('c'), isNull);
    });

    test('a half-visible row keeps its full placement rect, negative top included', () {
      // 'a' (content rows 0-3) is shifted up by 1: absolute rows [-1, 2).
      final frame = _viewportFrame(6, 4, 1);

      expect(frame.hits.rectOf('a'), Rect.create(x: 0, y: -1, width: 6, height: 3));
    });

    test('hitId still resolves a partially visible row inside the window', () {
      final frame = _viewportFrame(6, 4, 1);

      expect(frame.hits.hitId(0, 0), 'a', reason: "a's second content row lands at absolute y=0");
    });

    test('a point outside the viewport rect resolves to nothing, same as any other node', () {
      final frame = _viewportFrame(6, 4, 0);

      expect(frame.hits.hitId(0, 4), isNull, reason: 'one row past the 4-row window');
    });
  });

  group('nested clipsHits viewports', () {
    /// An outer viewport ([outerScroll]) wrapping a 1-row filler, then an
    /// inner 3-row viewport ([innerScroll]) holding a 5-row leaf tagged 'x'.
    Frame nested(int outerScroll, int innerScroll) {
      final content = plume.Column<PaintToken>(
        children: [
          plume.SizedBox<PaintToken>(width: 6, height: 1),
          plume.ConstrainedBox<PaintToken>(
            additionalConstraints: plume.BoxConstraints.tight(const plume.Size(6, 3)),
            child: plume.Viewport<PaintToken>(scrollOffset: innerScroll, child: _leaf('x', 6, 5)),
          ),
        ],
      );
      return _frame(6, 4)..renderNode(plume.Viewport<PaintToken>(scrollOffset: outerScroll, child: content));
    }

    test('both windows aligned leaves the inner tag visible', () {
      final frame = nested(0, 2);

      expect(frame.hits.rectOf('x'), Rect.create(x: 0, y: -1, width: 6, height: 5));
    });

    test('the outer clip composes with the inner one, hiding a tag the inner window alone would show', () {
      // Scrolling the outer viewport moves the whole inner viewport (rect
      // [1, 4) at rest) up and out of the outer's [0, 4) window, even though
      // 'x' stays inside the inner viewport's own local window.
      final frame = nested(4, 2);

      expect(frame.hits.rectOf('x'), isNull);
    });
  });

  group('Offstage', () {
    test('a tagged widget inside an Offstage child is invisible to the frame HitMap', () {
      final node = const Stack(
        children: [
          Offstage(child: Tagged('hidden', SizedBox(width: 4, height: 2))),
          Tagged('visible', SizedBox(width: 2, height: 1)),
        ],
      ).build();
      final frame = _frame(6, 3)..renderNode(node);

      expect(frame.hits.rectOf('hidden'), isNull);
      expect(frame.hits.hitId(0, 0), 'visible', reason: 'the visible sibling still resolves where it overlaps');
      expect(frame.hits.hitId(3, 1), isNull, reason: 'a point covered only by offstage content hits nothing');
    });
  });

  group('Hit', () {
    test('compares by id and rect', () {
      final rect = Rect.create(x: 0, y: 0, width: 2, height: 2);

      expect(Hit('a', rect), Hit('a', rect));
      expect(Hit('a', rect).hashCode, Hit('a', rect).hashCode);
      expect(Hit('a', rect), isNot(Hit('b', rect)));
    });
  });

  group('regionAt', () {
    // A 6×5 list body: item 0 two rows tall (y 0-1), a separator row (y 2),
    // item 1 two rows tall (y 3-4). Separator and any tail stay unmarked.
    Frame listFrame() => _frame(6, 5)
      ..renderNode(
        _MarkingLeaf(
          'list',
          w: 6,
          h: 5,
          marks: const [
            (_Row(0), plume.Rect(0, 0, 6, 2)),
            (_Row(1), plume.Rect(0, 3, 6, 2)),
          ],
        ),
      );

    test('resolves a point on a row to that row', () {
      final hits = listFrame().hits;

      expect(hits.regionAt('list', 0, 0), const _Row(0));
      expect(hits.regionAt('list', 0, 3), const _Row(1));
    });

    test('every line of a multi-line row resolves to the same row', () {
      // The bug the arc exists to fix: a second painted line must not land on
      // the next item. Both lines of item 0 are item 0; both of item 1 are 1.
      final hits = listFrame().hits;

      expect(hits.regionAt('list', 5, 0), const _Row(0));
      expect(hits.regionAt('list', 5, 1), const _Row(0), reason: "item 0's second line");
      expect(hits.regionAt('list', 5, 3), const _Row(1));
      expect(hits.regionAt('list', 5, 4), const _Row(1), reason: "item 1's second line");
    });

    test('a point on an unmarked separator or tail resolves to nothing', () {
      final hits = listFrame().hits;

      expect(hits.regionAt('list', 3, 2), isNull, reason: 'the separator belongs to nobody');
    });

    test('a point off the widget resolves to null', () {
      final hits = listFrame().hits;

      expect(hits.regionAt('list', 20, 20), isNull);
    });

    test('an unknown id resolves to null', () {
      final hits = listFrame().hits;

      expect(hits.regionAt('nope', 0, 0), isNull);
    });

    test('a smaller part painted over a row wins the overlap', () {
      // A row, then a 2-cell indicator marked over its left edge (paint order:
      // coarse then fine). A point on the indicator resolves to it; a point
      // elsewhere on the row resolves to the row.
      final frame = _frame(6, 1)
        ..renderNode(
          _MarkingLeaf(
            'tree',
            w: 6,
            h: 1,
            marks: const [
              (_Row(0), plume.Rect(0, 0, 6, 1)),
              (_Indicator(0), plume.Rect(0, 0, 2, 1)),
            ],
          ),
        );
      final hits = frame.hits;

      expect(hits.regionAt('tree', 0, 0), const _Indicator(0), reason: 'the part on top answers the overlap');
      expect(hits.regionAt('tree', 4, 0), const _Row(0), reason: 'off the indicator, the row answers');
    });

    test("a nested widget's regions never surface on the enclosing widget", () {
      // An inner marking leaf tagged 'inner' inside an outer tagged 'outer'
      // that marks nothing where the inner does.
      final inner = _MarkingLeaf('inner', w: 4, h: 3, marks: const [(_Row(0), plume.Rect(0, 0, 4, 3))]);
      final outer = plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: inner)..tag = 'outer';
      final hits = (_frame(6, 5)..renderNode(outer)).hits;

      expect(hits.regionAt('inner', 2, 2), const _Row(0), reason: 'the inner widget resolves its own region');
      expect(hits.regionAt('outer', 2, 2), isNull, reason: "the inner's region does not leak to the outer");
    });

    test('a widget that marks the same key twice trips the uniqueness assert', () {
      final frame = _frame(6, 2)
        ..renderNode(
          _MarkingLeaf(
            'dup',
            w: 6,
            h: 2,
            marks: const [
              (_Row(0), plume.Rect(0, 0, 6, 1)),
              (_Row(0), plume.Rect(0, 1, 6, 1)),
            ],
          ),
        );

      expect(() => frame.hits, throwsA(isA<AssertionError>()));
    });

    test('a scrolled-off widget answers null even for a marked part', () {
      // The row leaf is 9 tall inside a 4-row viewport scrolled fully past it,
      // so the tag is absent from the map and its regions with it.
      final leaf = _MarkingLeaf('list', w: 6, h: 9, marks: const [(_Row(0), plume.Rect(0, 0, 6, 2))]);
      final frame = _frame(6, 4)..renderNode(plume.Viewport<PaintToken>(scrollOffset: 9, child: leaf));

      expect(frame.hits.regionAt('list', 0, 0), isNull);
    });
  });
}
