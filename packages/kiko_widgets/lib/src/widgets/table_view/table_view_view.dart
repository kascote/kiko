import 'package:kiko/kiko.dart';

import 'table_renderer.dart';
import 'table_view_model.dart';
import 'types.dart';

/// A TableView as a view — the plume-native view for [TableViewModel].
///
/// This is the scrolling body on its own, with no frame around it: a custom node
/// that fills its area and paints the table's sticky header and its windowed rows
/// through the plume paint protocol. That row rendering — visible columns,
/// truncation, alignment, per-cell styling — is the table's own [TableRenderer]
/// and is reused here, so the plume port and the old widget draw identically.
/// [emptyPlaceholder] shows while the table holds zero rows, and a row whose
/// page has not landed paints as a column-shaped skeleton, or through
/// [pendingBuilder] when given. Wrap it in a [Container] for a border or edge
/// titles. The node is stamped with the model id so a click routes back
/// through [HitMap.hitId].
final class TableView implements View {
  /// Creates a table view over [model], styled by [theme].
  const TableView({
    required this.model,
    required this.theme,
    this.style = const TableViewStyle(),
    this.showCrosshair = false,
    this.emptyPlaceholder,
    this.pendingBuilder,
  });

  /// The model whose columns, rows, cursor, and scroll this view renders.
  final TableViewModel model;

  /// The theme that resolves cell, header, and row styles.
  final Theme theme;

  /// Row and chrome anatomy overrides. See [TableViewStyle].
  final TableViewStyle style;

  /// Paints the full crosshair: a wash across the cursor's column, in
  /// addition to the cursor row wash and cursor cell fill that always paint.
  ///
  /// Off by default, matching the table's look before the crosshair existed:
  /// only the cursor row and the cursor cell are highlighted.
  final bool showCrosshair;

  /// The line shown when the table holds zero rows, or `null` for a blank body.
  final Line? emptyPlaceholder;

  /// Builds the line for a row at a given index whose page has not landed,
  /// or `null` to paint the column-shaped skeleton instead.
  final Line Function(int index)? pendingBuilder;

  @override
  Node build() => _TableViewport(
    model: model,
    theme: theme,
    style: style,
    showCrosshair: showCrosshair,
    emptyPlaceholder: emptyPlaceholder,
    pendingBuilder: pendingBuilder,
  )..tag = IdTag(model.id);
}

/// The self-painting body of a [TableView]: fills the space the box gives it and
/// paints the table through the plume `Surface`.
class _TableViewport extends Node {
  _TableViewport({
    required this.model,
    required this.theme,
    required this.style,
    required this.showCrosshair,
    this.emptyPlaceholder,
    this.pendingBuilder,
  });

  final TableViewModel model;
  final Theme theme;
  final TableViewStyle style;
  final bool showCrosshair;
  final Line? emptyPlaceholder;
  final Line Function(int index)? pendingBuilder;

  // Captured from the layout context so paint measures text the way the frame
  // does — a cjk frame reaches the cells, not just the box chrome.
  TextMeasurer _measurer = const TermUnicodeMeasurer();

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    _measurer = context.measurer;
    return constraints.constrain(Size(constraints.maxW ?? 0, constraints.maxH ?? 0));
  }

  @override
  void paintSelf(Surface surface) {
    final clip = surface.clipRect;
    if (clip == null || clip.isEmpty) return;
    // Anchor at the placement rect, not the (possibly narrower) clip: a
    // clipping ancestor trims which cells actually draw, but the row/column
    // windowing must stay keyed to the widget's own laid-out size, or a
    // partially scrolled-off table pins its content to the viewport edge.
    final area = Rect.create(x: rect.x, y: rect.y, width: rect.width, height: rect.height);
    TableRenderer(
      model,
      theme,
      measurer: _measurer,
      style: style,
      showCrosshair: showCrosshair,
      emptyPlaceholder: emptyPlaceholder,
      pendingBuilder: pendingBuilder,
    ).paint(area, surface, mark: (region, r) => markRegion(region, r.toPlume()));
  }
}
