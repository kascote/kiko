import 'package:plume/plume.dart';
import 'package:test/test.dart';

/// A minimal multi-child container used to exercise the base protocol: it lays
/// each child out loosely, parks it at a fixed offset, and fills its own
/// constraints.
class _Group<S> extends RenderNode<S> {
  _Group(this._children, this._offsets);

  final List<RenderNode<S>> _children;
  final List<Offset> _offsets;

  @override
  List<RenderNode<S>> get children => _children;

  @override
  Size performLayout(BoxConstraints constraints) {
    for (var i = 0; i < _children.length; i++) {
      _children[i].layout(constraints.loosen());
      _children[i].offset = _offsets[i];
    }
    return constraints.biggest;
  }
}

void main() {
  group('RenderNode', () {
    test('a leaf reports its size, clamped to constraints', () {
      final box = SizedBox<Object>(width: 4, height: 2);
      expect(box.layout(BoxConstraints.loose(const Size(10, 10))), const Size(4, 2));
      expect(box.size, const Size(4, 2));
    });

    test('a leaf is clamped when it exceeds the maximum', () {
      final box = SizedBox<Object>(width: 40, height: 2);
      expect(box.layout(BoxConstraints.loose(const Size(10, 10))), const Size(10, 2));
    });

    test('place fixes absolute rects from parent offsets', () {
      final a = SizedBox<Object>(width: 2, height: 1);
      final b = SizedBox<Object>(width: 3, height: 2);
      final group = _Group<Object>([a, b], const [Offset(1, 1), Offset(4, 0)])
        ..layout(BoxConstraints.tight(const Size(10, 5)))
        ..place(Offset.zero);

      expect(group.rect, const Rect(0, 0, 10, 5));
      expect(a.rect, const Rect(1, 1, 2, 1));
      expect(b.rect, const Rect(4, 0, 3, 2));
    });

    test('nested groups accumulate offsets down the tree', () {
      final leaf = SizedBox<Object>(width: 1, height: 1);
      final inner = _Group<Object>([leaf], const [Offset(2, 3)]);
      final outer = _Group<Object>([inner], const [Offset(5, 1)])
        ..layout(BoxConstraints.tight(const Size(20, 20)))
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
          ..layout(BoxConstraints.tight(const Size(10, 5)))
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
        ..layout(BoxConstraints.tight(const Size(4, 4)))
        ..place(Offset.zero);

      expect(group.hitTest(const Offset(1, 1)), same(over));
    });
  });
}
