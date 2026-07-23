import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _context = LayoutContext(measurer: MonospaceMeasurer());

/// A minimal multi-child container used to exercise the base protocol: it lays
/// each child out loosely, parks it at a fixed offset, and fills its own
/// constraints.
class _Group<T> extends RenderNode<T> {
  _Group(this._children, this._offsets);

  final List<RenderNode<T>> _children;
  final List<Offset> _offsets;

  @override
  List<RenderNode<T>> get children => _children;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    for (var i = 0; i < _children.length; i++) {
      _children[i].layout(constraints.loosen(), context);
      _children[i].offset = _offsets[i];
    }
    return constraints.biggest;
  }
}

/// A leaf that fills its own rect, so its paint records as a [FillIntent].
class _Fill<T> extends RenderNode<T> {
  _Fill(this.token, this.w, this.h);

  final T token;
  final int w;
  final int h;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.constrain(Size(w, h));

  @override
  void paintSelf(Surface<T> surface) => surface.fillRect(rect, token);
}

/// A leaf that marks a caller-chosen set of regions when it paints, so its
/// [RenderNode.markedRegions] can be inspected. [marker] receives the leaf's
/// placed [rect] so a test can mark absolute-cell regions; set [skip] to make
/// `paintSelf` return before it marks anything, exercising an early-out paint.
class _Marker<T> extends RenderNode<T> {
  _Marker(this.marker, {this.w = 4, this.h = 2});

  List<MarkedRegion> Function(Rect rect) marker;
  final int w;
  final int h;
  bool skip = false;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.constrain(Size(w, h));

  @override
  void paintSelf(Surface<T> surface) {
    if (skip) return;
    for (final region in marker(rect)) {
      markRegion(region.key, region.rect);
    }
  }
}

