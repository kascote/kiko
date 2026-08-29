import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import 'types.dart';

/// The geometry a scroll view painted: how many rows its viewport showed, how
/// many its content spans, and where every tagged descendant sits.
///
/// The view reports one from paint through `BufferSurface.report`, addressed
/// to the scroll view's id. The owner's `update` stores all three facts and
/// clamps its offset to the new extent; `ensureVisible` reads [tagRanges]
/// from the last report.
@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScrollMetrics &&
          other.id == id &&
          other.viewportRows == viewportRows &&
          other.contentRows == contentRows &&
          _sameRanges(other.tagRanges, tagRanges);

  @override
  int get hashCode => Object.hash(id, viewportRows, contentRows, tagRanges.length);

  @override
  String toString() =>
      'ScrollMetrics($id, viewportRows: $viewportRows, contentRows: $contentRows, tagRanges: $tagRanges)';

  static bool _sameRanges(Map<String, ScrollViewTagRange> a, Map<String, ScrollViewTagRange> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
