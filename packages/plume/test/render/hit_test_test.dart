import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// Lays [node] out tightly at [size] and fixes its absolute rects.
void _layout(RenderNode<String> node, Size size) {
  node
    ..layout(BoxConstraints.tight(size), _ctx)
    ..place(Offset.zero);
}

void main() {
  group('hitTest through a Stack', () {
    test('returns the top-most of overlapping children', () {
      final under = SizedBox<String>(width: 6, height: 4);
      final over = SizedBox<String>(width: 6, height: 4);
      // Both fill the same rect; `over` paints later, so it wins the hit.
      final stack = Stack<String>(fit: StackFit.expand, children: [under, over]);
      _layout(stack, const Size(6, 4));
      expect(stack.hitTest(const Offset(2, 2)), same(over));
    });

    test('returns a Positioned child at its anchored rect', () {
      final filler = SizedBox<String>(width: 10, height: 6);
      final anchored = SizedBox<String>(width: 2, height: 2);
      final stack = Stack<String>(
        children: [
          filler,
          Positioned<String>(left: 5, top: 3, child: anchored),
        ],
      );
      _layout(stack, const Size(10, 6));
      expect(stack.hitTest(const Offset(5, 3)), same(anchored));
      // Just outside the anchored rect falls back to the filling child.
      expect(stack.hitTest(Offset.zero), same(filler));
    });

    test('boundary cells: the right and bottom edges are exclusive', () {
      final box = SizedBox<String>(width: 3, height: 2);
      final stack = Stack<String>(children: [box]);
      _layout(stack, const Size(3, 2));
      // The rect covers columns 0..2 and rows 0..1.
      expect(stack.hitTest(const Offset(2, 1)), same(box), reason: 'last cell inside');
      expect(stack.hitTest(const Offset(3, 1)), isNull, reason: 'one past the right edge');
      expect(stack.hitTest(const Offset(2, 2)), isNull, reason: 'one past the bottom edge');
    });

    test('a point inside the stack but off every child returns the stack', () {
      final child = SizedBox<String>(width: 2, height: 2);
      final stack = Stack<String>(children: [Positioned<String>(left: 0, top: 0, child: child)]);
      _layout(stack, const Size(8, 5));
      expect(stack.hitTest(const Offset(6, 4)), same(stack));
    });
  });

  group('hitTest through nested offsets', () {
    test('offsets accumulate down the tree', () {
      final leaf = SizedBox<String>(width: 2, height: 2);
      final stack = Stack<String>(
        children: [
          Positioned<String>(
            left: 3,
            top: 2,
            child: Padding<String>(insets: const EdgeInsets.all(1), child: leaf),
          ),
        ],
      );
      _layout(stack, const Size(20, 20));
      // Positioned at (3, 2); the padding insets the leaf by one more.
      expect(leaf.rect, const Rect(4, 3, 2, 2));
      expect(stack.hitTest(const Offset(5, 4)), same(leaf));
      // The padding ring around the leaf hits the padding, not the leaf.
      expect(stack.hitTest(const Offset(3, 2)), isNot(same(leaf)));
    });
  });

  group('hitTest through an Overlay', () {
    late Overlay<String> overlay;
    late SizedBox<String> base;
    late SizedBox<String> modal;

    setUp(() {
      base = SizedBox<String>(width: 20, height: 10);
      modal = SizedBox<String>(width: 4, height: 2);
      overlay = Overlay<String>(
        base: base,
        overlays: [Positioned<String>(left: 8, top: 4, child: modal)],
      );
      _layout(overlay, const Size(20, 10));
    });

    test('a click on the overlay hits the overlay, above the base', () {
      expect(overlay.hitTest(const Offset(9, 5)), same(modal));
    });

    test('a click off the overlay falls through to the base', () {
      expect(overlay.hitTest(Offset.zero), same(base));
    });

    test('a point outside the whole scene returns null', () {
      expect(overlay.hitTest(const Offset(50, 50)), isNull);
    });
  });
}
