import 'package:kiko/kiko.dart';

import 'text_area_model.dart';
import 'text_area_renderer.dart';

/// A multi-line TextArea as a view — the plume-native view for [TextAreaModel].
///
/// A [Box] owns the outer frame: an optional [border] with [borderStyle] and
/// edge titles. The scrolling body is a custom node that fills the inner area
/// and paints the editor — wrapped lines, the line-number gutter, selection, and
/// the placeholder — through the plume paint protocol. That rendering is the
/// text area's own [TextAreaRenderer]. The terminal cursor the editor asks for
/// is carried back to the surface when painting through the real `BufferSurface`
/// (plume itself has no cursor concept), and the built subtree is stamped with
/// the model id so a click routes back through [Frame.hitId].
final class TextArea implements View {
  /// Creates a text area over [model], styled by [theme].
  const TextArea({
    required this.model,
    required this.theme,
    this.styleOverrides,
    this.border = BorderType.none,
    this.borderStyle = const Style(),
    this.topTitles = const <Line>[],
    this.bottomTitles = const <Line>[],
  });

  /// The model whose text, cursor, selection, and scroll this view renders.
  final TextAreaModel model;

  /// The theme that resolves editor and border styles.
  final Theme theme;

  /// Per-state style overrides applied on top of the theme's editor styles.
  final Map<WidgetState, Style>? styleOverrides;

  /// The border drawn around the editor, or [BorderType.none] for no border.
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
    child: NodeView(_TextAreaViewport(model: model, theme: theme, styleOverrides: styleOverrides)),
  ).build()..tag = model.id;
}

/// The self-painting body of a [TextArea]: fills the space the box gives it,
/// paints the editor through the plume `Surface`, and reports the cursor.
class _TextAreaViewport extends Node {
  _TextAreaViewport({required this.model, required this.theme, this.styleOverrides});

  final TextAreaModel model;
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

    final cursor = TextAreaRenderer(model, theme, styleOverrides).paint(area, surface);
    // Only the real BufferSurface has a terminal cursor to report — a
    // RecordingSurface (goldens) has nothing to carry it to.
    if (surface is BufferSurface) surface.cursor = cursor;
  }
}