void main() {
  group('RenderNode', () {
    test('a leaf reports its size, clamped to constraints', () {
      final box = SizedBox<Object>(width: 4, height: 2);
      expect(box.layout(BoxConstraints.loose(const Size(10, 10)), _context), const Size(4, 2));
      expect(box.size, const Size(4, 2));
    });

    test('a leaf is clamped when it exceeds the maximum', () {
      final box = SizedBox<Object>(width: 40, height: 2);
      expect(box.layout(BoxConstraints.loose(const Size(10, 10)), _context), const Size(10, 2));
    });

    test('layout asserts against un-normalized constraints', () {
      final box = SizedBox<Object>(width: 4, height: 2);
      expect(
        () => box.layout(const BoxConstraints(minW: 5, maxW: 3), _context),
        throwsA(isA<AssertionError>()),
      );
    });

    test('place fixes absolute rects from parent offsets', () {
      final a = SizedBox<Object>(width: 2, height: 1);
      final b = SizedBox<Object>(width: 3, height: 2);
      final group = _Group<Object>([a, b], const [Offset(1, 1), Offset(4, 0)])
        ..layout(BoxConstraints.tight(const Size(10, 5)), _context)
        ..place(Offset.zero);

      expect(group.rect, const Rect(0, 0, 10, 5));
      expect(a.rect, const Rect(1, 1, 2, 1));
      expect(b.rect, const Rect(4, 0, 3, 2));
    });

    test('paint clips a child that overflows its parent', () {
      final leaf = _Fill<String>('x', 4, 4);
      final group = _Group<String>([leaf], const [Offset(2, 2)])
        ..layout(BoxConstraints.tight(const Size(4, 4)), _context)
        ..place(Offset.zero);
      final surface = RecordingSurface<String>();
      group.paint(surface);
      // The leaf's rect (2,2,4,4) spills past the 4x4 group; the paint walk
      // carries the effective clip (2,2,2,2) so the backend trims it.
      expect(surface.intents, const [FillIntent<String>(Rect(2, 2, 4, 4), 'x', clip: Rect(2, 2, 2, 2))]);
    });

    test('paint carries no clip for a child fully inside its parent', () {
      final leaf = _Fill<String>('x', 2, 2);
      final group = _Group<String>([leaf], const [Offset(1, 1)])
        ..layout(BoxConstraints.tight(const Size(6, 6)), _context)
        ..place(Offset.zero);
      final surface = RecordingSurface<String>();
      group.paint(surface);
      expect(surface.intents, const [FillIntent<String>(Rect(1, 1, 2, 2), 'x')]);
    });

    test('nested groups accumulate offsets down the tree', () {
      final leaf = SizedBox<Object>(width: 1, height: 1);
      final inner = _Group<Object>([leaf], const [Offset(2, 3)]);
      final outer = _Group<Object>([inner], const [Offset(5, 1)])
        ..layout(BoxConstraints.tight(const Size(20, 20)), _context)
        ..place(Offset.zero);

      expect(outer.rect, const Rect(0, 0, 20, 20));
      // leaf global = outer(5,1) + inner(2,3) = (7,4)
      expect(leaf.rect, const Rect(7, 4, 1, 1));
    });

    group('hitTest', () {
      late _Group<Object> group;
      late SizedBox<Object> a;
      late SizedBox<Object> b;

      setUp(() {
        a = SizedBox<Object>(width: 2, height: 2);
        b = SizedBox<Object>(width: 2, height: 2);
        group = _Group<Object>([a, b], const [Offset.zero, Offset(4, 0)])
          ..layout(BoxConstraints.tight(const Size(10, 5)), _context)
          ..place(Offset.zero);
      });

      test('returns the child under the point', () {
        expect(group.hitTest(const Offset(1, 1)), same(a));
        expect(group.hitTest(const Offset(5, 1)), same(b));
      });

      test('returns the container when inside but off every child', () {
        expect(group.hitTest(const Offset(3, 4)), same(group));
      });

      test('returns null outside the tree', () {
        expect(group.hitTest(const Offset(20, 20)), isNull);
      });
    });

    test('hitTest returns the top-most of overlapping children', () {
      final under = SizedBox<Object>(width: 4, height: 4);
      final over = SizedBox<Object>(width: 4, height: 4);
      // Both at the origin; `over` is later in paint order, so it wins.
      final group = _Group<Object>([under, over], const [Offset.zero, Offset.zero])
        ..layout(BoxConstraints.tight(const Size(4, 4)), _context)
        ..place(Offset.zero);

      expect(group.hitTest(const Offset(1, 1)), same(over));
    });

    group('marked regions', () {
      RecordingSurface<String> paint(RenderNode<String> node) {
        final surface = RecordingSurface<String>();
        node.paint(surface);
        return surface;
      }

      test('a paint that marks records the (key, rect) pairs it drew', () {
        final leaf =
            _Marker<String>(
                (rect) => const [
                  MarkedRegion('row-0', Rect(0, 0, 4, 1)),
                  MarkedRegion('row-1', Rect(0, 1, 4, 1)),
                ],
              )
              ..layout(BoxConstraints.tight(const Size(4, 2)), _context)
              ..place(Offset.zero);
        paint(leaf);

        expect(leaf.markedRegions, const [
          MarkedRegion('row-0', Rect(0, 0, 4, 1)),
          MarkedRegion('row-1', Rect(0, 1, 4, 1)),
        ]);
      });

      test('marks are in absolute cells, following the node down the tree', () {
        // The leaf marks its own placed rect, so the group offset must show
        // through — the mark is in the same absolute space paint draws in.
        final leaf = _Marker<String>((rect) => [MarkedRegion('self', rect)]);
        final group = _Group<String>([leaf], const [Offset(3, 2)])
          ..layout(BoxConstraints.tight(const Size(10, 6)), _context)
          ..place(Offset.zero);
        paint(group);

        expect(leaf.rect, const Rect(3, 2, 4, 2));
        expect(leaf.markedRegions, const [MarkedRegion('self', Rect(3, 2, 4, 2))]);
      });

      test('a node that never marks holds an empty store', () {
        final leaf = _Fill<String>('x', 2, 2)
          ..layout(BoxConstraints.tight(const Size(2, 2)), _context)
          ..place(Offset.zero);
        paint(leaf);

        expect(leaf.markedRegions, isEmpty);
      });

      test('a repaint that marks nothing clears the prior frame marks', () {
        final leaf = _Marker<String>((rect) => [MarkedRegion('self', rect)])
          ..layout(BoxConstraints.tight(const Size(4, 2)), _context)
          ..place(Offset.zero);
        paint(leaf);
        expect(leaf.markedRegions, isNotEmpty);

        // Next frame the node paints no marked part at all.
        leaf.marker = (rect) => const [];
        paint(leaf);
        expect(leaf.markedRegions, isEmpty);
      });

      test('the paint traversal clears marks even when paintSelf returns early', () {
        final leaf = _Marker<String>((rect) => [MarkedRegion('self', rect)])
          ..layout(BoxConstraints.tight(const Size(4, 2)), _context)
          ..place(Offset.zero);
        paint(leaf);
        expect(leaf.markedRegions, isNotEmpty);

        // paintSelf bails before its marking code runs; the clear still happens
        // because paint() — the traversal — does it, not the widget.
        leaf.skip = true;
        paint(leaf);
        expect(leaf.markedRegions, isEmpty);
      });

      test('a marking descendant is cleared and re-marked through a full traversal', () {
        final leaf = _Marker<String>((rect) => [MarkedRegion('self', rect)]);
        final group = _Group<String>([leaf], const [Offset(1, 1)])
          ..layout(BoxConstraints.tight(const Size(8, 8)), _context)
          ..place(Offset.zero);
        paint(group);
        expect(leaf.markedRegions, const [MarkedRegion('self', Rect(1, 1, 4, 2))]);

        // Repainting the same tree is idempotent: the descendant's store holds
        // one entry, not two.
        paint(group);
        expect(leaf.markedRegions, const [MarkedRegion('self', Rect(1, 1, 4, 2))]);
      });
    });
  });

  group('MarkedRegion', () {
    test('has structural equality over key and rect', () {
      expect(const MarkedRegion('row-0', Rect(0, 0, 4, 1)), const MarkedRegion('row-0', Rect(0, 0, 4, 1)));
      expect(
        const MarkedRegion('row-0', Rect(0, 0, 4, 1)),
        isNot(const MarkedRegion('row-1', Rect(0, 0, 4, 1))),
      );
      expect(
        const MarkedRegion('row-0', Rect(0, 0, 4, 1)),
        isNot(const MarkedRegion('row-0', Rect(0, 1, 4, 1))),
      );
    });
  });
}
