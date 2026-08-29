import '../geometry/box_constraints.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../painting/surface.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import '../render/single_child_node.dart';
import 'stack.dart';

/// Lays its child out as usual but shows none of it.
///
/// The child is sized and placed exactly as it would be if it were an ordinary
/// child — its size still counts toward whatever sizes this node — but nothing
/// in its subtree ever paints, and no point ever hits it: a click over offstage
/// content passes through to whatever is painted beneath it, the same as a
/// click that missed every child entirely.
///
/// This is how a parent reserves room for content it is not currently showing.
/// [Stack] already sizes itself to its largest non-positioned child, so
/// `Stack(children: [Offstage(child: alternative), active])` reserves space
/// for the larger of two (or more) interchangeable children: the stack's size
/// accounts for the hidden alternative whether or not it is the one on screen,
/// so swapping which child is active never resizes the stack.
class Offstage<T> extends SingleChildNode<T> {
  /// Reserves space for [child] without painting or hit-testing it.
  Offstage({required RenderNode<T> child}) : super(child);

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final size = child.layout(constraints, context);
    child.offset = Offset.zero;
    return size;
  }

  @override
  void paint(Surface<T> surface) {}

  @override
  RenderNode<T>? hitTest(Offset point) => null;

  @override
  Object? tagAt(Offset point) => null;

  // [children] is left as the inherited `[child]` so [place] still fixes the
  // child's absolute rect — it really is laid out, just never shown. Every
  // walk that shows a node is overridden instead: [paint], this node's own
  // [hitTest] and [tagAt] above, [hitChildren] for any hit resolution that
  // descends the tree, and [visitChildren] for tooling that tours it.
  @override
  Iterable<RenderNode<T>> get hitChildren => const <Never>[];

  @override
  void visitChildren(void Function(RenderNode<T> child) visit) {}
}
