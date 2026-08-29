import 'package:kiko/kiko.dart';

import 'scroll_metrics.dart';
import 'scroll_view_model.dart';
import 'types.dart';

/// A ScrollView as a view — the plume-native view for [ScrollViewModel].
///
/// Content area only: no built-in scrollbar, no border, no chrome — compose
/// those around it. Wraps [child] in the kiko_core [Viewport] bridge at
/// [ScrollViewModel.scrollOffset], and tags the viewport node itself with
/// [ScrollViewModel.id] — the content area IS the hit region, so a wheel over
/// a gap between composed children still resolves to the model, not the
/// background. Installs the measurement callback that reports the
/// viewport/content extents it painted as a [ScrollMetrics] addressed to the
/// model's hit path when they differ from what the model holds, the way every
/// windowed widget reports its viewport; the model reads them one frame
/// behind the paint.
///
/// Every tagged descendant's content-relative row range is keyed by its full
/// hit path: the scope path the paint walk carries down to this view
/// ([BufferSurface.scopePath]), then the descendant's ancestor chain inside
/// the content, folded by [HitTag.scopeUnder], then its own tag. A bare
/// member id and a scope wrapping chrome around that member key the same way
/// (see [ScrollViewModel.ensureVisible]). A tag outside the sealed [HitTag]
/// vocabulary is dropped, mirroring [HitMap]'s own rule that only that
/// vocabulary is addressable. A path repeated across several nodes — a scope
/// may legally sit on more than one — unions its rows: min top to max
/// bottom.
final class ScrollView implements View {
  /// Creates a scroll view over [model], showing [child]'s scrolled window.
  const ScrollView({required this.model, required this.child});

  /// The model whose offset drives this view and whose id every frame's
  /// geometry report is addressed to.
  final ScrollViewModel model;

  /// The scrollable content, laid out with its main axis unbounded.
  final View child;

  @override
  Node build() => Viewport(
    scrollOffset: model.scrollOffset,
    onMeasure: _onMeasure,
    child: child,
  ).build()..tag = IdTag(model.id);

  void _onMeasure(ViewportMetrics metrics, Surface surface) {
    if (surface is! BufferSurface) return;
    // The viewport's own scope path prefixes every key, so a key is the path
    // the hit map records for that descendant, not one relative to this view.
    final scopePath = surface.scopePath;
    final tagRanges = <String, ScrollViewTagRange>{};
    for (final entry in metrics.entries) {
      final path = _pathOf(entry.chain);
      if (path == null) continue;
      final range = (top: entry.top, height: entry.height);
      final key = HitTag.join(scopePath, path);
      final existing = tagRanges[key];
      tagRanges[key] = existing == null ? range : _union(existing, range);
    }
    // Report only while the model does not hold this geometry, so the frame
    // the report causes has nothing more to say.
    if (metrics.viewportRows == model.viewportRows &&
        metrics.contentRows == model.contentRows &&
        sameTagRanges(tagRanges, model.tagRanges)) {
      return;
    }
    surface.report(
      ScrollMetrics(
        HitTag.join(scopePath, model.id),
        viewportRows: metrics.viewportRows,
        contentRows: metrics.contentRows,
        tagRanges: tagRanges,
      ),
    );
  }

  /// Folds [chain] into a hit path relative to the viewport's content, or
  /// `null` when the node's own tag is outside the sealed [HitTag] vocabulary.
  ///
  /// A foreign ancestor tag is ignored, never fatal — [HitMap] walks past
  /// foreign tags the same way.
  static String? _pathOf(List<Object> chain) {
    if (chain.isEmpty) return null;
    final own = chain.last;
    if (own is! HitTag) return null;
    return HitTag.join(HitTag.scopePathOf(chain.take(chain.length - 1)), own.segment);
  }

  /// The envelope of two ranges on the same path: min top to max bottom.
  static ScrollViewTagRange _union(ScrollViewTagRange a, ScrollViewTagRange b) {
    final top = a.top < b.top ? a.top : b.top;
    final bottom = (a.top + a.height > b.top + b.height) ? a.top + a.height : b.top + b.height;
    return (top: top, height: bottom - top);
  }
}
