import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../row_region.dart';
import 'table_column.dart';
import 'table_view_model.dart';
import 'types.dart';

/// Records that [region] was painted at [rect] — the seam a table's viewport
/// wires to its node's region store so marks are written by the same code that
/// paints the parts they name.
typedef RegionMark = void Function(Region region, Rect rect);

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
  ///
  /// [mark], when given, is called for each painted part with the region that
  /// names it and its absolute rect — the sticky header as a [TableHeaderRegion]
  /// and every data row as a [RowRegion] — so the caller's node records where
  /// its parts were painted. Marks are emitted in the same loop that computes
  /// the rects, so the geometry a pointer resolves against cannot drift from
  /// what was drawn.
  void paint(Rect area, Surface surface, {RegionMark? mark}) {
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
      mark?.call(const TableHeaderRegion(), Rect.create(x: area.x, y: area.y, width: area.width, height: headerHeight));
    }

    // 2. Check for empty state — the data itself is empty, not merely unloaded.
    // A table that knows its size (or has a page on its way) has rows to draw,
    // even before any of them arrive: they paint as skeletons below.
    if (model.rowLimit == 0) {
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
    //
    // The loop walks the viewport and paints a skeleton for any row whose page
    // isn't held, rather than stopping at the end of the loaded data. A viewport
    // sitting over a missing page then shows rows filling in, and recovers when
    // they land, instead of painting a blank body.
    //
    // While a fetch is in flight, though, the nearest rows the window holds
    // whole are better than a screen of skeletons: they keep the table readable
    // during a jump, and the chrome (getScrollState) still reports where the
    // cursor really is. Any other incomplete status falls back to skeletons, so
    // a fetch that never lands stops the view showing stale rows on its own —
    // no timer decides when.
    final scrollRow = model.viewportStatus == SliceStatus.filling
        ? model.nearestHeldStart(dataHeight) ?? model.scrollRow
        : model.scrollRow;
    final endRow = (scrollRow + dataHeight).clamp(0, model.rowLimit);

    for (var rowIdx = scrollRow; rowIdx < endRow; rowIdx++) {
      final row = model.getRow(rowIdx);
      final screenY = area.y + headerHeight + (rowIdx - scrollRow);
      final rowRect = Rect.create(x: area.x, y: screenY, width: area.width, height: 1);
      // Mark the row's painted rect in the same loop that paints it — a loading
      // placeholder still sits on its own row, so it is marked too.
      mark?.call(RowRegion(rowIdx), rowRect);

      if (row == null) {
        _renderLoadingRow(surface, rowRect, visibleCols);
        continue;
      }

      final isCursorRow = rowIdx == model.cursorRow;
      final isSelected = model.isSelected(rowIdx);
      final isHover = model.hoverRow == rowIdx;

      _renderRow(surface, rowRect, row, rowIdx, visibleCols, isCursorRow, isSelected, isHover);
    }
  }

  /// Gets visible columns that fit within [areaWidth].
  List<TableColumn> _getVisibleColumns(int areaWidth) {
    final cols = <TableColumn>[];
    var usedWidth = 0;
    final allVisible = model.columns.where((c) => c.visible).toList();
    final scrollCol = model.scrollCol;
    final sepWidth = model.columnSeparator.width(measurer);

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
    final sepWidth = sep.width(measurer);

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

  /// Renders the placeholder for a row whose page isn't held.
  ///
  /// By default it is a skeleton: the row's own shape — its columns and
  /// separators — with a dim run standing in for each cell. Forty rows each
  /// reading "Loading..." are unreadable at scrolling speed and look like a
  /// fault; the same rows as column-shaped runs read as filling in. A caller
  /// that wants a literal line back sets [TableViewModel.loadingIndicator].
  void _renderLoadingRow(Surface surface, Rect area, List<TableColumn> visibleCols) {
    final style = _loadingRowStyle();
    final indicator = model.loadingIndicator;
    if (indicator != null) {
      paintLine(surface, indicator.patchStyle(style), x: area.x, y: area.y, width: area.width, measurer: measurer);
      return;
    }

    var x = area.x;
    final sep = model.columnSeparator;
    final sepWidth = sep.width(measurer);
    for (var i = 0; i < visibleCols.length; i++) {
      if (i > 0 && sepWidth > 0) {
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
      final col = visibleCols[i];
      // Short of the full width, so the run reads as content pending rather
      // than as a filled cell.
      final runWidth = col.width <= 2 ? col.width : (col.width * 3) ~/ 4;
      paintLine(
        surface,
        Line('░' * runWidth).patchStyle(style),
        x: x,
        y: area.y,
        width: col.width,
        measurer: measurer,
      );
      x += col.width;
    }
  }

  /// Renders a data row.
  ///
  /// Per-cell paint order is honest anatomy, not borrowed states: row base,
  /// then the [_hoverRowStyle] wash (weakest, so selection/cursor read over
  /// it) if the row is hovered, then [_selectedRowStyle] (a fill) if the row is
  /// selected, then the crosshair washes ([_cursorRowStyle] always,
  /// [_cursorColumnStyle] only when [TableViewModel.showCrosshair] is on) if the
  /// cell is on the cursor's row/column, then [_cursorCellStyle] (a fill) if this
  /// is the exact cursor cell — patched last, so it wins outright. Each wash is a
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
    bool isHover,
  ) {
    var x = area.x;
    final scrollCol = model.scrollCol;
    final sep = model.columnSeparator;
    final sepWidth = sep.width(measurer);

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
      if (isHover) style = style.patch(_hoverRowStyle());
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

  /// Sticky header text style: bold, over whatever ground the pane painted.
  Style _headerStyle() => model.styles.header ?? const Style(addModifier: Modifier.bold);

  /// Column separator glyph style.
  Style _separatorStyle() => model.styles.separator ?? _resolver.ink(_resolver.tones.border);

  /// Placeholder rows for data windowed out of the cache.
  Style _loadingRowStyle() => model.styles.loadingRow ?? _resolver.ink(_resolver.tones.muted);

  /// The empty-state line.
  Style _placeholderStyle() => model.styles.placeholder ?? _resolver.ink(_resolver.tones.muted);

  /// The hovered row — `hover` × `wash`. A bg-only wash (hover resolves for no
  /// other paint class), so it tints the row without clobbering its foreground.
  /// No anatomy slot: hover is a generic state, not a TableView-specific part.
  Style _hoverRowStyle() =>
      _resolver.resolve(null, const {WidgetState.hover}, cls: PaintClass.wash, overrides: styleOverrides);

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
    if (line.width(measurer) <= maxWidth) return line;

    final ellipsisWidth = measurer.widthOf(ellipsis);
    final targetWidth = maxWidth - ellipsisWidth;
    if (targetWidth <= 0) {
      return Line(ellipsis.substring(0, maxWidth.clamp(0, ellipsis.length)));
    }

    // Rebuild texts with truncation
    final texts = <Text>[];
    var remainingWidth = targetWidth;

    for (final text in line.texts) {
      if (remainingWidth <= 0) break;

      final textWidth = text.width(measurer);
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
  ///
  /// Walks grapheme clusters rather than codepoints, so a multi-codepoint
  /// character (an emoji with a skin-tone modifier, a flag) is kept or
  /// dropped as one unit — truncation never cuts one in half.
  Text? _truncateText(Text text, int maxWidth) {
    final result = StringBuffer();
    var width = 0;

    for (final cluster in text.content.characters) {
      final clusterWidth = measurer.widthOf(cluster);
      if (width + clusterWidth > maxWidth) break;
      result.write(cluster);
      width += clusterWidth;
    }

    final truncated = result.toString();
    if (truncated.isEmpty) return null;
    return Text(truncated, style: text.style);
  }

  /// Aligns line content within [width].
  Line _alignLine(Line line, int width, TextAlign alignment) {
    final lineWidth = line.width(measurer);
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
