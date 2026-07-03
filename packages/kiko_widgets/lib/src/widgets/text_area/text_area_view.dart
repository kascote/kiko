import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

import 'text_area.dart';
import 'text_area_model.dart';

/// Builds a multi-line TextArea as a plume node — the plume-native view for
/// [TextAreaModel].
///
/// plume owns the outer frame: an optional [border] with [borderStyle] and edge
/// titles. The scrolling body is a custom node that fills the inner area and
/// paints the editor — wrapped lines, the line-number gutter, selection, and the
/// placeholder — through the plume paint protocol. That rendering is the text
/// area's own [TextAreaRenderer] and is reused here, so the plume port and the
/// old widget draw identically. The terminal cursor the editor asks for is
/// carried back to the surface when painting through the real `BufferSurface`
/// (plume itself has no cursor concept), and the subtree root is stamped with
/// the model id so a click routes back through [Frame.hitId].
plume.RenderNode<PaintToken> textArea(
  TextAreaModel model,
  Theme theme, {
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
    child: _TextAreaViewport(model: model, theme: theme, styleOverrides: styleOverrides),
  )..tag = model.id;
}

/// The self-painting body of a [textArea]: fills the space the box gives it,
/// paints the editor through the plume `Surface`, and reports the cursor.
class _TextAreaViewport extends plume.RenderNode<PaintToken> {
  _TextAreaViewport({required this.model, required this.theme, this.styleOverrides});

  final TextAreaModel model;
  final Theme theme;
  final Map<WidgetState, Style>? styleOverrides;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) =>
      constraints.constrain(plume.Size(constraints.maxW ?? 0, constraints.maxH ?? 0));

  @override
  void paintSelf(plume.Surface<PaintToken> surface) {
    final clip = surface.clipRect ?? rect;
    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    if (area.isEmpty) return;

    final cursor = TextAreaRenderer(model, theme, styleOverrides).paint(area, surface);
    // Only the real BufferSurface has a terminal cursor to report — a
    // RecordingSurface (goldens) has nothing to carry it to.
    if (surface is BufferSurface) surface.cursor = cursor;
  }
}
