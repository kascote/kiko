import 'package:meta/meta.dart';
import 'package:plume/plume.dart' as plume;

import '../layout/rect.dart';
import '../mvu/region.dart';
import '../plume/paint_token.dart';
import 'hit_tag.dart';

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
  bool operator ==(Object other) => identical(this, other) || other is Hit && id == other.id && rect == other.rect;

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
  final Map<String, plume.RenderNode<PaintToken>> _nodes;

  /// A map over nothing: every query answers `null` or empty.
  ///
  /// This is what a turn sees before the first frame is painted. `hits` is
  /// always a map, never `null`.
  const HitMap.empty() : _roots = const [], _rects = const {}, _nodes = const {};

  const HitMap._(this._roots, this._rects, this._nodes);

  /// Freezes the tagged geometry of [roots], a frame's laid-out trees in paint
  /// order.
  ///
  /// The list is copied, so a frame may go on rendering into its own without
  /// disturbing a map already handed out. The trees themselves are retained by
  /// reference: a frame inflates a fresh one every render, so nothing else can
  /// mutate them. Retaining the nodes is also what lets [regionAt] descend a
  /// widget's own subtree for the marked part under a pointer.
  factory HitMap.fromRoots(Iterable<plume.RenderNode<PaintToken>> roots) {
    final frozen = List<plume.RenderNode<PaintToken>>.unmodifiable(roots);
    final rects = <String, Rect>{};
    final nodes = <String, plume.RenderNode<PaintToken>>{};
    for (final root in frozen) {
      _collectRects(root, rects, nodes, null);
    }
    assert(_regionKeysAreUnique(nodes), 'unreachable: the check throws its own message');
    return HitMap._(
      frozen,
      Map<String, Rect>.unmodifiable(rects),
      Map<String, plume.RenderNode<PaintToken>>.unmodifiable(nodes),
    );
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

  /// Returns the region the widget tagged [id] marked under cell ([x], [y]), or
  /// `null` when the pointer is over no marked part of it.
  ///
  /// The search descends only [id]'s own subtree — found in one query through
  /// the id-to-node index built with the map — and stops at any nested tagged
  /// widget, so one widget's regions can never surface as another's. `null`
  /// means the point is on a gap between marked parts, off the widget entirely,
  /// or on a widget that marks nothing; and `null` too when [id] is not on
  /// screen this frame.
  ///
  /// The router calls this for the widget a pointer resolved to (or the widget
  /// holding a captured gesture); an app rebuilding a pointer against a chrome
  /// alias calls it for the member the chrome decorates.
  Region? regionAt(String id, int x, int y) {
    final node = _nodes[id];
    if (node == null) return null;
    return _regionIn(node, plume.Offset(x, y), isRoot: true);
  }

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

  /// Walks [node] in pre-order, recording the rect of every id-tagged node
  /// whose rect survives the [clip] carried down from a `clipsHits` ancestor,
  /// or `null` when nothing upstream clips.
  ///
  /// A descendant is visited after its ancestor and a later sibling after an
  /// earlier one, so writing over a repeated id leaves the innermost — and, on
  /// a tie, the topmost — which is the node [hitId] would have named.
  ///
  /// Presence is visibility-true: a tagged node whose rect falls entirely
  /// outside [clip] (for example, scrolled off a `Viewport`) is omitted
  /// rather than recorded, so [rectOf] answers `null` for it — the signal
  /// capture-cancel relies on. A node that IS recorded still gets its full,
  /// unclipped rect: that rect is the widget's coordinate origin, and clipping
  /// it would corrupt `local` math for a partially visible widget.
  static void _collectRects(
    plume.RenderNode<PaintToken> node,
    Map<String, Rect> into,
    Map<String, plume.RenderNode<PaintToken>> nodes,
    plume.Rect? clip,
  ) {
    final ownRect = node.rect;
    final tag = node.tag;
    assert(
      tag is! String,
      'Raw String hit tag "$tag": kiko stamps HitTag values, not bare strings. '
      'Stamp IdTag("$tag") — or wrap the view in Tagged — instead.',
    );
    if (tag is IdTag && (clip == null || !clip.intersect(ownRect).isEmpty)) {
      final id = tag.id;
      assert(
        !into.containsKey(id),
        'Duplicate hit tag "$id": a tag id must identify exactly one node per '
        'frame, or rectOf cannot say which node it means. Two widgets are '
        'tagging the same id — check for a Tagged() wrapping a widget that '
        'already tags itself with its own model id.',
      );
      into[id] = _rectOf(node);
      // The same visibility gate as the rect: a widget scrolled off a clipping
      // ancestor is absent, so no pointer resolves against its regions either.
      nodes[id] = node;
    }
    final childClip = node.clipsHits ? (clip == null ? ownRect : clip.intersect(ownRect)) : clip;
    node.visitChildren((child) => _collectRects(child, into, nodes, childClip));
  }

  /// Returns the innermost id tag under [point] within [node]'s subtree.
  ///
  /// Descends children front-to-back so the node the viewer sees on top wins,
  /// and gates on each node's rect exactly as Plume's own hit testing does.
  /// A tag that is not an [IdTag] is ignored rather than allowed to shadow one
  /// further out: Plume's `tag` is an opaque handle of any type, and only the
  /// ids kiko stamps are addressable.
  static String? _hitIdIn(plume.RenderNode<PaintToken> node, plume.Offset point) {
    if (!node.rect.contains(point)) return null;
    for (final child in _childrenOf(node).reversed) {
      final id = _hitIdIn(child, point);
      if (id != null) return id;
    }
    final tag = node.tag;
    return tag is IdTag ? tag.id : null;
  }

  /// Returns the innermost region marked under [point] within [node]'s subtree,
  /// or `null` when nothing marked covers it.
  ///
  /// Descends children front-to-back and, within a node, lets the last-marked
  /// covering region win — both mirror paint order, so the part painted on top
  /// answers a click on an overlap (a tree's indicator drawn over its row). The
  /// walk stops at any nested id-tagged node other than [node] itself: that
  /// is a separate widget, and its regions belong to it, never to the enclosing
  /// widget this resolves for. A non-[Region] mark key (Plume's key is an
  /// opaque `Object`) is ignored, exactly as a non-[IdTag] tag is.
  static Region? _regionIn(plume.RenderNode<PaintToken> node, plume.Offset point, {required bool isRoot}) {
    if (!node.rect.contains(point)) return null;
    if (!isRoot && node.tag is IdTag) return null;
    for (final child in _childrenOf(node).reversed) {
      final region = _regionIn(child, point, isRoot: false);
      if (region != null) return region;
    }
    Region? found;
    for (final marked in node.markedRegions) {
      final key = marked.key;
      if (key is Region && marked.rect.contains(point)) found = key;
    }
    return found;
  }

  /// Debug-only: asserts no widget marks the same region key twice in a frame —
  /// the region-side sibling of the duplicate-tag assert, so an ambiguous part
  /// fails loudly rather than resolving arbitrarily.
  ///
  /// Walks each on-screen tagged widget's own subtree (stopping at nested
  /// tagged widgets, the same boundary [_regionIn] respects) and trips if a key
  /// repeats. Returns `true` so it can sit inside an `assert`; the real message
  /// comes from the inner assert it trips.
  static bool _regionKeysAreUnique(Map<String, plume.RenderNode<PaintToken>> nodes) {
    for (final entry in nodes.entries) {
      final seen = <Object>{};
      void walk(plume.RenderNode<PaintToken> node, {required bool isRoot}) {
        if (!isRoot && node.tag is IdTag) return;
        for (final marked in node.markedRegions) {
          assert(
            seen.add(marked.key),
            'Duplicate region key "${marked.key}" in widget "${entry.key}": a '
            'widget may mark a region key at most once per frame, or the part '
            'it names is ambiguous.',
          );
        }
        node.visitChildren((child) => walk(child, isRoot: false));
      }

      walk(entry.value, isRoot: true);
    }
    return true;
  }

  /// Returns the chain of id-tagged nodes over [point], outermost first.
  ///
  /// Takes the same branch [_hitIdIn] takes, and reports every tagged node along
  /// it rather than only the last.
  static List<Hit> _pathIn(plume.RenderNode<PaintToken> node, plume.Offset point) {
    if (!node.rect.contains(point)) return const <Hit>[];
    final tag = node.tag;
    for (final child in _childrenOf(node).reversed) {
      final sub = _pathIn(child, point);
      if (sub.isNotEmpty) {
        return tag is IdTag ? [Hit(tag.id, _rectOf(node)), ...sub] : sub;
      }
    }
    return tag is IdTag ? [Hit(tag.id, _rectOf(node))] : const <Hit>[];
  }
}
