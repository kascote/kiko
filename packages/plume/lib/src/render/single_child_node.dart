import 'render_node.dart';

/// A [RenderNode] with exactly one [child].
///
/// Handles the child-list plumbing so single-child widgets (padding, align,
/// constrained boxes, containers) only implement their own sizing and painting.
abstract class SingleChildNode<S> extends RenderNode<S> {
  /// Creates a node wrapping [child].
  SingleChildNode(this.child);

  /// The single child this node lays out and positions.
  final RenderNode<S> child;

  @override
  List<RenderNode<S>> get children => <RenderNode<S>>[child];
}
