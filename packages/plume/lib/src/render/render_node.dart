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

  /// An opaque handle that makes this node addressable, or `null` for an
  /// anonymous node.
  ///
  /// Set by whoever builds the tree — kiko stamps a widget's stable id here —
  /// and never interpreted by the engine, only compared by equality the way a
  /// map key is. [tagAt] resolves one from a point and [nodeForTag] finds the
  /// node that carries it.
  Object? tag;

  /// The regions this node marked while painting itself, or an empty list when
  /// it marked none.
  ///
  /// A *marked region* is a (key, rect) pair a node records for one of its own
  /// painted parts — a row, a header, an indicator — via [markRegion] from
  /// [paintSelf]. Like [tag] the key is opaque: the engine stores it and never
  /// reads it; interpreting it belongs to the embedding framework (kiko's hit
  /// map descends the committed tree to resolve the part under a pointer). The
  /// rect is in absolute grid cells, the same space [paint] draws in.
  ///
  /// The list describes the last committed frame: [paint] clears it before this
  /// node repaints, so a stale mark cannot survive a repaint even when a
  /// widget's paint returns early. A node that never marks never allocates it.
  List<MarkedRegion> get markedRegions => _markedRegions ?? const <MarkedRegion>[];

  List<MarkedRegion>? _markedRegions;

  /// Records that [key] names the part painted at [rect], appending it to this
  /// node's [markedRegions].
  ///
  /// Call this from [paintSelf], inside the same loop that paints the part, so
  /// the mark is written by the code that drew it and their geometry cannot
  /// drift apart. [key] is opaque to Plume (an embedding framework gives it
  /// meaning); [rect] is in absolute grid cells. Marks made this way are
  /// cleared automatically before the next repaint — a caller never clears.
  @protected
  void markRegion(Object key, Rect rect) {
    (_markedRegions ??= <MarkedRegion>[]).add(MarkedRegion(key, rect));
  }

  /// Whether this node's [rect] clips its descendants' hit *presence*.
  ///
  /// Plume itself does not consume this — [hitTest] and [tagAt] already prune
  /// independently at each node's own [rect] regardless of this flag. It is a
  /// capability a host layer reads instead: a widget host that also tracks
  /// whether an id is reachable at all (not merely what a point resolves to)
  /// can use it to treat a descendant scrolled outside a clipping ancestor as
  /// absent. `false` for every node by default, so nothing changes for an
  /// existing tree; a clipping container such as a scrolling viewport
  /// overrides it `true`.
  bool get clipsHits => false;

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
  /// This node is pushed onto the surface before painting and popped after
  /// ([Surface.pushNode]). Its [rect] becomes the active clip, so a node — or
  /// any descendant — only affects cells inside the box layout assigned it
  /// (intersected with every ancestor's rect). Its [tag] joins the surface's
  /// [Surface.tagChain], so [paintSelf] here and in every descendant can read
  /// the tags of the nodes enclosing it. Clipping is a paint-only guarantee:
  /// it constrains where a node may draw, not whether [hitTest] or [tagAt] can
  /// reach it — those prune independently at each node's own [rect] (see
  /// [hitTest]).
  ///
  /// This node's [markedRegions] are dropped before [paintSelf] runs, so the
  /// marks [paintSelf] makes describe only this repaint. A node whose paint is
  /// overridden away (for example `Offstage`, a no-op) neither clears nor
  /// marks — consistent, since such a node hides its whole subtree from hit
  /// resolution too.
  void paint(Surface<T> surface) {
    _markedRegions = null;
    surface.pushNode(rect, tag);
    paintSelf(surface);
    for (final child in children) {
      child.paint(surface);
    }
    surface.popNode();
  }

  /// Emits the draw intents for this node alone, not its children.
  ///
  /// Leaves override this; the default draws nothing.
  @protected
  void paintSelf(Surface<T> surface) {}

  /// Returns the top-most node whose [rect] contains [point], searching
  /// children front-to-back. Returns `null` when [point] is outside this node.
  ///
  /// There is no accumulated clip stack here: each node visited gates its own
  /// descent at its own [rect], so a point outside an ancestor's rect never
  /// reaches that ancestor's children, no matter where a descendant is placed
  /// relative to it. This is independent of paint clipping (see [paint]),
  /// which only constrains where a node may draw.
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

  /// Returns the [tag] of the innermost tagged node enclosing [point], or `null`
  /// when no tagged node covers it.
  ///
  /// Like [hitTest] this descends children front-to-back, so a node drawn on top
  /// of an overlap wins; unlike [hitTest] it reports a *tag*, returning the
  /// deepest descendant that carries one and only falling back to this node's
  /// own [tag] when nothing below it is tagged. That fallback is the point: the
  /// node physically under a point is usually an untagged leaf, so
  /// `hitTest(point)?.tag` would miss the enclosing widget this finds.
  ///
  /// Prunes the same way as [hitTest]: each node visited gates its own descent
  /// at its own [rect], independent of paint clipping.
  Object? tagAt(Offset point) {
    if (!_rect.contains(point)) {
      return null;
    }
    for (final child in children.reversed) {
      final found = child.tagAt(point);
      if (found != null) {
        return found;
      }
    }
    return tag;
  }

  /// Returns the node whose [tag] equals [target], searched depth-first from
  /// this node, or `null` when none carries it.
  ///
  /// Tags are assumed unique, so the first match is the only match. Read the
  /// returned node's [rect] to anchor, measure, or scroll a widget into view.
  RenderNode<T>? nodeForTag(Object target) {
    if (tag == target) {
      return this;
    }
    for (final child in children) {
      final found = child.nodeForTag(target);
      if (found != null) {
        return found;
      }
    }
    return null;
  }
}

/// One part a node marked while painting: an opaque [key] and the absolute
/// [rect] the part was painted at.
///
/// A node appends these through [RenderNode.markRegion] and exposes them as
/// [RenderNode.markedRegions]. Plume treats [key] as opaque — it stores the
/// pair and never inspects it — exactly as it does [RenderNode.tag]; an
/// embedding framework matches [key] by equality to give it meaning.
@immutable
class MarkedRegion {
  /// Pairs [key] with the [rect] its part was painted at.
  const MarkedRegion(this.key, this.rect);

  /// The opaque handle naming the marked part. Compared only by equality.
  final Object key;

  /// The part's absolute rectangle on the grid, in the space paint draws in.
  final Rect rect;

  @override
  bool operator ==(Object other) => other is MarkedRegion && other.key == key && other.rect == rect;

  @override
  int get hashCode => Object.hash(key, rect);

  @override
  String toString() => 'MarkedRegion($key, $rect)';
}
