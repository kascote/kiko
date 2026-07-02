import 'package:meta/meta.dart';

import '../geometry/box_constraints.dart';
import '../geometry/offset.dart';
import '../geometry/rect.dart';
import '../geometry/size.dart';
import '../painting/surface.dart';
import 'layout_context.dart';

/// The base of every node in a Plume layout tree.
///
/// A frame builds a fresh tree, then drives it through the same passes each
/// time: [layout] sizes every node (constraints down, sizes up), [place] fixes
/// each node's absolute [rect], [paint] emits draw intents, and [hitTest] finds
/// the top-most node under a point. Containers override [children] and size
/// them in [performLayout]; leaves override [paintSelf] to draw.
///
/// [T] is the opaque paint token carried through to the [Surface]; Plume never
/// inspects it.
abstract class RenderNode<T> {
  /// This node's size, chosen during [layout].
  Size size = Size.zero;

  /// This node's position relative to its parent, assigned by the parent
  /// during layout. The root keeps the default of [Offset.zero].
  Offset offset = Offset.zero;

  Rect _rect = Rect.zero;

  /// This node's absolute rectangle on the grid, fixed during [place].
  Rect get rect => _rect;

  /// The child nodes, in paint order (front-most last). Empty for leaves.
  @protected
  List<RenderNode<T>> get children => <RenderNode<T>>[];

  /// Calls [visit] for each child, in paint order.
  ///
  /// Lets tooling (goldens, custom traversals) walk the tree without touching
  /// the child list directly.
  void visitChildren(void Function(RenderNode<T> child) visit) {
    children.forEach(visit);
  }

  /// Sizes this node under [constraints], stores the result in [size], and
  /// returns it.
  ///
  /// Subclasses implement [performLayout]; this wrapper guarantees [size] is
  /// always recorded. Every incoming constraint is asserted well-formed here,
  /// the single funnel every node passes through, so an inverted or negative
  /// constraint fails loudly in debug at zero release cost.
  @nonVirtual
  Size layout(BoxConstraints constraints, LayoutContext context) {
    assert(
      constraints.isNormalized,
      'RenderNode.layout received un-normalized constraints: $constraints. '
      'Minimums must be non-negative and no larger than their maximums.',
    );
    return size = performLayout(constraints, context);
  }

  /// Computes this node's size under [constraints], laying out and offsetting
  /// any children along the way. [context] carries ambient inputs such as the
  /// text measurer.
  @protected
  Size performLayout(BoxConstraints constraints, LayoutContext context);

  /// Fixes this node's absolute [rect] with its top-left at [origin], then
  /// places each child at `origin + child.offset`.
  @nonVirtual
  void place(Offset origin) {
    _rect = Rect.fromOriginSize(origin, size);
    for (final child in children) {
      child.place(origin + child.offset);
    }
  }

  /// Emits this node's own draw intents, then paints its children on top.
  ///
  /// This node's [rect] is pushed as the active clip before painting and popped
  /// after, so a node — or any descendant — only affects cells inside the box
  /// layout assigned it (intersected with every ancestor's rect). Clipping is a
  /// paint-only guarantee: [hitTest] is deliberately not clipped.
  void paint(Surface<T> surface) {
    surface.pushClip(rect);
    paintSelf(surface);
    for (final child in children) {
      child.paint(surface);
    }
    surface.popClip();
  }

  /// Emits the draw intents for this node alone, not its children.
  ///
  /// Leaves override this; the default draws nothing.
  @protected
  void paintSelf(Surface<T> surface) {}

  /// Returns the top-most node whose [rect] contains [point], searching
  /// children front-to-back. Returns `null` when [point] is outside this node.
  ///
  /// Hit testing is not clipped: a child whose rect spills past this node's is
  /// still hit where it was placed. Clipping is a paint-only guarantee (see
  /// [paint]).
  RenderNode<T>? hitTest(Offset point) {
    if (!_rect.contains(point)) {
      return null;
    }
    for (final child in children.reversed) {
      final hit = child.hitTest(point);
      if (hit != null) {
        return hit;
      }
    }
    return this;
  }
}
