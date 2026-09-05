import 'package:kiko/kiko.dart';

import 'types.dart';

/// Column definition for TableView.
class TableColumn {
  /// Key in row Map to get cell value.
  final String field;

  /// Header display (styled).
  final Line label;

  /// Column width in characters.
  final int width;

  /// Cell alignment (start/center/end).
  final TextAlign alignment;

  /// The cell style for this column, resolved at paint against the frame's
  /// [StyleResolver].
  ///
  /// The renderer patches the result over the table's `row` slot, then the
  /// states patch over that. A style that sets only a foreground keeps the
  /// row slot's background.
  final Style Function(StyleResolver resolver)? style;

  /// Whether column is visible.
  final bool visible;

  /// Optional render callback. Receives [CellRenderContext], returns Line.
  /// If null, uses value.toString() with alignment.
  ///
  /// Context provides access to:
  /// - `value`: cell value for this column
  /// - `row`: full row data (access other columns)
  /// - `rowIndex`: global row index
  /// - `colIndex`: column index (visible only)
  /// - `column`: this column definition
  /// - `isSelected`: row selection state
  /// - `isCursorRow`: cursor on this row
  /// - `isCursorCell`: cursor on this exact cell
  /// - `totalCount`: total rows (nullable)
  final Line Function(CellRenderContext ctx)? render;

  /// Creates a TableColumn.
  const TableColumn({
    required this.field,
    required this.label,
    this.width = 20,
    this.alignment = TextAlign.start,
    this.style,
    this.visible = true,
    this.render,
  });
}
