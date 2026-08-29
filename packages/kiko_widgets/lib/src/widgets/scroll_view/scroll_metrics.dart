import 'package:kiko/kiko.dart';

import 'types.dart';

/// The geometry a scroll view painted: how many rows its viewport showed, how
/// many its content spans, and where every tagged descendant sits.
///
/// The view reports one from paint through `BufferSurface.report`, addressed
/// to the scroll view's id. The owner's `update` stores all three facts and
/// clamps its offset to the new extent; `ensureVisible` reads [tagRanges]
/// from the last report.
class ScrollMetrics extends FrameReport {
  /// Creates a report that the scroll view registered under [id] showed
  /// [viewportRows] rows of [contentRows], with each tagged descendant's
  /// content-relative range in [tagRanges].
  const ScrollMetrics(super.id, {required this.viewportRows, required this.contentRows, required this.tagRanges});

  /// The rows the viewport showed.
  final int viewportRows;

  /// The rows the content spans, whether or not they were all visible.
  final int contentRows;

  /// Every tagged descendant's content-relative row range, keyed by its hit
  /// path.
  final Map<String, ScrollViewTagRange> tagRanges;
}
