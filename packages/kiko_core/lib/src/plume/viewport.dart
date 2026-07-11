import 'package:plume/plume.dart' as plume;

import 'aliases.dart';
import 'paint_token.dart';
import 'view.dart';

/// Shows a scrolled window onto a taller [child].
///
/// A thin bridge over plume's [plume.Viewport]: like every [View], it is
/// rebuilt fresh every frame, so [scrollOffset] and [onMeasure] both ride in
/// at build time from whoever owns the scroll state (a `ScrollViewModel`, in
/// `kiko_widgets`). This view holds no state of its own — plume's own doc
/// comment on [plume.Viewport] has the mechanism (unbounded-axis layout,
/// negative placement, clip-derived windowing).
///
/// Router, cursor slot, and `Tagged` are unaffected: a node under this view
/// tags itself exactly as it would anywhere else, and its presence in
/// [package:kiko/src/widgets/hit_map.dart]'s `HitMap` follows this node's
/// `clipsHits`, not anything this view adds.
final class Viewport implements View {
  /// Creates a viewport scrolled [scrollOffset] rows into [child], optionally
  /// reporting geometry to [onMeasure] after each paint.
  const Viewport({required this.scrollOffset, required this.child, this.onMeasure});

  /// How many content rows are scrolled past the top of the viewport.
  ///
  /// Owned and clamped by the caller; this view places the child at exactly
  /// `-scrollOffset` without questioning it.
  final int scrollOffset;

  /// The scrollable content.
  final View child;

  /// Fired after each paint with this frame's measured geometry
  /// ([plume.ViewportMetrics]: viewport rows, content rows, and every tagged
  /// descendant's content-relative row range), or `null` to skip measurement.
  final plume.ViewportMeasureCallback? onMeasure;

  @override
  Node build() => plume.Viewport<PaintToken>(scrollOffset: scrollOffset, child: child.build(), onMeasure: onMeasure);
}
