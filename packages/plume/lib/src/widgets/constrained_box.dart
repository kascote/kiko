import '../geometry/box_constraints.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import '../render/single_child_node.dart';

/// Applies [additionalConstraints] to its child on top of the incoming ones.
///
/// The extra constraints are clamped into what the parent allows, so this can
/// tighten a child but never escape the parent's bounds.
class ConstrainedBox<T> extends SingleChildNode<T> {
  /// Constrains [child] further with [additionalConstraints].
  ConstrainedBox({required this.additionalConstraints, required RenderNode<T> child}) : super(child);

  /// The extra bounds to impose on the child.
  final BoxConstraints additionalConstraints;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final childSize = child.layout(additionalConstraints.enforce(constraints), context);
    child.offset = Offset.zero;
    return constraints.constrain(childSize);
  }
}
