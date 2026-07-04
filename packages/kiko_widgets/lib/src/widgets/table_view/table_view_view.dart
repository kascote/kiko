import 'package:kiko/kiko.dart';

import 'table_renderer.dart';
import 'table_view_model.dart';

/// Builds a TableView as a plume node — the plume-native view for
/// [TableViewModel].
///
/// plume owns the outer frame: an optional [border] with [borderStyle] and edge
/// titles. The scrolling body is a custom node that fills the inner area and
/// paints the table's sticky header and its windowed rows through the plume
/// paint protocol. That row rendering — visible columns, truncation,
/// alignment, per-cell styling — is the table's own [TableRenderer] and is
/// reused here, so the plume port and the old widget draw identically. The
/// subtree root is stamped with the model id so a click routes back through
/// [Frame.hitId].
Node tableView({
  required TableViewModel model,
  required Theme theme,
  Map<WidgetState, Style>? styleOverrides,
  BorderType border = BorderType.none,
  Style borderStyle = const Style(),
  List<Line> topTitles = const <Line>[],
  List<Line> bottomTitles = const <Line>[],
}) {
  return box(
    border: border,
    borderStyle: borderStyle,
    topTitles: topTitles,
    bottomTitles: bottomTitles,
    child: _TableViewport(model: model, theme: theme, styleOverrides: styleOverrides),
  )..tag = model.id;
}

/// The self-painting body of a [tableView]: fills the space the box gives it and
/// paints the table through the plume `Surface`.
class _TableViewport extends Node {
  _TableViewport({required this.model, required this.theme, this.styleOverrides});

  final TableViewModel model;
  final Theme theme;
  final Map<WidgetState, Style>? styleOverrides;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) =>
      constraints.constrain(Size(constraints.maxW ?? 0, constraints.maxH ?? 0));

  @override
  void paintSelf(Surface surface) {
    final clip = surface.clipRect ?? rect;
    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    if (area.isEmpty) return;
    TableRenderer(model, theme, styleOverrides).paint(area, surface);
  }
}
