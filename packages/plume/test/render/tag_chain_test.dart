import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _context = LayoutContext(measurer: MonospaceMeasurer());

/// A leaf that copies the surface's tag chain while it paints, so a test can
/// read what the node saw.
class _Probe<T> extends RenderNode<T> {
  List<Object>? seen;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.constrain(const Size(2, 1));

  @override
  void paintSelf(Surface<T> surface) => seen = surface.tagChain;
}

RecordingSurface<String> _paint(RenderNode<String> node) {
  final surface = RecordingSurface<String>();
  node
    ..layout(BoxConstraints.tight(const Size(6, 4)), _context)
    ..place(Offset.zero)
    ..paint(surface);
  return surface;
}

void main() {
  group('Surface.tagChain', () {
    test('is empty on a fresh surface', () {
      expect(RecordingSurface<String>().tagChain, isEmpty);
    });

    test("inside paintSelf it holds the ancestors' tags then the node's own, outermost first", () {
      final probe = _Probe<String>()..tag = 'leaf';
      final inner = Column<String>(children: [probe])..tag = 'inner';
      final outer = Column<String>(children: [inner])..tag = 'outer';

      _paint(outer);

      expect(probe.seen, ['outer', 'inner', 'leaf']);
    });

    test('a null tag adds nothing', () {
      final probe = _Probe<String>();
      final anonymous = Column<String>(children: [probe]);
      final outer = Column<String>(children: [anonymous])..tag = 'outer';

      _paint(outer);

      expect(probe.seen, ['outer']);
    });

    test('is empty again after paint returns', () {
      final probe = _Probe<String>()..tag = 'leaf';
      final outer = Column<String>(children: [probe])..tag = 'outer';

      final surface = _paint(outer);

      expect(surface.tagChain, isEmpty);
    });

    test("a sibling painted later does not see the earlier sibling's tag", () {
      final first = _Probe<String>()..tag = 'first';
      final second = _Probe<String>()..tag = 'second';
      final outer = Column<String>(children: [first, second])..tag = 'outer';

      _paint(outer);

      expect(first.seen, ['outer', 'first']);
      expect(second.seen, ['outer', 'second']);
    });

    test('pushNode without a tag stands in for an untagged ancestor', () {
      final surface = RecordingSurface<String>()..pushNode(const Rect(0, 0, 6, 4));
      expect(surface.tagChain, isEmpty);
      surface.pushNode(const Rect(0, 0, 3, 2), 'x');
      expect(surface.tagChain, ['x']);
      surface.popNode();
      expect(surface.tagChain, isEmpty);
      surface.popNode();
    });

    test('tagChain is a copy: mutating it leaves the surface untouched', () {
      final surface = RecordingSurface<String>()..pushNode(const Rect(0, 0, 6, 4), 'x');
      surface.tagChain.add('y');
      expect(surface.tagChain, ['x']);
      surface.popNode();
    });
  });
}
