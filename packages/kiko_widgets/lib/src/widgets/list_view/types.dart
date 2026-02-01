import 'package:kiko/kiko.dart';

import 'list_view_model.dart';

// ═══════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════

/// Actions for ListView key bindings.
enum ListViewAction {
  /// Move cursor up one item.
  up,

  /// Move cursor down one item.
  down,

  /// Move cursor to first item.
  first,

  /// Move cursor to last item.
  last,

  /// Move cursor up one page.
  pageUp,

  /// Move cursor down one page.
  pageDown,

  /// Toggle selection at cursor.
  toggleSelect,

  /// Confirm current selection/cursor.
  confirm,

  /// Extend selection upward (range select).
  selectUp,

  /// Extend selection downward (range select).
  selectDown,
}

// ═══════════════════════════════════════════════════════════
// SCROLL STATE
// ═══════════════════════════════════════════════════════════

/// Scroll position info for external scrollbar.
class ScrollState {
  /// Scroll offset (first visible item index).
  final int offset;

  /// Number of visible items.
  final int visible;

  /// Total item count, or null if unknown.
  final int? total;

  /// Creates a ScrollState.
  const ScrollState({
    required this.offset,
    required this.visible,
    required this.total,
  });

  /// Scroll progress 0.0-1.0, or null if total unknown.
  double? get progress {
    if (total == null || total! <= visible) return null;
    return offset / (total! - visible);
  }

  /// Thumb size as fraction 0.0-1.0, or null if total unknown.
  double? get thumbSize {
    if (total == null || total == 0) return null;
    return (visible / total!).clamp(0.1, 1.0);
  }
}

// ═══════════════════════════════════════════════════════════
// ITEM STATE
// ═══════════════════════════════════════════════════════════

/// State passed to itemBuilder for each item.
///
/// - `focused`: true if cursor is on this item
/// - `checked`: true if item is checked (multi-select only, requires
///   `multiSelect: true` on ListViewModel)
/// - `disabled`: true if item is disabled via `isDisabled` callback
///
/// Use `_` to ignore, or destructure what you need:
/// ```dart
/// // Ignore state
/// itemBuilder: (item, index, _) => Line(item),
///
/// // Use specific fields
/// itemBuilder: (item, index, (:focused, :checked, :disabled)) =>
///     Line('${focused ? '>' : ' '} $item'),
/// ```
typedef ItemState = ({bool checked, bool focused, bool disabled});

// ═══════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════

/// Emitted when cursor nears end and dataSource.hasMore is true.
class ListLoadMoreCmd<T, K> extends Cmd {
  /// The list view model that needs more data.
  final ListViewModel<T, K> source;

  /// Creates a LoadMoreCmd.
  const ListLoadMoreCmd(this.source);
}

/// Emitted when execute an action in the current item
class ListActionCmd<T, K> extends Cmd {
  /// The list view model where confirm was triggered.
  final ListViewModel<T, K> source;

  /// Creates a ListActionCmd.
  const ListActionCmd(this.source);
}
