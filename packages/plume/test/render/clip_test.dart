import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/fake_wide_measurer.dart';
import '../support/golden.dart';

/// A leaf that fills its own rect, so its paint records as a [FillIntent].
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

/// Lays [node] out tightly at [size], places it, and paints it, returning the
/// recording surface so the caller can read both the intents and their clips.
RecordingSurface<S> _paint<S>(RenderNode<S> node, Size size, {TextMeasurer measurer = const MonospaceMeasurer()}) {
  final surface = RecordingSurface<S>();
  node
    ..layout(BoxConstraints.tight(size), LayoutContext(measurer: measurer))
    ..place(Offset.zero)
    ..paint(surface);
  return surface;
}

List<String> _lines<S>(RecordingSurface<S> surface) => surface.intents.map((intent) => '$intent').toList();

void main() {
  group('clip', () {
    test('a bordered container keeps its rect and carries the clip', () {
      // The container is 6x4 but an ancestor clips it to 4x4. The fill and
      // border are recorded around the ORIGINAL 6x4 rect with the clip carried,
      // so the backend drops the cells outside the clip. It must never re-border
      // the 4x4 clip rect, which would fabricate a false edge at columns 3 where
      // the content was merely cut off.
      final container = Container<String>(
        border: 'edge',
        background: 'fill',
        child: SizedBox<String>(width: 4, height: 2),
      );
      final surface = RecordingSurface<String>()..pushClip(const Rect(0, 0, 4, 4));
      container
        ..layout(BoxConstraints.tight(const Size(6, 4)), const LayoutContext(measurer: MonospaceMeasurer()))
        ..place(Offset.zero)
        ..paint(surface);
      surface.popClip();
      expect(_lines(surface), [
        'fillRect(Rect(0, 0, 6, 4), fill, clip: Rect(0, 0, 4, 4))',
        'drawBorder(Rect(0, 0, 6, 4), edge, clip: Rect(0, 0, 4, 4))',
      ]);
      noOverflow(surface.intents, const Rect(0, 0, 4, 4));
    });

    test('a text taller than its box draws only the in-box rows', () {
      final surface = _paint(Text<String>([const TextRun('a\nb\nc', 'x')]), const Size(3, 2));
      expect(_lines(surface), ['drawText(0, 0, "a", x)', 'drawText(0, 1, "b", x)']);
      noOverflow(surface.intents, const Rect(0, 0, 3, 2));
    });

    test('a positioned child off the right/bottom edge is clipped to the stack', () {
      final stack = Stack<String>(
        children: [
          Positioned<String>(left: 2, top: 1, child: _Fill<String>('a', 6, 6)),
        ],
      );
      final surface = _paint(stack, const Size(5, 4));
      expect(_lines(surface), ['fillRect(Rect(2, 1, 6, 6), a, clip: Rect(2, 1, 3, 3))']);
      noOverflow(surface.intents, const Rect(0, 0, 5, 4));
    });

    test('a positioned child with a negative offset is clipped at the origin', () {
      final stack = Stack<String>(
        children: [
          Positioned<String>(left: -2, top: -1, child: _Fill<String>('a', 4, 4)),
        ],
      );
      final surface = _paint(stack, const Size(5, 4));
      expect(_lines(surface), ['fillRect(Rect(-2, -1, 4, 4), a, clip: Rect(0, 0, 2, 3))']);
      noOverflow(surface.intents, const Rect(0, 0, 5, 4));
    });

    test('an Overlay base taller than the layer no longer paints through the bottom', () {
      // Overlay uses StackFit.expand, the shipped path that reported the
      // overflow bug: a 6-line base clamped to a 4-tall layer draws only 4 rows.
      final overlay = Overlay<String>(
        base: Text<String>([const TextRun('l1\nl2\nl3\nl4\nl5\nl6', 'x')]),
      );
      final surface = _paint(overlay, const Size(4, 4));
      expect(_lines(surface), [
        'drawText(0, 0, "l1", x)',
        'drawText(0, 1, "l2", x)',
        'drawText(0, 2, "l3", x)',
        'drawText(0, 3, "l4", x)',
      ]);
      noOverflow(surface.intents, const Rect(0, 0, 4, 4));
    });

    test('nested ancestors intersect to the effective clip', () {
      final tree = Stack<String>(
        children: [
          Positioned<String>(
            left: 1,
            top: 1,
            width: 4,
            height: 4,
            child: Stack<String>(
              children: [
                Positioned<String>(left: 2, top: 2, child: _Fill<String>('a', 10, 10)),
              ],
            ),
          ),
        ],
      );
      final surface = _paint(tree, const Size(6, 6));
      // clip (3,3,2,2) = frame ∩ (1,1,4,4) outer ∩ (1,1,4,4) inner stack ∩
      // (3,3,10,10) inner positioned.
      expect(_lines(surface), ['fillRect(Rect(3, 3, 10, 10), a, clip: Rect(3, 3, 2, 2))']);
      noOverflow(surface.intents, const Rect(0, 0, 6, 6));
    });

    test('a wide glyph straddling the clip edge is dropped at its boundary', () {
      final tree = Stack<String>(
        children: [
          Positioned<String>(left: 0, top: 0, width: 4, child: Text<String>([const TextRun('字字', 'x')])),
        ],
      );
      final surface = _paint(tree, const Size(3, 1), measurer: const FakeWideMeasurer());
      // The width-2 字 at columns 2-3 would spill past the 3-wide clip, so it is
      // dropped whole and only the first 字 survives.
      expect(_lines(surface), ['drawText(0, 0, "字", x)']);
      noOverflow(surface.intents, const Rect(0, 0, 3, 1), measurer: const FakeWideMeasurer());
    });
  });
}
