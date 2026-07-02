import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// Lays [node] out tightly at [size], places it, paints it under an ancestor
/// [clip], and returns the recorded intents as strings.
List<String> _paintClipped<S>(RenderNode<S> node, Size size, Rect clip) {
  final surface = RecordingSurface<S>()..pushClip(clip);
  node
    ..layout(BoxConstraints.tight(size), _ctx)
    ..place(Offset.zero)
    ..paint(surface);
  surface.popClip();
  return surface.intents.map((intent) => '$intent').toList();
}

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
      expect(_paintClipped(container, const Size(6, 4), const Rect(0, 0, 4, 4)), [
        'fillRect(Rect(0, 0, 6, 4), fill, clip: Rect(0, 0, 4, 4))',
        'drawBorder(Rect(0, 0, 6, 4), edge, clip: Rect(0, 0, 4, 4))',
      ]);
    });
  });
}
