import '../widgets/hit_map.dart';
import '../widgets/hit_tag.dart';
import 'aliases.dart';
import 'view.dart';

/// Tags [child] with [id] so pointer events resolve to it, or use
/// [Tagged.scope] to mark it as a scope instead.
///
/// A tagged node is what a mouse event resolves to: the id reaches `update`
/// as the target of the event, and [HitMap.rectOf] reports where the node was
/// painted. Wrap whatever should answer for a click.
///
/// ```dart
/// Tagged('save-button', Container(child: Line('Save')))
/// ```
///
/// [Tagged] adds no node of its own — it stamps [child]'s own built node, so
/// wrapping and a container view's `id:` parameter produce the same tree.
/// Reach for `id:` when the caller already constructs the container; reach
/// for [Tagged] to tag a view the caller does not construct. The underlying
/// plume `tag` field is an engine-opaque handle; nothing should write it
/// outside these stamping sites.
///
/// **Where you put the tag decides what the event's local coordinates mean.**
/// The only rule is that a routed event's position is relative to the tagged
/// node's rect. Tag a bordered box and a click reports coordinates counted from
/// the border; tag the content inside it and the same click reports coordinates
/// counted from the content. Neither is more correct, and nothing downstream
/// compensates — choose the one whose origin the handler wants to measure from.
///
/// **An id names exactly one node per frame.** Two guards enforce this in
/// debug. [build] asserts that [child]'s node carries no tag yet; this catches
/// wrapping a widget that tags its own root node. Building the frame's
/// [HitMap] asserts that no id lands on two nodes; this catches what a
/// [Tagged] cannot see — a sibling or an inner node tagged with the same id.
final class Tagged implements View {
  /// Tags [child] with [id].
  const Tagged(String this.id, this.child) : name = null;

  /// Marks [child] as the scope [name], so every tag beneath it resolves as
  /// `name/...` instead of standing alone.
  const Tagged.scope(String this.name, this.child) : id = null;

  /// The stable id the tagged node answers to, or `null` when this [Tagged]
  /// marks a scope instead.
  final String? id;

  /// The scope name the tagged node carries, or `null` when this [Tagged]
  /// tags a plain id instead.
  final String? name;

  /// The view being tagged.
  final View child;

  @override
  Node build() {
    final node = child.build();
    assert(
      node.tag == null,
      'Tagged(${id != null ? '"$id"' : '.scope("$name")'}, ...) would '
      'overwrite the tag "${node.tag}" its child already carries. Built-in '
      'widgets tag themselves with their model id — wrap a container around '
      'one instead, or address it by its own id.',
    );
    return node..tag = id != null ? IdTag(id!) : ScopeTag(name!);
  }
}
