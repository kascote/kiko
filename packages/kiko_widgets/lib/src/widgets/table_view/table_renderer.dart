import 'package:kiko/kiko.dart';
import 'package:termunicode/termunicode.dart';

import 'table_column.dart';
import 'table_view_model.dart';
import 'types.dart';

/// Paints a [TableViewModel] through a plume [Surface].
///
/// The rendering — visible columns, sticky header, windowed rows, per-cell
/// truncation, alignment, and state styling — lives here so both the plume
/// `tableView` viewport and any other caller draw a table the same way.
class TableRenderer {
  /// Creates a renderer for [model], styled by [theme] and [styleOverrides].
  TableRenderer(this.model, this.theme, this.styleOverrides);

  /// The model containing table state.
  final TableViewModel model;

  /// Theme for deriving styles.
  final Theme theme;

  /// Optional per-state style overrides.
  final Map<WidgetState, Style>? styleOverrides;

  /// Paints the table into [area] of [surface].
  void paint(Rect area, Surface surface) {
    if (area.isEmpty) return;

    // Calculate visible columns that fit in area width
    final visibleCols = _getVisibleColumns(area.width);
    if (visibleCols.isEmpty) return;

    final headerHeight = model.stickyHeader ? 1 : 0;
    final dataHeight = area.height - headerHeight;
    if (dataHeight <= 0) return;

    // Update model's visible dimensions
    model.setVisibleDimensions(dataHeight, visibleCols.length);

    // 1. Render header (if sticky)
    if (model.stickyHeader) {
      _renderHeader(surface, area, visibleCols);
    }

    // 2. Check for empty state
    final (loadedStart, loadedEnd) = model.loadedRange;
    if (loadedStart == loadedEnd && !model.isLoading()) {
      final placeholder = model.emptyPlaceholder;
      if (placeholder != null) {
        paintLine(surface, placeholder, x: area.x, y: area.y + headerHeight, width: area.width);
      }
      return;
    }

    // 3. Render visible rows
    final scrollRow = model.scrollRow;
    final endRow = (scrollRow + dataHeight).clamp(0, loadedEnd);

    for (var rowIdx = scrollRow; rowIdx < endRow; rowIdx++) {
      final row = model.getRow(rowIdx);
      final screenY = area.y + headerHeight + (rowIdx - scrollRow);

      if (row == null) {
        // Render loading placeholder for missing row
        _renderLoadingRow(
          surface,
          Rect.create(
            x: area.x,
            y: screenY,
            width: area.width,
            height: 1,
          ),
        );
        continue;
      }

      final isHover = rowIdx == model.cursorRow;
      final isSelected = model.isSelected(rowIdx);

      _renderRow(
        surface,
        Rect.create(
          x: area.x,
          y: screenY,
          width: area.width,
          height: 1,
        ),
        row,
        rowIdx,
        visibleCols,
        isHover,
        isSelected,
      );
    }
  }

  /// Gets visible columns that fit within [areaWidth].
  List<TableColumn> _getVisibleColumns(int areaWidth) {
    final cols = <TableColumn>[];
    var usedWidth = 0;
    final allVisible = model.columns.where((c) => c.visible).toList();
    final scrollCol = model.scrollCol;
    final sepWidth = model.columnSeparator.width;

    for (var i = scrollCol; i < allVisible.length; i++) {
      final col = allVisible[i];
      // Account for separator width (except before first column)
      final needsSep = cols.isNotEmpty;
      final totalWidth = col.width + (needsSep ? sepWidth : 0);
      if (usedWidth + totalWidth > areaWidth) break;
      cols.add(col);
      usedWidth += totalWidth;
    }
    return cols;
  }

  /// Renders the header row.
  void _renderHeader(Surface surface, Rect area, List<TableColumn> visibleCols) {
    var x = area.x;
    final y = area.y;
    final sep = model.columnSeparator;
    final sepWidth = sep.width;

    for (var i = 0; i < visibleCols.length; i++) {
      // Render separator before column (except first)
      if (i > 0 && sepWidth > 0) {
        paintLine(surface, Line.fromSpans([sep]), x: x, y: y, width: sepWidth);
        x += sepWidth;
      }

      final col = visibleCols[i];

      // Determine header style
      final style =
          model.styles.header ??
          Style(
            fg: theme.background.fg,
            addModifier: Modifier.bold,
          );

      // Render header cell
      final line = _truncateLine(col.label, col.width, model.ellipsis);
      final aligned = _alignLine(line, col.width, col.alignment);
      paintLine(surface, aligned.patchStyle(style), x: x, y: y, width: col.width);

      x += col.width;
    }
  }

