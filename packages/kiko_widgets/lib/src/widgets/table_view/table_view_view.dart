import 'package:kiko/kiko.dart';

import 'table_renderer.dart';
import 'table_view_model.dart';

/// A TableView as a view — the plume-native view for [TableViewModel].
///
/// A [Box] owns the outer frame: an optional [border] with [borderStyle] and
/// edge titles. The scrolling body is a custom node that fills the inner area
/// and paints the table's sticky header and its windowed rows through the plume
/// paint protocol. That row rendering — visible columns, truncation,
/// alignment, per-cell styling — is the table's own [TableRenderer] and is
/// reused here, so the plume port and the old widget draw identically. The
/// built subtree is stamped with the model id so a click routes back through
/// [Frame.hitId].
final class TableView implements View {
  /// Creates a table view over [model], styled by [theme].
  const TableView({
    required this.model,
    required this.theme,
    this.styleOverrides,
    this.border = BorderType.none,
    this.borderStyle = const Style(),
    this.topTitles = const <Line>[],
    this.bottomTitles = const <Line>[],
  });

  /// The model whose columns, rows, cursor, and scroll this view renders.
  final TableViewModel model;

  /// The theme that resolves cell, header, and border styles.
  final Theme theme;

  /// Per-state style overrides applied on top of the theme's row styles.
  final Map<WidgetState, Style>? styleOverrides;

  /// The border drawn around the table, or [BorderType.none] for no border.
  final BorderType border;

  /// The colour and modifiers of the border glyphs.
  final Style borderStyle;

  /// The titles riding on the top edge of the border.
  final List<Line> topTitles;

  /// The titles riding on the bottom edge of the border.
  final List<Line> bottomTitles;

  @override
  Node build() => Box(
    border: border,
    borderStyle: borderStyle,
    topTitles: topTitles,
    bottomTitles: bottomTitles,
    child: NodeView(_TableViewport(model: model, theme: theme, styleOverrides: styleOverrides)),
  ).build()..tag = model.id;
}

/// The self-painting body of a [TableView]: fills the space the box gives it and
/// paints the table through the plume `Surface`.
class _TableViewport extends Node {
  _TableViewport({required this.model, required this.theme, this.styleOverrides});

  final TableViewModel model;
  final Theme theme;
  final Map<WidgetState, Style>? styleOverrides;

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
    final clip = surface.clipRect ?? rect;
    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    if (area.isEmpty) return;
    TableRenderer(model, theme, styleOverrides, measurer: _measurer).paint(area, surface);
  }
}
