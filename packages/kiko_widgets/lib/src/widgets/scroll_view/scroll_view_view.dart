import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

import 'scroll_view_model.dart';
import 'types.dart';

/// A ScrollView as a view — the plume-native view for [ScrollViewModel].
///
/// Content area only: no built-in scrollbar, no border, no chrome — compose
/// those around it. Wraps [child] in the kiko_core [Viewport] bridge at
/// [ScrollViewModel.scrollOffset], and tags the viewport node itself with
/// [ScrollViewModel.id] — the content area IS the hit region, so a wheel over
/// a gap between composed children still resolves to the model, not the
/// background. Installs the measurement callback that feeds this frame's
/// viewport/content extents and every tagged descendant's content-relative
/// row range back into the model through [ScrollViewModel.setViewportMetrics]
/// — the same view-pushes-state-in back-channel List and Tree use for
/// `visibleCount`, one-frame lag accepted. Foreign (non-`String`) tags are
/// dropped here, mirroring [HitMap]'s own string-tag-only rule.
final class ScrollView implements View {
  /// Creates a scroll view over [model], showing [child]'s scrolled window.
  const ScrollView({required this.model, required this.child});

  /// The model whose offset drives this view and whose geometry back-channel
  /// this view feeds every frame.
  final ScrollViewModel model;

  /// The scrollable content, laid out with its main axis unbounded.
  final View child;

  @override
  Node build() => Viewport(
    scrollOffset: model.scrollOffset,
    onMeasure: _onMeasure,
    child: child,
  ).build()..tag = model.id;

  void _onMeasure(plume.ViewportMetrics metrics) {
    final tagRanges = <String, ScrollViewTagRange>{};
    for (final entry in metrics.tagRanges.entries) {
      final tag = entry.key;
      if (tag is String) {
        tagRanges[tag] = (top: entry.value.top, height: entry.value.height);
      }
    }
    model.setViewportMetrics(
      viewportRows: metrics.viewportRows,
      contentRows: metrics.contentRows,
      tagRanges: tagRanges,
    );
  }
}
