import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/golden.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// A fixed-size leaf that fills its rect, so it appears in paint goldens.
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

void main() {
  group('Offstage', () {
    test("lays its child out and reports the child's size as its own", () {
      final offstage = Offstage<String>(child: _Fill('a', 5, 3))
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(Offset.zero);
      expect(offstage.size, const Size(5, 3));
    });

    test('places its child at a real rect, the same as a visible child would get', () {
      final child = _Fill<String>('a', 4, 2);
      final offstage = Offstage<String>(child: child)
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(const Offset(3, 1));
      expect(offstage.child.rect, const Rect(3, 1, 4, 2));
    });

    test('paints nothing, even though its child would otherwise paint', () {
      expect(paintGolden(Offstage<String>(child: _Fill('a', 3, 2)), const Size(3, 2)), isEmpty);
    });

    test('hitTest always misses, including squarely over the child it hides', () {
      final offstage = Offstage<String>(child: SizedBox<String>(width: 4, height: 2))
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(Offset.zero);
      expect(offstage.hitTest(const Offset(1, 1)), isNull);
    });

    test('tagAt always misses, even though the child underneath carries a tag', () {
      final offstage = Offstage<String>(child: SizedBox<String>(width: 4, height: 2)..tag = 'hidden')
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(Offset.zero);
      expect(offstage.tagAt(const Offset(1, 1)), isNull);
    });

    test('hitChildren is empty, so a hit walk that descends it never reaches the child', () {
      final offstage = Offstage<String>(child: SizedBox<String>(width: 2, height: 1))
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(Offset.zero);
      expect(offstage.hitChildren, isEmpty);
    });

    test('visitChildren does not descend into the child it hides', () {
      final offstage = Offstage<String>(child: SizedBox<String>(width: 2, height: 1))
        ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
        ..place(Offset.zero);
      final visited = <RenderNode<String>>[];
      offstage.visitChildren(visited.add);
      expect(visited, isEmpty);
    });
  });

  group('Stack of alternates, one Offstage', () {
    test('sizes to an Offstage child larger than the visible one', () {
      final stack =
          Stack<String>(
              children: [
                Offstage<String>(child: _Fill('big', 8, 5)),
                _Fill('small', 3, 2),
              ],
            )
            ..layout(BoxConstraints.loose(const Size(20, 10)), _ctx)
            ..place(Offset.zero);
      expect(stack.size, const Size(8, 5));
    });

    test('nothing under the Offstage child paints', () {
      expect(
        paintGolden(
          Stack<String>(
            children: [
              _Fill('under', 4, 4),
              Offstage<String>(child: _Fill('hidden', 4, 4)),
            ],
          ),
          const Size(4, 4),
        ),
        ['fillRect(Rect(0, 0, 4, 4), under)'],
      );
    });

    test('a hit over offstage content resolves to whatever is painted beneath it', () {
      final under = _Fill<String>('under', 4, 4);
      final stack =
          Stack<String>(
              children: [
                under,
                Offstage<String>(child: _Fill('hidden', 4, 4)),
              ],
            )
            ..layout(BoxConstraints.tight(const Size(4, 4)), _ctx)
            ..place(Offset.zero);
      // The offstage child paints last (would be on top if shown), but it
      // never intercepts the hit, so the point falls through to `under`.
      expect(stack.hitTest(const Offset(2, 2)), same(under));
    });

    test('a hit over offstage content with nothing beneath returns the stack itself', () {
      final stack = Stack<String>(children: [Offstage<String>(child: SizedBox<String>(width: 2, height: 2))])
        ..layout(BoxConstraints.tight(const Size(8, 5)), _ctx)
        ..place(Offset.zero);
      // (0, 0) sits squarely inside the hidden child's would-be rect.
      expect(stack.hitTest(Offset.zero), same(stack));
      expect(stack.tagAt(Offset.zero), isNull);
    });
  });
}
