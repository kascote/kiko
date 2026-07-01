import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/golden.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// A fixed-size leaf that fills its rect, so it appears in paint goldens.
class _Fill<S> extends RenderNode<S> {
  _Fill(this.style, this.w, this.h);

  final S style;
  final int w;
  final int h;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.constrain(Size(w, h));

  @override
  void paintSelf(Surface<S> surface) => surface.fillRect(rect, style);
}

void main() {
  group('Stack', () {
    test('sizes to its largest non-positioned child', () {
      final stack = Stack<String>(children: [_Fill('a', 3, 2), _Fill('b', 5, 1)])
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(Offset.zero);
      expect(stack.size, const Size(5, 2));
    });

    test('aligns non-positioned children within the resolved size', () {
      final big = _Fill<String>('b', 6, 3);
      final small = _Fill<String>('a', 2, 1);
      Stack<String>(alignment: Alignment.center, children: [big, small])
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(Offset.zero);
      expect(big.rect, const Rect(0, 0, 6, 3));
      // small (2x1) centered in the 6x3 stack: x = (6-2)/2, y = (3-1)/2.
      expect(small.rect, const Rect(2, 1, 2, 1));
    });

    test('expand fit forces non-positioned children to fill the stack', () {
      final child = _Fill<String>('a', 2, 1);
      Stack<String>(fit: StackFit.expand, children: [child])
        ..layout(BoxConstraints.tight(const Size(8, 4)), _ctx)
        ..place(Offset.zero);
      expect(child.rect, const Rect(0, 0, 8, 4));
    });

    test('fills the incoming constraints when every child is positioned', () {
      final stack = Stack<String>(children: [Positioned<String>(left: 1, top: 1, child: SizedBox<String>(width: 2))])
        ..layout(BoxConstraints.tight(const Size(9, 5)), _ctx)
        ..place(Offset.zero);
      expect(stack.size, const Size(9, 5));
    });

    test('asserts when every child is positioned under an unbounded axis', () {
      final stack = Stack<String>(children: [Positioned<String>(left: 1, top: 1, child: SizedBox<String>(width: 2))]);
      expect(
        () => stack.layout(const BoxConstraints(maxH: 5), _ctx),
        throwsA(isA<AssertionError>()),
      );
    });

    test('paints children front-to-back in list order', () {
      expect(
        paintGolden(
          Stack<String>(children: [_Fill('under', 4, 4), _Fill('over', 2, 2)]),
          const Size(4, 4),
        ),
        [
          'fillRect(Rect(0, 0, 4, 4), under)',
          'fillRect(Rect(0, 0, 2, 2), over)',
        ],
      );
    });

    test('paints overlapping children so the later one lands on top', () {
      expect(
        paintGolden(
          Stack<String>(
            alignment: Alignment.center,
            children: [_Fill('back', 6, 4), _Fill('front', 2, 2)],
          ),
          const Size(6, 4),
        ),
        [
          'fillRect(Rect(0, 0, 6, 4), back)',
          'fillRect(Rect(2, 1, 2, 2), front)',
        ],
      );
    });
  });

  group('Positioned', () {
    test('left and top pin the child to those edges', () {
      final child = SizedBox<String>(width: 2, height: 1);
      final stack = Stack<String>(children: [Positioned<String>(left: 3, top: 2, child: child)])
        ..layout(BoxConstraints.tight(const Size(10, 6)), _ctx)
        ..place(Offset.zero);
      expect(stack.size, const Size(10, 6));
      expect(child.rect, const Rect(3, 2, 2, 1));
    });

    test('right and bottom pin the child against the far edges', () {
      final child = SizedBox<String>(width: 2, height: 1);
      Stack<String>(children: [Positioned<String>(right: 1, bottom: 1, child: child)])
        ..layout(BoxConstraints.tight(const Size(10, 6)), _ctx)
        ..place(Offset.zero);
      // x = 10 - 1 - 2, y = 6 - 1 - 1.
      expect(child.rect, const Rect(7, 4, 2, 1));
    });

    test('left and right together stretch the child across the stack', () {
      final child = SizedBox<String>(width: 2, height: 1);
      Stack<String>(children: [Positioned<String>(left: 2, right: 3, child: child)])
        ..layout(BoxConstraints.tight(const Size(10, 6)), _ctx)
        ..place(Offset.zero);
      // width = 10 - 2 - 3 = 5.
      expect(child.rect, const Rect(2, 0, 5, 1));
    });

    test('a positioned child does not affect the stack size', () {
      final stack =
          Stack<String>(
              children: [
                _Fill('a', 4, 2),
                Positioned<String>(left: 20, top: 20, child: SizedBox<String>(width: 5, height: 5)),
              ],
            )
            ..layout(BoxConstraints.loose(const Size(40, 40)), _ctx)
            ..place(Offset.zero);
      expect(stack.size, const Size(4, 2));
    });
  });
}
