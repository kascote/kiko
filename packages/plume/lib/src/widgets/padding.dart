import '../geometry/box_constraints.dart';
import '../geometry/edge_insets.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import '../render/single_child_node.dart';

/// Insets its child by [insets], reporting a size that includes the padding.
class Padding<S> extends SingleChildNode<S> {
  /// Pads [child] by [insets].
  Padding({required this.insets, required RenderNode<S> child}) : super(child);

  /// The cell insets around the child.
  final EdgeInsets insets;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final childSize = child.layout(constraints.deflate(insets.horizontal, insets.vertical), context);
    child.offset = Offset(insets.left, insets.top);
    return constraints.constrain(Size(childSize.w + insets.horizontal, childSize.h + insets.vertical));
  }
}
