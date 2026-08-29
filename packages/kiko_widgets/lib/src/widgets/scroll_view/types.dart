// ═══════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════

/// Actions for ScrollView key bindings.
enum ScrollViewAction {
  /// Scroll up one content row.
  lineUp,

  /// Scroll down one content row.
  lineDown,

  /// Scroll up one viewport's worth of rows.
  pageUp,

  /// Scroll down one viewport's worth of rows.
  pageDown,

  /// Scroll to the first content row.
  top,

  /// Scroll to the last content row.
  bottom,
}

// ═══════════════════════════════════════════════════════════
// GEOMETRY
// ═══════════════════════════════════════════════════════════

/// A tagged descendant's row extent inside a ScrollView's content.
///
/// Both fields are content-relative — measured from the top of the content,
/// not the viewport — so a range stays the same as the viewport scrolls.
/// Reported by the view's paint each frame in a `ScrollMetrics`, so the
/// model reads it one frame behind.
typedef ScrollViewTagRange = ({int top, int height});

// ═══════════════════════════════════════════════════════════
// SCROLL STATE
// ═══════════════════════════════════════════════════════════

/// Scroll position info for external scrollbar.
class ScrollViewScrollState {
  /// The first visible content row.
  final int offset;

  /// How many rows the viewport shows.
  final int viewportRows;

  /// How many rows the content spans, whether or not they are all visible.
  final int contentRows;

  /// Creates a ScrollViewScrollState.
  const ScrollViewScrollState({
    required this.offset,
    required this.viewportRows,
    required this.contentRows,
  });

  /// Scroll progress 0.0-1.0.
  double get progress => contentRows <= viewportRows ? 0 : offset / (contentRows - viewportRows);

  /// Thumb size as a fraction 0.0-1.0.
  double get thumbSize => contentRows == 0 ? 1 : (viewportRows / contentRows).clamp(0.1, 1.0);
}
