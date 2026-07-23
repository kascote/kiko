import 'package:kiko/kiko.dart';

import '../scrollable_model.dart';
import 'types.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for ScrollView state and behavior.
///
/// Holds the scroll offset and the geometry the view measures every frame —
/// how many rows the viewport shows, how many the content spans, and every
/// tagged descendant's content-relative row range. Implements [Component]
/// (stable [id] + [update]) for addressing and focus.
///
/// The model owns no content and does no layout itself: `ScrollView` wraps a
/// plume viewport around whatever content the caller composes, and reports
/// each frame's geometry back through [setViewportMetrics] — the same
/// view-pushes-state-in back-channel pattern List and Tree use for
/// `visibleCount`. Unlike ListView, TableView and TreeView, this model is
/// never `Loadable`: it scrolls composed UI already fully in memory, not
/// paginated data (see kiko_widgets/CLAUDE.md's Async Loading section for the
/// data-scale widgets).
///
/// ```dart
/// final scroll = ScrollViewModel();
/// // ...
/// frame.render(ScrollView(model: scroll, child: someTallColumn));
/// ```
class ScrollViewModel with ScrollableModel implements Component {
  /// Stable address for this model.
  ///
  /// Auto-generated when omitted; pass an explicit id to match against a
  /// literal or to disambiguate multiple instances.
  @override
  final String id;

  /// Whether the scroll view is focused.
  ///
  /// Only the keyboard path is gated on it — the wheel scrolls whether or not
  /// the view is focused, matching every other scrollable widget.
  @override
  bool focused;

  /// Key bindings for scroll actions.
  late final KeyBinding<ScrollViewAction> keyBinding;

  /// Creates a ScrollViewModel.
  ///
  /// Pass a custom [keyBinding] to override the default key bindings.
  ScrollViewModel({String? id, this.focused = false, KeyBinding<ScrollViewAction>? keyBinding})
    : id = id ?? autoId('scrollview') {
    this.keyBinding = keyBinding ?? defaultScrollViewBindings.copy();
  }

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  int _scrollOffset = 0;
  int _viewportRows = 0;
  int _contentRows = 0;
  Map<String, ScrollViewTagRange> _tagRanges = const {};

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  /// Current scroll offset — the first visible content row.
  @override
  int get scrollOffset => _scrollOffset;

  /// Rows the viewport shows, as last pushed in by the view.
  int get viewportRows => _viewportRows;

  /// Rows the viewport shows — the shared scrollable surface's name for
  /// [viewportRows].
  @override
  int get visibleCount => viewportRows;

  /// How many rows the content spans, as last pushed in by the view.
  int get contentRows => _contentRows;

  int get _maxOffset {
    final over = _contentRows - _viewportRows;
    return over > 0 ? over : 0;
  }

  /// Moves the viewport by [rows], clamped to the content's own extent.
  /// Returns rows actually moved (see [ScrollableModel.scrollBy]).
  @override
  int scrollBy(int rows) {
    final before = _scrollOffset;
    _scrollOffset = (_scrollOffset + rows).clamp(0, _maxOffset);
    return _scrollOffset - before;
  }

  /// Called by the view during paint to install this frame's geometry: how
  /// many rows the viewport shows, how many the content spans, and every
  /// tagged descendant's content-relative row range.
  void setViewportMetrics({
    required int viewportRows,
    required int contentRows,
    required Map<String, ScrollViewTagRange> tagRanges,
  }) {
    _viewportRows = viewportRows;
    _contentRows = contentRows;
    _tagRanges = tagRanges;
    _scrollOffset = _scrollOffset.clamp(0, _maxOffset);
  }

  /// Brings the tagged descendant [id] fully into view, scrolling the
  /// minimum amount needed.
  ///
  /// A no-op when it is already fully visible; taller than the viewport
  /// top-aligns instead of centering. Does nothing when [id] is absent from
  /// the last measured frame — the one-frame lag makes absence transiently
  /// normal, so this declines to guess rather than scroll on stale geometry.
  ///
  /// Works for any tagged descendant, not just a focused one: scrolling to a
  /// validation error is the same call as scrolling to the focused field.
  void ensureVisible(String id) {
    final range = _tagRanges[id];
    if (range == null) return;
    if (range.height >= _viewportRows) {
      _scrollOffset = range.top;
    } else if (range.top < _scrollOffset) {
      _scrollOffset = range.top;
    } else if (range.top + range.height > _scrollOffset + _viewportRows) {
      _scrollOffset = range.top + range.height - _viewportRows;
    }
    _scrollOffset = _scrollOffset.clamp(0, _maxOffset);
  }

  /// Scroll position info for external scrollbar.
  ScrollViewScrollState getScrollState() =>
      ScrollViewScrollState(offset: _scrollOffset, viewportRows: _viewportRows, contentRows: _contentRows);

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  /// Handles keyboard and pointer messages. Returns [Handled] or [Declined].
  ///
  /// The pointer branch sits above the focus gate: a wheel scrolls whether or
  /// not the view is focused, per-direction declining a notch that moves
  /// nothing (already at that edge — see [ScrollableModel.scrollBy]'s
  /// contract), so a nesting scroll ancestor gets the chance. Every other
  /// pointer — clicks, hover, drags, a horizontal wheel, leave, cancel — is
  /// declined so it keeps resolving to the children composed inside. The
  /// keyboard path stays behind the gate, driven entirely by [keyBinding] —
  /// never a hardcoded key.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      if (pointer.wheelDeltaY != 0) {
        final moved = scrollBy(wheelScrollLines * pointer.wheelDeltaY);
        // Nothing moved in that direction (already at the edge) — decline so
        // a nesting scroll ancestor gets the notch; consuming at the limit
        // would make nesting permanently dead.
        if (moved == 0) return const Declined();
        return const Handled();
      }
      // Everything else — a horizontal wheel, a click, a hover, a drag —
      // passes through to whatever is composed inside.
      return const Declined();
    }
    if (msg is PointerLeaveMsg || msg is PointerCancelMsg) return const Declined();

    if (!focused) return const Declined();

    if (msg case KeyMsg()) {
      final action = keyBinding.resolve(msg);
      if (action == null) return const Declined();

      switch (action) {
        case ScrollViewAction.lineUp:
          scrollBy(-1);
        case ScrollViewAction.lineDown:
          scrollBy(1);
        case ScrollViewAction.pageUp:
          scrollBy(-(_viewportRows > 0 ? _viewportRows : 1));
        case ScrollViewAction.pageDown:
          scrollBy(_viewportRows > 0 ? _viewportRows : 1);
        case ScrollViewAction.top:
          scrollBy(-_contentRows);
        case ScrollViewAction.bottom:
          scrollBy(_contentRows);
      }

      return const Handled();
    }

    return const Declined();
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// Default key bindings for ScrollView.
final defaultScrollViewBindings = KeyBinding<ScrollViewAction>()
  ..map(['up', 'k'], ScrollViewAction.lineUp)
  ..map(['down', 'j'], ScrollViewAction.lineDown)
  ..map(['pageUp', 'ctrl+b'], ScrollViewAction.pageUp)
  ..map(['pageDown', 'ctrl+d'], ScrollViewAction.pageDown)
  ..map(['home', 'g'], ScrollViewAction.top)
  ..map(['end', 'G'], ScrollViewAction.bottom);
