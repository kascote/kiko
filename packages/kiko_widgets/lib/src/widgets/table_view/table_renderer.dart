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
  ///
  /// [measurer] measures text the way the frame paints it; pass the frame's own
  /// measurer so a cjk-configured frame sizes cells like it draws them.
  TableRenderer(this.model, this.theme, this.styleOverrides, {this.measurer = const TermUnicodeMeasurer()});

  /// The model containing table state.
  final TableViewModel model;

  /// Theme for deriving styles.
  final Theme theme;

  /// Optional per-state style overrides.
  final Map<WidgetState, Style>? styleOverrides;

  /// Measures text for painting, carried from the frame.
  final TextMeasurer measurer;

  /// Resolves the anatomy slots that derive from theme tones + state.
  late final _resolver = StyleResolver(theme);

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
        paintLine(
          surface,
          placeholder.patchStyle(_placeholderStyle()),
          x: area.x,
          y: area.y + headerHeight,
          width: area.width,
          measurer: measurer,
        );
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

      final isCursorRow = rowIdx == model.cursorRow;
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
        isCursorRow,
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
        paintLine(
          surface,
          Line.fromTexts([sep]).patchStyle(_separatorStyle()),
          x: x,
          y: y,
          width: sepWidth,
          measurer: measurer,
        );
        x += sepWidth;
      }

      final col = visibleCols[i];
      final style = _headerStyle();

      // Render header cell
      final line = _truncateLine(col.label, col.width, model.ellipsis);
      final aligned = _alignLine(line, col.width, col.alignment);
      paintLine(surface, aligned.patchStyle(style), x: x, y: y, width: col.width, measurer: measurer);

      x += col.width;
    }
  }

  /// Renders a loading placeholder row.
  void _renderLoadingRow(Surface surface, Rect area) {
    final line = (model.loadingIndicator ?? Line('Loading...')).patchStyle(_loadingRowStyle());
    paintLine(surface, line, x: area.x, y: area.y, width: area.width, measurer: measurer);
  }

  /// Renders a data row.
  ///
  /// Per-cell paint order is honest anatomy, not borrowed states: row base,
  /// then [_selectedRowStyle] (a fill) if the row is selected, then the
  /// crosshair washes ([_cursorRowStyle] always, [_cursorColumnStyle] only
  /// when [TableViewModel.showCrosshair] is on) if the cell is on the
  /// cursor's row/column, then [_cursorCellStyle] (a fill) if this is the
  /// exact cursor cell — patched last, so it wins outright. Each wash is a
  /// bg-only [Style], so [Style.patch] leaves whatever foreground the row (or
  /// a custom [TableColumn.render]) already painted untouched.
  void _renderRow(
    Surface surface,
    Rect area,
    Map<String, Object?> row,
    int rowIndex,
    List<TableColumn> visibleCols,
    bool isCursorRow,
    bool isSelected,
  ) {
    var x = area.x;
    final scrollCol = model.scrollCol;
    final sep = model.columnSeparator;
    final sepWidth = sep.width;

    for (var colIdx = 0; colIdx < visibleCols.length; colIdx++) {
      // Render separator before column (except first)
      if (colIdx > 0 && sepWidth > 0) {
        paintLine(
          surface,
          Line.fromTexts([sep]).patchStyle(_separatorStyle()),
          x: x,
          y: area.y,
          width: sepWidth,
          measurer: measurer,
        );
        x += sepWidth;
      }

      final col = visibleCols[colIdx];
      final value = row[col.field];

      final isCursorColumn = (scrollCol + colIdx) == model.cursorCol;
      final isCursorCell = isCursorRow && isCursorColumn;

      var style = col.style ?? model.styles.row ?? const Style();
      if (isSelected) style = style.patch(_selectedRowStyle());
      if (isCursorRow) style = style.patch(_cursorRowStyle());
      if (model.showCrosshair && isCursorColumn) style = style.patch(_cursorColumnStyle());
      if (isCursorCell) style = style.patch(_cursorCellStyle());

      // Build render context
      final ctx = CellRenderContext(
        value: value,
        row: row,
        rowIndex: rowIndex,
        colIndex: scrollCol + colIdx,
        column: col,
        isSelected: isSelected,
        isCursorRow: isCursorRow,
        isCursorCell: isCursorCell,
        totalCount: model.totalCount,
      );

      // Render cell content
      final line = col.render?.call(ctx) ?? _defaultRender(value, col);
      final truncated = _truncateLine(line, col.width, model.ellipsis);
      final aligned = _alignLine(truncated, col.width, col.alignment);
      paintLine(surface, aligned.patchStyle(style), x: x, y: area.y, width: col.width, measurer: measurer);

      x += col.width;
    }
  }

  // ─────────────────────────────────────────────
  // Anatomy — derived defaults, overridable per instance or per theme
  // ─────────────────────────────────────────────

  /// Sticky header text style.
  Style _headerStyle() => model.styles.header ?? Style(fg: theme.background.on, addModifier: Modifier.bold);

  /// Column separator glyph style.
  Style _separatorStyle() => model.styles.separator ?? theme.border.ink;

  /// Placeholder rows for data windowed out of the cache.
  Style _loadingRowStyle() => model.styles.loadingRow ?? theme.muted.ink;

  /// The empty-state line.
  Style _placeholderStyle() => model.styles.placeholder ?? theme.muted.ink;

  /// Rows in the selection set — `selected` × `fill`.
  Style _selectedRowStyle() =>
      model.styles.selectedRow ?? _resolver.resolve(null, const {WidgetState.selected}, overrides: styleOverrides);

  /// Crosshair row wash — `cursor` × `wash`.
  Style _cursorRowStyle() => model.styles.cursorRow ?? _resolveCursor(PaintClass.wash);

  /// Crosshair column wash — `cursor` × `wash`.
  Style _cursorColumnStyle() => model.styles.cursorColumn ?? _resolveCursor(PaintClass.wash);

  /// The cursor cell fill — `cursor` × `fill`.
  Style _cursorCellStyle() => model.styles.cursorCell ?? _resolveCursor(PaintClass.fill);

  Style _resolveCursor(PaintClass cls) =>
      _resolver.resolve(null, const {WidgetState.cursor}, cls: cls, overrides: styleOverrides);

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

    // Rebuild texts with truncation
    final texts = <Text>[];
    var remainingWidth = targetWidth;

    for (final text in line.texts) {
      if (remainingWidth <= 0) break;

      final textWidth = text.width;
      if (textWidth <= remainingWidth) {
        texts.add(text);
        remainingWidth -= textWidth;
      } else {
        // Truncate this text
        final truncated = _truncateText(text, remainingWidth);
        if (truncated != null) texts.add(truncated);
        remainingWidth = 0;
      }
    }

    // Add ellipsis
    texts.add(Text(ellipsis));
    return Line.fromTexts(texts, style: line.style);
  }

  /// Truncates a text run to fit within [maxWidth].
  Text? _truncateText(Text text, int maxWidth) {
    final content = text.content;
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
    return Text(truncated, style: text.style);
  }

  /// Aligns line content within [width].
  Line _alignLine(Line line, int width, TextAlign alignment) {
    final lineWidth = line.width;
    if (lineWidth >= width) return line;

    final padding = width - lineWidth;
    final (leftPad, rightPad) = switch (alignment) {
      TextAlign.start => (0, padding),
      TextAlign.center => (padding ~/ 2, padding - padding ~/ 2),
      TextAlign.end => (padding, 0),
    };

    final texts = <Text>[];
    if (leftPad > 0) texts.add(Text(' ' * leftPad));
    texts.addAll(line.texts);
    if (rightPad > 0) texts.add(Text(' ' * rightPad));

    return Line.fromTexts(texts, style: line.style);
  }
}
