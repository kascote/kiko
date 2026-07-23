import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import 'table_column.dart';

// ═══════════════════════════════════════════════════════════
// HIT REGIONS
// ═══════════════════════════════════════════════════════════

/// The table's sticky header, marked as one region from day one.
///
/// A press on it declines and bubbles, exactly as it did before regions
/// existed; it exists now so a future column-sort feature hangs off the region
/// instead of new geometry, refining this one coarse header into per-column
/// header cells as a TableView-local change. It is not row-scoped — the header
/// is not a data row — so a model's row arm never mistakes it for one.
@immutable
class TableHeaderRegion implements Region {
  /// The sole header region for a table.
  const TableHeaderRegion();

  @override
  bool operator ==(Object other) => other is TableHeaderRegion;

  @override
  int get hashCode => (TableHeaderRegion).hashCode;

  @override
  String toString() => 'TableHeaderRegion()';
}

// ═══════════════════════════════════════════════════════════
// CELL RENDER CONTEXT
// ═══════════════════════════════════════════════════════════

/// Context passed to cell render callbacks.
///
/// Provides full access to cell value, row data, position, and state
/// for conditional rendering based on selection, cursor, or other columns.
class CellRenderContext {
  /// Cell value for this column.
  final Object? value;

  /// Full row data (access other columns).
  final Map<String, Object?> row;

  /// Global row index (0-based).
  final int rowIndex;

  /// Column index (0-based, visible columns only).
  final int colIndex;

  /// Column definition.
  final TableColumn column;

  /// Whether this row is selected.
  final bool isSelected;

  /// Whether cursor is on this row.
  final bool isCursorRow;

  /// Whether cursor is on this exact cell.
  final bool isCursorCell;

  /// Total row count, or null if unknown.
  final int? totalCount;

  /// Creates a CellRenderContext.
  const CellRenderContext({
    required this.value,
    required this.row,
    required this.rowIndex,
    required this.colIndex,
    required this.column,
    required this.isSelected,
    required this.isCursorRow,
    required this.isCursorCell,
    required this.totalCount,
  });
}

// ═══════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════

/// Actions for TableView key bindings.
enum TableViewAction {
  /// Move cursor up one row.
  up,

  /// Move cursor down one row.
  down,

  /// Move cursor left one column.
  left,

  /// Move cursor right one column.
  right,

  /// Move cursor up one page.
  pageUp,

  /// Move cursor down one page.
  pageDown,

  /// Move cursor to first loaded row.
  home,

  /// Move cursor to last loaded row.
  end,

  /// Move cursor to first column.
  firstCol,

  /// Move cursor to last column.
  lastCol,

  /// Toggle selection on current row.
  toggleSelect,

  /// Confirm current cell.
  confirm,
}

// ═══════════════════════════════════════════════════════════
// SCROLL STATE
// ═══════════════════════════════════════════════════════════

/// Scroll position info for external scrollbar.
class TableScrollState {
  /// Scroll offset (first visible row index).
  final int offset;

  /// Number of visible rows.
  final int visible;

  /// Total row count, or null if unknown.
  final int? total;

  /// Creates a TableScrollState.
  const TableScrollState({
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
// STYLES
// ═══════════════════════════════════════════════════════════

/// TableView's anatomy: one nullable style slot per part.
///
/// A `null` slot is derived from the theme's tones by the rule below; a
/// non-null slot is the caller's exact style and wins verbatim, bypassing
/// both the derivation and the per-state `styleOverrides` map on `TableView`.
///
/// | slot           | derived default                          | matrix source     |
/// | -------------- | ----------------------------------------- | ----------------- |
/// | `header`       | `Style(fg: theme.background.on)` + bold   | anatomy-specific  |
/// | `row`          | none (inherits the pane's own fill)       | —                 |
/// | `separator`    | `theme.border.ink`                        | resting chrome    |
/// | `selectedRow`  | `theme.selection.fill`                    | selected × fill   |
/// | `cursorRow`    | `theme.cursor.wash`                       | cursor × wash     |
/// | `cursorColumn` | `theme.cursor.wash`                       | cursor × wash     |
/// | `cursorCell`   | `theme.cursor.fill` + bold                | cursor × fill     |
/// | `loadingRow`   | `theme.muted.ink`                         | anatomy-specific  |
/// | `placeholder`  | `theme.muted.ink`                         | anatomy-specific  |
///
/// Per-cell paint order is: row base, then `selectedRow` (a fill), then
/// `cursorRow`/`cursorColumn` (washes — a bg-only patch that leaves each
/// cell's own foreground untouched), then `cursorCell` (a fill, which wins
/// outright since it patches last). The crosshair (`cursorColumn`) only
/// paints when `TableViewModel.showCrosshair` is true; a slot's presence
/// styles a part, it never turns on the behavior that paints it.
class TableViewStyle {
  /// Sticky header text.
  final Style? header;

  /// Base row style (usually left null to inherit the pane's own fill).
  final Style? row;

  /// Column separator glyphs.
  final Style? separator;

  /// Rows in the selection set.
  final Style? selectedRow;

  /// Crosshair: the current row, painted as a wash.
  final Style? cursorRow;

  /// Crosshair: the current column, painted as a wash.
  final Style? cursorColumn;

  /// The cursor cell (current row ∩ current column), painted as a fill.
  final Style? cursorCell;

  /// Placeholder rows for data windowed out of the cache.
  final Style? loadingRow;

  /// The empty-state line.
  final Style? placeholder;

  /// Creates a TableViewStyle.
  const TableViewStyle({
    this.header,
    this.row,
    this.separator,
    this.selectedRow,
    this.cursorRow,
    this.cursorColumn,
    this.cursorCell,
    this.loadingRow,
    this.placeholder,
  });
}

// ═══════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════

/// Emitted when an action is triggered on the table.
///
/// Built-in actions:
/// - `'primary'` - Enter key on current row
///
/// Custom actions can be added via keybindings.
@immutable
class TableActionCmd extends Cmd {
  /// Id of the table view model.
  final String id;

  /// Action name (e.g., 'primary' for Enter, or custom action name).
  final String action;

  /// Creates a TableActionCmd.
  const TableActionCmd(this.id, this.action);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TableActionCmd && other.id == id && other.action == action;

  @override
  int get hashCode => Object.hash(id, action);

  @override
  String toString() => 'TableActionCmd($id, $action)';
}