  /// Renders a loading placeholder row.
  void _renderLoadingRow(Surface surface, Rect area) {
    paintLine(surface, model.loadingIndicator ?? Line('Loading...'), x: area.x, y: area.y, width: area.width);
  }

  /// Renders a data row.
  void _renderRow(
    Surface surface,
    Rect area,
    Map<String, Object?> row,
    int rowIndex,
    List<TableColumn> visibleCols,
    bool isHover,
    bool isSelected,
  ) {
    var x = area.x;
    final scrollCol = model.scrollCol;
    final sep = model.columnSeparator;
    final sepWidth = sep.width;

    for (var colIdx = 0; colIdx < visibleCols.length; colIdx++) {
      // Render separator before column (except first)
      if (colIdx > 0 && sepWidth > 0) {
        paintLine(surface, Line.fromSpans([sep]), x: x, y: area.y, width: sepWidth);
        x += sepWidth;
      }

      final col = visibleCols[colIdx];
      final value = row[col.field];

      // Resolve row style via StyleResolver
      final states = <WidgetState>{
        if (isHover) WidgetState.hover,
        if (isSelected) WidgetState.selected,
      };
      final resolver = StyleResolver(theme);
      var style = model.styles.row ?? const Style();
      if (col.style != null) style = col.style!;
      if (states.isNotEmpty) {
        style = resolver.resolve(style, states, overrides: styleOverrides);
      }

      // Column highlight for current cell (cursor row + cursor col)
      final isCursorCell = isHover && (scrollCol + colIdx) == model.cursorCol;
      if (isCursorCell) {
        style = resolver.resolve(style, {WidgetState.focused}, overrides: styleOverrides);
      }

      // Build render context
      final ctx = CellRenderContext(
        value: value,
        row: row,
        rowIndex: rowIndex,
        colIndex: scrollCol + colIdx,
        column: col,
        isSelected: isSelected,
        isCursorRow: isHover,
        isCursorCell: isCursorCell,
        totalCount: model.totalCount,
      );

      // Render cell content
      final line = col.render?.call(ctx) ?? _defaultRender(value, col);
      final truncated = _truncateLine(line, col.width, model.ellipsis);
      final aligned = _alignLine(truncated, col.width, col.alignment);
      paintLine(surface, aligned.patchStyle(style), x: x, y: area.y, width: col.width);

      x += col.width;
    }
  }

  /// Default cell rendering: converts value to string.
  Line _defaultRender(Object? value, TableColumn col) {
    return Line(value?.toString() ?? '');
  }

  /// Truncates a Line to fit within [maxWidth], adding ellipsis if needed.
  Line _truncateLine(Line line, int maxWidth, String ellipsis) {
    if (line.width <= maxWidth) return line;

    final ellipsisWidth = widthString(ellipsis);
    final targetWidth = maxWidth - ellipsisWidth;
    if (targetWidth <= 0) {
      return Line(ellipsis.substring(0, maxWidth.clamp(0, ellipsis.length)));
    }

    // Rebuild spans with truncation
    final spans = <Span>[];
    var remainingWidth = targetWidth;

    for (final span in line.spans) {
      if (remainingWidth <= 0) break;

      final spanWidth = span.width;
      if (spanWidth <= remainingWidth) {
        spans.add(span);
        remainingWidth -= spanWidth;
      } else {
        // Truncate this span
        final truncated = _truncateSpan(span, remainingWidth);
        if (truncated != null) spans.add(truncated);
        remainingWidth = 0;
      }
    }

    // Add ellipsis
    spans.add(Span(ellipsis));
    return Line.fromSpans(spans, style: line.style);
  }

  /// Truncates a span to fit within [maxWidth].
  Span? _truncateSpan(Span span, int maxWidth) {
    final content = span.content;
    final result = StringBuffer();
    var width = 0;

    for (final char in content.runes) {
      final charWidth = widthCp(char);
      if (width + charWidth > maxWidth) break;
      result.writeCharCode(char);
      width += charWidth;
    }

    final truncated = result.toString();
    if (truncated.isEmpty) return null;
    return Span(truncated, style: span.style);
  }

  /// Aligns line content within [width].
  Line _alignLine(Line line, int width, Alignment alignment) {
    final lineWidth = line.width;
    if (lineWidth >= width) return line;

    final padding = width - lineWidth;
    final (leftPad, rightPad) = switch (alignment) {
      Alignment.left => (0, padding),
      Alignment.center => (padding ~/ 2, padding - padding ~/ 2),
      Alignment.right => (padding, 0),
    };

    final spans = <Span>[];
    if (leftPad > 0) spans.add(Span(' ' * leftPad));
    spans.addAll(line.spans);
    if (rightPad > 0) spans.add(Span(' ' * rightPad));

    return Line.fromSpans(spans, style: line.style);
  }
}
