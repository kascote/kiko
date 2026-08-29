import '../geometry/rect.dart';

/// A sink the paint pass draws into.
///
/// The engine walks the laid-out tree and calls these methods in paint order;
/// each call is a *draw intent*. Backends implement it to render for real (for
/// example into a terminal buffer), and tests implement it to record the calls.
///
/// [T] is the opaque paint token carried from the widgets. The surface is the
/// one place it is interpreted — the layout core never looks inside it.
///
/// The surface also tracks the node painting now. The paint walk pushes each
/// node — its rect and its tag — before painting it and pops it after
/// ([pushNode] / [popNode]). [clipRect] is the intersection of every pushed
/// rect, so a node paints only within the box layout assigned it: draw calls
/// landing outside that region are trimmed or dropped. [tagChain] is every
/// pushed tag, outermost first, so a node can learn its ancestry while it
/// paints. Concrete surfaces extend `ClippingSurface`, which owns the node
/// stack and the trim/drop rules, so a leaf drawing through the three draw
/// methods cannot escape the clip.
abstract class Surface<T> {
  /// Draws the run of graphemes [run] starting at cell ([x], [y]), styled by
  /// [token].
  void drawText(int x, int y, String run, T token);

  /// Fills every cell of [rect], styled by [token].
  void fillRect(Rect rect, T token);

  /// Draws a border around the edge of [rect], styled by [token].
  void drawBorder(Rect rect, T token);

  /// Enters a node: pushes [rect] as the active clip, intersected with the
  /// current clip, and [tag] onto the tag chain.
  ///
  /// Every draw call between this and the matching [popNode] is confined to
  /// the pushed region. A `null` [tag] adds nothing to [tagChain]; pass one to
  /// stand in for an untagged ancestor.
  void pushNode(Rect rect, [Object? tag]);

  /// Leaves the node entered by the matching [pushNode].
  void popNode();

  /// The active clip — the intersection of every pushed rect — or `null` when
  /// nothing is pushed (an unclipped surface).
  Rect? get clipRect;

  /// The tags of the node painting now and its ancestors, outermost first.
  ///
  /// Read it from `paintSelf`: the node's own tag is the last entry. Nodes
  /// with no tag contribute nothing, so the list is empty outside any tagged
  /// node. Plume stores the tags and never interprets them.
  List<Object> get tagChain;
}
