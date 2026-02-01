import 'package:kiko/kiko.dart';

import 'table_column.dart';
import 'table_view_model.dart';

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
// LOAD DIRECTION
// ═══════════════════════════════════════════════════════════

/// Direction for loading more data.
enum LoadDirection {
  /// Load next page (cursor near end).
  forward,

  /// Load previous page (cursor near start).
  backward,
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

/// Style configuration for TableView.
class TableViewStyle {
  /// Header row style.
  final Style? header;

  /// Default row style.
  final Style? row;

  /// Current row (hover) style.
  final Style? hover;

  /// Selected rows style.
  final Style? selected;

  /// Current column highlight in current row.
  final Style? columnHighlight;

  /// Creates a TableViewStyle.
  const TableViewStyle({
    this.header,
    this.row,
    this.hover,
    this.selected,
    this.columnHighlight,
  });
}

// ═══════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════

/// Emitted when cursor nears edge of loaded data.
class TableLoadMoreCmd extends Cmd {
  /// The table view model that needs more data.
  final TableViewModel source;

  /// Direction to load (forward/backward).
  final LoadDirection direction;

  /// Creates a LoadPageCmd.
  const TableLoadMoreCmd(this.source, {required this.direction});
}

/// Emitted when an action is triggered on the table.
///
/// Built-in actions:
/// - `'primary'` - Enter key on current row
///
/// Custom actions can be added via keybindings.
class TableActionCmd extends Cmd {
  /// The table view model.
  final TableViewModel source;

  /// Action name (e.g., 'primary' for Enter, or custom action name).
  final String action;

  /// Creates a TableActionCmd.
  const TableActionCmd(this.source, this.action);
}
