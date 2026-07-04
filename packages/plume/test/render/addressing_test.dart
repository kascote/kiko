import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// A tagged box wrapping [child] with one cell of padding on every side.
Padding<String> _tagged(String tag, RenderNode<String> child) =>
    Padding<String>(insets: const EdgeInsets.all(1), child: child)..tag = tag;

void main() {
  group('tag', () {
    test('defaults to null', () {
      expect(SizedBox<String>(width: 1, height: 1).tag, isNull);
    });
  });

  group('tagAt', () {
    // outer[0..6, 0..5] wraps inner[1..5, 1..4] wraps a tagged leaf[2..4, 2..3].
    late Padding<String> outer;
    late SizedBox<String> leaf;
    setUp(() {
      leaf = SizedBox<String>(width: 2, height: 1)..tag = 'leaf';
      outer = _tagged('outer', _tagged('inner', leaf))
        ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
        ..place(Offset.zero);
    });

    test('returns the innermost tag under the point', () {
      expect(outer.tagAt(const Offset(2, 2)), 'leaf');
    });

    test('falls back to the enclosing tag between inner nodes', () {
      // (1, 1) sits inside inner but outside the leaf.
      expect(outer.tagAt(const Offset(1, 1)), 'inner');
    });

    test('returns the outermost tag when only it encloses the point', () {
      expect(outer.tagAt(Offset.zero), 'outer');
    });

    test('returns null when the point is outside the tree', () {
      expect(outer.tagAt(const Offset(19, 19)), isNull);
    });

    test('returns an enclosing tag even when the leaf under the point is untagged', () {
      // The node physically at the point is the untagged SizedBox, but the
      // tagged box around it is what a hit should resolve to.
      final box = _tagged('box', SizedBox<String>(width: 4, height: 2))
        ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
        ..place(Offset.zero);
      expect(box.hitTest(const Offset(2, 2)), isA<SizedBox<String>>());
      expect(box.tagAt(const Offset(2, 2)), 'box');
    });

    test('resolves the front-most tag in an overlap', () {
      final back = SizedBox<String>(width: 4, height: 2)..tag = 'back';
      final front = SizedBox<String>(width: 4, height: 2)..tag = 'front';
      final stack =
          Stack<String>(
              children: <RenderNode<String>>[
                Positioned<String>(left: 0, top: 0, child: back),
                Positioned<String>(left: 0, top: 0, child: front),
              ],
            )
            ..layout(BoxConstraints.tight(const Size(4, 2)), _ctx)
            ..place(Offset.zero);
      // The last child paints on top, so it wins the tag too.
      expect(stack.tagAt(const Offset(1, 1)), 'front');
    });
  });

  group('nodeForTag', () {
    test('finds the node carrying the tag and null otherwise', () {
      final leaf = SizedBox<String>(width: 2, height: 1)..tag = 'leaf';
      final outer = _tagged('outer', leaf)
        ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
        ..place(Offset.zero);

      expect(outer.nodeForTag('leaf'), same(leaf));
      expect(outer.nodeForTag('leaf')?.rect, const Rect(1, 1, 2, 1));
      expect(outer.nodeForTag('outer'), same(outer));
      expect(outer.nodeForTag('missing'), isNull);
    });
  });
}
