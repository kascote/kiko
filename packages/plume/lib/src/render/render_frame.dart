import '../geometry/box_constraints.dart';
import '../geometry/rect.dart';
import '../painting/surface.dart';
import '../painting/text_measurer.dart';
import 'layout_context.dart';
import 'render_node.dart';

/// Drives [node] through one frame into [surface] — the four-pass ritual in one
/// call.
///
/// It lays [node] out tight to [area]'s size (measuring text with [measurer]),
/// places its top-left at [area]'s origin, and paints it. The root's own rect is
/// [area], so the paint-side clip keeps every draw inside the frame.
///
/// Hit testing is left to the caller (`node.hitTest(point)`): it runs per input
/// event, not per frame.
void renderFrame<T>(
  RenderNode<T> node,
  Rect area,
  Surface<T> surface, {
  TextMeasurer measurer = const MonospaceMeasurer(),
}) {
  node
    ..layout(BoxConstraints.tight(area.size), LayoutContext(measurer: measurer))
    ..place(area.topLeft)
    ..paint(surface);
}
