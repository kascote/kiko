import '../geometry/box_constraints.dart';
import '../geometry/size.dart';
import '../render/render_node.dart';

/// A leaf that occupies a fixed box and draws nothing.
///
/// Handy as a spacer or a minimum-size placeholder. Its size is the requested
/// [width] × [height] clamped to the incoming constraints.
class SizedBox<S> extends RenderNode<S> {
  /// Creates a box [width] cells wide and [height] cells tall.
  SizedBox({this.width = 0, this.height = 0});

  /// The requested width in cells, before constraints are applied.
  final int width;

  /// The requested height in cells, before constraints are applied.
  final int height;

  @override
  Size performLayout(BoxConstraints constraints) => constraints.constrain(Size(width, height));
}
