import '../geometry/box_constraints.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import '../render/single_child_node.dart';
import 'alignment.dart';

/// How a [Stack] sizes the children that are not [Positioned].
enum StackFit {
  /// Each child may pick any size up to the stack, sizing to its own content.
  loose,

  /// Each child is forced to fill the whole stack.
  expand,
}

/// Pins its child to chosen edges of a [Stack].
///
/// Each edge is optional. Setting [left], [top], [right], or [bottom] pins the
/// child that far from that edge of the stack; setting both edges on an axis
/// stretches the child to span between them. [width] and [height] give an
/// explicit size for an axis that a single edge (or no edge) leaves free, and an
/// axis with neither an edge nor a size falls back to the stack's alignment.
///
/// This is a marker the parent [Stack] reads, much like a flexible child of a
/// row or column: its own layout just passes the incoming constraints straight
/// through to the child.
class Positioned<T> extends SingleChildNode<T> {
  /// Positions [child] using any mix of edges ([left]/[top]/[right]/[bottom])
  /// and an explicit [width]/[height].
  Positioned({
    required RenderNode<T> child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
  }) : super(child);

  /// Distance from the stack's left edge, or `null` to leave the left free.
  final int? left;

  /// Distance from the stack's top edge, or `null` to leave the top free.
  final int? top;

  /// Distance from the stack's right edge, or `null` to leave the right free.
  final int? right;

  /// Distance from the stack's bottom edge, or `null` to leave the bottom free.
  final int? bottom;

  /// Explicit width, used when [left] and [right] do not already fix it.
  final int? width;

  /// Explicit height, used when [top] and [bottom] do not already fix it.
  final int? height;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final size = child.layout(constraints, context);
    child.offset = Offset.zero;
    return size;
  }
}

/// Layers its children, painting each over the one before it.
///
/// Non-positioned children are sized per [fit] and placed within the stack by
/// [alignment]; [Positioned] children are pinned to the edges they name. The
/// stack sizes itself to its largest non-positioned child, or fills the incoming
/// constraints when every child is positioned. Children paint front-to-back in
/// list order and hit-test back-to-front, so the last child wins an overlap.
class Stack<T> extends RenderNode<T> {
  /// Creates a stack of [children], aligned by [alignment] and sized per [fit].
  Stack({
    required List<RenderNode<T>> children,
    this.alignment = Alignment.topLeft,
    this.fit = StackFit.loose,
  }) : _children = children;

  /// Where each non-positioned child sits within the stack's extra space.
  final Alignment alignment;

  /// How non-positioned children are sized.
  final StackFit fit;

  final List<RenderNode<T>> _children;

  @override
  List<RenderNode<T>> get children => _children;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final childConstraints = switch (fit) {
      StackFit.loose => constraints.loosen(),
      StackFit.expand => BoxConstraints.tight(constraints.biggest),
    };

    // Pass 1: size the stack from its non-positioned children.
    var hasNonPositioned = false;
    var width = constraints.minW;
    var height = constraints.minH;
    for (final child in _children) {
      if (child is Positioned<T>) {
        continue;
      }
      hasNonPositioned = true;
      final childSize = child.layout(childConstraints, context);
      if (childSize.w > width) {
        width = childSize.w;
      }
      if (childSize.h > height) {
        height = childSize.h;
      }
    }
    // With no non-positioned child, the stack sizes to the incoming
    // constraints. An unbounded axis has no extent to fill, so it would collapse
    // to its minimum (typically zero) — almost always a mistake, so fail loudly.
    assert(
      hasNonPositioned || (constraints.hasBoundedWidth && constraints.hasBoundedHeight),
      'A Stack whose children are all Positioned needs a bounded constraint to '
      'size itself; under an unbounded axis it collapses to its minimum. '
      'Constraints: $constraints.',
    );
    final size = hasNonPositioned ? constraints.constrain(Size(width, height)) : constraints.biggest;

    // Pass 2: place every child within the resolved size.
    for (final child in _children) {
      if (child is Positioned<T>) {
        _placePositioned(child, size, context);
      } else {
        child.offset = Offset(alignment.alignX(size.w - child.size.w), alignment.alignY(size.h - child.size.h));
      }
    }
    return size;
  }

  void _placePositioned(Positioned<T> child, Size size, LayoutContext context) {
    final left = child.left;
    final top = child.top;
    final right = child.right;
    final bottom = child.bottom;

    var minW = 0;
    int? maxW;
    if (left != null && right != null) {
      minW = maxW = _atLeastZero(size.w - left - right);
    } else {
      final w = child.width;
      if (w != null) {
        minW = maxW = w;
      }
    }

    var minH = 0;
    int? maxH;
    if (top != null && bottom != null) {
      minH = maxH = _atLeastZero(size.h - top - bottom);
    } else {
      final h = child.height;
      if (h != null) {
        minH = maxH = h;
      }
    }

    child.layout(BoxConstraints(minW: minW, maxW: maxW, minH: minH, maxH: maxH), context);

    final childW = child.size.w;
    final childH = child.size.h;
    final x = left ?? (right != null ? size.w - right - childW : alignment.alignX(size.w - childW));
    final y = top ?? (bottom != null ? size.h - bottom - childH : alignment.alignY(size.h - childH));
    child.offset = Offset(x, y);
  }

  static int _atLeastZero(int v) => v < 0 ? 0 : v;
}
