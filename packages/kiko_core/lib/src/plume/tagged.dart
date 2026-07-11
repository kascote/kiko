import '../widgets/hit_map.dart';
import 'aliases.dart';
import 'view.dart';

/// Marks [child] as a hit region addressable by [id].
///
/// A tagged region is what a mouse event resolves to: the id reaches `update`
/// as the target of the event, and [HitMap.rectOf] reports where the region was
/// painted. Wrap whatever should answer for a click.
///
/// ```dart
/// Tagged('save-button', Box(child: Line('Save')))
/// ```
///
/// This is the one place a hit tag is set. The underlying plume `tag` field is
/// an engine-opaque handle; nothing else should reach past this view to write
/// it.
///
/// **Where you put the tag decides what the event's local coordinates mean.**
/// The only rule is that a routed event's position is relative to the tagged
/// node's rect. Tag a bordered box and a click reports coordinates counted from
/// the border; tag the content inside it and the same click reports coordinates
/// counted from the content. Neither is more correct, and nothing downstream
/// compensates — choose the one whose origin the handler wants to measure from.
///
/// **An id names exactly one region per frame.** Wrapping a widget that already
/// tags its own subtree with its model id puts that id on two nodes, and the
/// rect of such an id is then ambiguous. Building the frame's [HitMap] asserts
/// against it in debug. The check cannot live here, because a [Tagged] cannot
/// see what its siblings tagged.
final class Tagged implements View {
  /// Tags [child]'s region with [id].
  const Tagged(this.id, this.child);

  /// The stable id this region answers to.
  final String id;

  /// The view whose region is being tagged.
  final View child;

  @override
  Node build() {
    final node = child.build();
    assert(
      node.tag == null,
      'Tagged("$id", ...) would overwrite the tag "${node.tag}" its child '
      'already carries. Built-in widgets tag themselves with their model id — '
      'wrap a container around one instead, or address it by its own id.',
    );
    return node..tag = id;
  }
}
