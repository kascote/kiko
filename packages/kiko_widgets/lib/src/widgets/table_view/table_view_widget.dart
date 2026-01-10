import 'package:kiko/kiko.dart';
import 'package:termunicode/termunicode.dart';

import 'table_column.dart';
import 'table_view_model.dart';
import 'types.dart';

/// A table widget with keyboard navigation, selection, and async loading.
///
/// Renders tabular data from a [TableViewModel] with:
/// - Sticky or scrolling header
/// - Cell-level focus and selection
/// - Custom cell rendering per column
/// - Truncation and alignment
///
/// ```dart
/// TableView(model: tableModel).render(area, frame);
/// ```
class TableView extends Widget {
  /// The model containing table state.
  final TableViewModel model;

  /// Creates a TableView widget.
  TableView({required this.model});

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final renderArea = area.intersection(frame.buffer.area);
    if (renderArea.isEmpty) return;

    // Calculate visible columns that fit in area width
    final visibleCols = _getVisibleColumns(renderArea.width);
    if (visibleCols.isEmpty) return;

    final headerHeight = model.stickyHeader ? 1 : 0;
    final dataHeight = renderArea.height - headerHeight;
    if (dataHeight <= 0) return;

    // Update model's visible dimensions
    model.setVisibleDimensions(dataHeight, visibleCols.length);

    // 1. Render header (if sticky)
    if (model.stickyHeader) {
      _renderHeader(frame, renderArea, visibleCols);
    }

    // 2. Check for empty state
    final (loadedStart, loadedEnd) = model.loadedRange;
    if (loadedStart == loadedEnd && !model.isLoading) {
      if (model.emptyPlaceholder != null) {
        final emptyArea = Rect.create(
          x: renderArea.x,
          y: renderArea.y + headerHeight,
          width: renderArea.width,
          height: dataHeight,
        );
        model.emptyPlaceholder!.render(emptyArea, frame);
      }
      return;
    }

    // 3. Render visible rows
    final scrollRow = model.scrollRow;
    final endRow = (scrollRow + dataHeight).clamp(0, loadedEnd);

    for (var rowIdx = scrollRow; rowIdx < endRow; rowIdx++) {
      final row = model.getRow(rowIdx);
      final screenY = renderArea.y + headerHeight + (rowIdx - scrollRow);

      if (row == null) {
        // Render loading placeholder for missing row
        _renderLoadingRow(
          frame,
          Rect.create(
            x: renderArea.x,
            y: screenY,
            width: renderArea.width,
            height: 1,
          ),
        );
        continue;
      }

      final isHover = rowIdx == model.cursorRow;
      final isSelected = model.isSelected(rowIdx);

      _renderRow(
        frame,
        Rect.create(
          x: renderArea.x,
          y: screenY,
          width: renderArea.width,
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
  void _renderHeader(Frame frame, Rect area, List<TableColumn> visibleCols) {
    var x = area.x;
    final y = area.y;
    final sep = model.columnSeparator;
    final sepWidth = sep.width;

    for (var i = 0; i < visibleCols.length; i++) {
      // Render separator before column (except first)
      if (i > 0 && sepWidth > 0) {
        final sepArea = Rect.create(x: x, y: y, width: sepWidth, height: 1);
        Line.fromSpans([sep]).render(sepArea, frame);
        x += sepWidth;
      }

      final col = visibleCols[i];
      final cellArea = Rect.create(x: x, y: y, width: col.width, height: 1);

      // Determine header style
      final style = model.headerStyle ?? const Style();

      // Render header cell
      final line = _truncateLine(col.label, col.width, model.ellipsis);
      final aligned = _alignLine(line, col.width, col.alignment);
      aligned.patchStyle(style).render(cellArea, frame);

      x += col.width;
    }
  }

  /// Renders a loading placeholder row.
  void _renderLoadingRow(Frame frame, Rect area) {
    (model.loadingIndicator ?? Line('Loading...')).render(area, frame);
  }

  /// Renders a data row.
  void _renderRow(
    Frame frame,
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
        final sepArea = Rect.create(x: x, y: area.y, width: sepWidth, height: 1);
        Line.fromSpans([sep]).render(sepArea, frame);
        x += sepWidth;
      }

      final col = visibleCols[colIdx];
      final value = row[col.field];
      final cellArea = Rect.create(x: x, y: area.y, width: col.width, height: 1);

      // Style precedence: column highlight > selected > hover > column > default
      var style = model.rowStyle ?? const Style();
      if (col.style != null) style = col.style!;
      if (isHover && model.hoverStyle != null) style = model.hoverStyle!;
      if (isSelected && model.selectedStyle != null) style = model.selectedStyle!;

      // Column highlight for current cell (cursor row + cursor col)
      final isCursorCell = isHover && (scrollCol + colIdx) == model.cursorCol;
      if (isCursorCell && model.columnHighlight != null) {
        style = model.columnHighlight!;
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
      aligned.patchStyle(style).render(cellArea, frame);

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
