import '../geometry/box_constraints.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import '../render/single_child_node.dart';
import 'alignment.dart';

/// Sizes to the available space on each bounded axis and positions its child
/// within it according to [alignment]; shrinks to the child on an unbounded
/// axis.
class Align<S> extends SingleChildNode<S> {
  /// Aligns [child] within this box using [alignment].
  Align({required this.alignment, required RenderNode<S> child}) : super(child);

  /// Where the child sits within the extra space.
  final Alignment alignment;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final childSize = child.layout(constraints.loosen(), context);
    final maxW = constraints.maxW;
    final maxH = constraints.maxH;
    final size = constraints.constrain(Size(maxW ?? childSize.w, maxH ?? childSize.h));
    child.offset = Offset(alignment.alignX(size.w - childSize.w), alignment.alignY(size.h - childSize.h));
    return size;
  }
}

/// Centers its child within the available space.
class Center<S> extends Align<S> {
  /// Centers [child].
  Center({required super.child}) : super(alignment: Alignment.center);
}
