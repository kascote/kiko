import '../geometry/box_constraints.dart';
import '../geometry/edge_insets.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../painting/surface.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import '../render/single_child_node.dart';

/// A single-child box that can size itself, pad its child, and paint a
/// background and border.
///
/// A [border] is one cell thick and insets the child by one on every side (on
/// top of any [padding]). The [background] and [border] carry opaque token
/// tokens; the fill is painted first, then the border, then the child on top.
class Container<T> extends SingleChildNode<T> {
  /// Wraps [child] with optional sizing and decoration.
  Container({
    required RenderNode<T> child,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.background,
    this.border,
  }) : super(child);

  /// Inner padding around the child.
  final EdgeInsets padding;

  /// A fixed width in cells, or `null` to size to the child.
  final int? width;

  /// A fixed height in cells, or `null` to size to the child.
  final int? height;

  /// The fill paint token, or `null` for no fill.
  final T? background;

  /// The border paint token, or `null` for no border.
  final T? border;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final edge = border != null ? 1 : 0;
    final left = padding.left + edge;
    final top = padding.top + edge;
    final horizontal = padding.horizontal + edge * 2;
    final vertical = padding.vertical + edge * 2;

    var box = constraints;
    final w = width;
    final h = height;
    if (w != null || h != null) {
      box = BoxConstraints(
        minW: w ?? box.minW,
        maxW: w ?? box.maxW,
        minH: h ?? box.minH,
        maxH: h ?? box.maxH,
      ).enforce(constraints);
    }

    final childSize = child.layout(box.deflate(horizontal, vertical), context);
    child.offset = Offset(left, top);
    return box.constrain(Size(childSize.w + horizontal, childSize.h + vertical));
  }

  @override
  void paintSelf(Surface<T> surface) {
    final bg = background;
    if (bg != null) {
      surface.fillRect(rect, bg);
    }
    final line = border;
    if (line != null) {
      surface.drawBorder(rect, line);
    }
  }
}
