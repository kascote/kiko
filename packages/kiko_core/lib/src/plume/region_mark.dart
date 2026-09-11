import 'package:plume/plume.dart' as plume;

import '../mvu/region.dart';
import 'aliases.dart';
import 'paint_token.dart';
import 'view.dart';

/// Marks [region] over [child]'s own rect, painting nothing beyond it.
///
/// Wrap a view with it to make a whole subtree answer as one part under a
/// pointer. Pair it with `Tagged` or `Tagged.scope` to give the marked subtree
/// a hit path.
///
/// [child] is laid out and painted exactly as it would be on its own; this
/// view only adds the mark.
final class RegionMark implements View {
  /// Marks [region] over [child]'s rect.
  const RegionMark(this.region, this.child);

  /// The region this marks over its own rect.
  final Region region;

  /// The view laid out and painted under the mark.
  final View child;

  @override
  Node build() => _RegionMarkNode(region, child.build());
}

/// The node [RegionMark] builds: sizes and paints exactly like its child, and
/// marks [region] over its own rect. Carries no tag of its own, so a wrapping
/// `Tagged` or `Tagged.scope` can stamp it.
class _RegionMarkNode extends plume.SingleChildNode<PaintToken> {
  _RegionMarkNode(this.region, Node child) : super(child);

  /// The region marked over this node's rect.
  final Region region;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) {
    final size = child.layout(constraints, context);
    child.offset = plume.Offset.zero;
    return size;
  }

  @override
  void paintSelf(Surface surface) => markRegion(region, rect);
}
