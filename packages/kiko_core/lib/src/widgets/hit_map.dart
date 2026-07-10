import 'package:meta/meta.dart';
import 'package:plume/plume.dart' as plume;

import '../layout/rect.dart';
import '../plume/paint_token.dart';

/// A tagged widget covering a cell, paired with the rect it was placed at.
///
/// Returned by [HitMap.hitPath], which reports one of these per tagged ancestor
/// of a point.
@immutable
class Hit {
  /// The stable id the widget stamped on its Plume subtree.
  final String id;

  /// Where that widget was placed, in 0-based buffer cells.
  final Rect rect;

  /// Pairs an addressable [id] with the [rect] it occupied.
  const Hit(this.id, this.rect);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Hit && id == other.id && rect == other.rect;

  @override
  int get hashCode => Object.hash(id, rect);

  @override
  String toString() => 'Hit($id, $rect)';
}

/// An immutable spatial index over one frame's tagged widgets.
///
/// Answers where a widget was painted and which widget owns a cell, so a mouse
/// event can be resolved to its target. Coordinates are 0-based buffer cells —
/// the same space as [Rect], `Buffer` and `Position`.
///
/// This is the only hit-testing type in kiko. Which frame a map describes is
/// carried by *which map you hold*, not by which method you call: `frame.hits`
/// is the frame being painted, as far as it has been painted; `ctx.hits` is the
/// committed frame the event saw. Holding one is safe — it is immutable, and it
/// retains the laid-out node trees rather than the buffer they painted into.
///
/// A tag id identifies exactly one node per frame. Duplicates trip an assert in
/// debug; in release the innermost wins.
@immutable
class HitMap {
  final List<plume.RenderNode<PaintToken>> _roots;
  final Map<String, Rect> _rects;

  /// A map over nothing: every query answers `null` or empty.
  ///
  /// This is what a turn sees before the first frame is painted. `hits` is
  /// always a map, never `null`.
  const HitMap.empty() : _roots = const [], _rects = const {};

  const HitMap._(this._roots, this._rects);

  /// Freezes the tagged geometry of [roots], a frame's laid-out trees in paint
  /// order.
  ///
  /// The list is copied, so a frame may go on rendering into its own without
  /// disturbing a map already handed out. The trees themselves are retained by
  /// reference: a frame inflates a fresh one every render, so nothing else can
  /// mutate them.
  factory HitMap.fromRoots(Iterable<plume.RenderNode<PaintToken>> roots) {
    final frozen = List<plume.RenderNode<PaintToken>>.unmodifiable(roots);
    final rects = <String, Rect>{};
    for (final root in frozen) {
      _collectRects(root, rects);
    }
    return HitMap._(frozen, Map<String, Rect>.unmodifiable(rects));
  }

  /// Returns the id of the innermost tagged widget at cell ([x], [y]), or `null`
  /// when nothing addressable sits there.
  ///
  /// Trees rendered later win an overlap, matching what the viewer sees, and
  /// within a tree the deepest tagged node wins. This is the router's per-event
  /// hot path; it allocates nothing and stops at the first hit. Untagged nodes
  /// painted on top do not swallow the tagged widget beneath them.
  String? hitId(int x, int y) {
    final point = plume.Offset(x, y);
    for (final root in _roots.reversed) {
      final id = _hitIdIn(root, point);
      if (id != null) return id;
    }
    return null;
  }

  /// Returns the on-screen rect of the widget stamped with [id], or `null` when
  /// no widget carries it this frame.
  ///
  /// This is the reverse of [hitId]: it locates a widget by its stable id to
  /// anchor an overlay, place a tooltip, or scroll it into view. Total for a
  /// placed tag, because ids are unique per frame.
  Rect? rectOf(String id) => _rects[id];

  /// Returns the tagged widgets covering cell ([x], [y]), outermost first.
  ///
  /// The last entry is the widget [hitId] would name. The path stays within the
  /// topmost tree that hits: a frame's trees are rendered independently and are
  /// not ancestors of one another, so nothing spans them.
  ///
  /// Kiko never bubbles a pointer event. This is the primitive an app builds its
  /// own propagation from: deliver to the last entry, and on a decline try the
  /// one before it.
  List<Hit> hitPath(int x, int y) {
    final point = plume.Offset(x, y);
    for (final root in _roots.reversed) {
      final path = _pathIn(root, point);
      if (path.isNotEmpty) return List<Hit>.unmodifiable(path);
    }
    return const <Hit>[];
  }

  static Rect _rectOf(plume.RenderNode<PaintToken> node) {
    final r = node.rect;
    return Rect.create(x: r.x, y: r.y, width: r.width, height: r.height);
  }

  static List<plume.RenderNode<PaintToken>> _childrenOf(plume.RenderNode<PaintToken> node) {
    final kids = <plume.RenderNode<PaintToken>>[];
    node.visitChildren(kids.add);
    return kids;
  }

  /// Walks [node] in pre-order, recording the rect of every string-tagged node.
  ///
  /// A descendant is visited after its ancestor and a later sibling after an
  /// earlier one, so writing over a repeated id leaves the innermost — and, on
  /// a tie, the topmost — which is the node [hitId] would have named.
  static void _collectRects(plume.RenderNode<PaintToken> node, Map<String, Rect> into) {
    final tag = node.tag;
    if (tag is String) {
      assert(
        !into.containsKey(tag),
        'Duplicate hit tag "$tag": a tag id must identify exactly one node per '
        'frame, or rectOf cannot say which node it means. Two widgets are '
        'tagging the same id — check for a Tagged() wrapping a widget that '
        'already tags itself with its own model id.',
      );
      into[tag] = _rectOf(node);
    }
    node.visitChildren((child) => _collectRects(child, into));
  }

  /// Returns the innermost string tag under [point] within [node]'s subtree.
  ///
  /// Descends children front-to-back so the node the viewer sees on top wins,
  /// and gates on each node's rect exactly as Plume's own hit testing does.
  /// Non-string tags are ignored rather than allowed to shadow a string tag
  /// further out: Plume's `tag` is an opaque handle of any type, and only the
  /// ids kiko stamps are addressable.
  static String? _hitIdIn(plume.RenderNode<PaintToken> node, plume.Offset point) {
    if (!node.rect.contains(point)) return null;
    for (final child in _childrenOf(node).reversed) {
      final id = _hitIdIn(child, point);
      if (id != null) return id;
    }
    final tag = node.tag;
    return tag is String ? tag : null;
  }

  /// Returns the chain of string-tagged nodes over [point], outermost first.
  ///
  /// Takes the same branch [_hitIdIn] takes, and reports every tagged node along
  /// it rather than only the last.
  static List<Hit> _pathIn(plume.RenderNode<PaintToken> node, plume.Offset point) {
    if (!node.rect.contains(point)) return const <Hit>[];
    final tag = node.tag;
    for (final child in _childrenOf(node).reversed) {
      final sub = _pathIn(child, point);
      if (sub.isNotEmpty) {
        return tag is String ? [Hit(tag, _rectOf(node)), ...sub] : sub;
      }
    }
    return tag is String ? [Hit(tag, _rectOf(node))] : const <Hit>[];
  }
}
