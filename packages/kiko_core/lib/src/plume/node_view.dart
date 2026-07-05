import 'aliases.dart';
import 'view.dart';

/// A view backed by a pre-built plume [Node].
///
/// Most views describe their UI declaratively and build a fresh node on demand.
/// A few leaves cannot: scroll viewports and text editors are hand-written
/// [Node]s that measure and paint themselves. A [NodeView] adapts one of those
/// raw nodes into a view, so a custom leaf drops into a box or any container
/// wherever a [View] is expected. [build] returns the wrapped node unchanged.
final class NodeView implements View {
  /// Wraps a pre-built [node] so it can stand in for a view.
  const NodeView(this.node);

  /// The pre-built node this view stands in for.
  final Node node;

  @override
  Node build() => node;
}
