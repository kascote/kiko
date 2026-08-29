import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

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
/// - `cursor`: true if the keyboard cursor is on this item (the current item)
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
/// itemBuilder: (item, index, (:cursor, :checked, :disabled)) =>
///     Line('${cursor ? '>' : ' '} $item'),
/// ```
typedef ItemState = ({bool checked, bool cursor, bool disabled});

// ═══════════════════════════════════════════════════════════
// STYLES
// ═══════════════════════════════════════════════════════════

/// ListView's anatomy: one nullable style slot per part.
///
/// A `null` slot is derived from the theme's tones by the rule below; a
/// non-null slot is the caller's exact style and wins verbatim, bypassing both
/// the derivation and the per-state `styleOverrides` map on `ListView`.
///
/// | slot           | derived default              | matrix source     |
/// | -------------- | ---------------------------- | ----------------- |
/// | `item`         | none (inherits the pane's ground)| —                 |
/// | `selectedItem` | `resolver.fill(selection)`   | selected × fill   |
/// | `cursorItem`   | `resolver.fill(cursor)` + bold | cursor × fill   |
/// | `loadingItem`  | `resolver.ink(muted)`        | anatomy-specific  |
/// | `placeholder`  | `resolver.ink(muted)`        | anatomy-specific  |
///
/// Per-row paint order is: `item` base, then `selectedItem` (a fill) if the
/// row is in the selection set, then `cursorItem` (a fill) if the keyboard
/// cursor is on it, then the disabled dim if the row is disabled — later layers
/// patch over earlier ones, so the cursor stays visible over a selected run and
/// disabled dims everything. There is no `indicator` slot: a ListView renders
/// no built-in glyph, so any marker is the caller's own `itemBuilder` content.
class ListViewStyle {
  /// Base row style (usually left null to inherit the pane's own fill).
  final Style? item;

  /// Rows in the selection set.
  final Style? selectedItem;

  /// The current item — the keyboard cursor position.
  final Style? cursorItem;

  /// The built-in dim run for an item whose page isn't held. A
  /// `loadingItemBuilder` on the view replaces the run, lines and style both.
  final Style? loadingItem;

  /// The empty-state line.
  final Style? placeholder;

  /// Creates a ListViewStyle.
  const ListViewStyle({
    this.item,
    this.selectedItem,
    this.cursorItem,
    this.loadingItem,
    this.placeholder,
  });
}

// ═══════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════

/// Emitted when execute an action in the current item
@immutable
class ListActivateEvent extends Cmd {
  /// Id of the list view model where confirm was triggered.
  final String id;

  /// Creates a ListActivateEvent.
  const ListActivateEvent(this.id);

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListActivateEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ListActivateEvent($id)';
}
