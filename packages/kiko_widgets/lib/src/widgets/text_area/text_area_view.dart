import 'package:kiko/kiko.dart';

import 'text_area_model.dart';
import 'text_area_renderer.dart';
import 'types.dart';

/// A multi-line TextArea as a view — the plume-native view for [TextAreaModel].
///
/// This is the scrolling body on its own, with no frame around it: a custom node
/// that fills its area and paints the editor — wrapped lines, the line-number
/// gutter, selection, and the placeholder — through the plume paint protocol.
/// That rendering is the text area's own [TextAreaRenderer]. The terminal cursor
/// the editor asks for is carried back to the surface when painting through the
/// real `BufferSurface` (plume itself has no cursor concept). Wrap it in a
/// [Container] for a border or edge titles. The node is stamped with the model id so a click
/// routes back through [HitMap.hitId].
final class TextArea implements View {
  /// Creates a text area over [model], styled by [theme].
  const TextArea({
    required this.model,
    required this.theme,
    this.style = const TextAreaStyle(),
    this.styleOverrides,
  });

  /// The model whose text, cursor, selection, and scroll this view renders.
  final TextAreaModel model;

  /// The theme that resolves editor styles.
  final Theme theme;

  /// Region anatomy overrides. See [TextAreaStyle].
  final TextAreaStyle style;

  /// Per-state style overrides applied on top of the theme's editor styles.
  final Map<WidgetState, Style>? styleOverrides;

  @override
  Node build() =>
      _TextAreaViewport(model: model, theme: theme, style: style, styleOverrides: styleOverrides)
        ..tag = IdTag(model.id);
}

/// The self-painting body of a [TextArea]: fills the space the box gives it,
/// paints the editor through the plume `Surface`, and reports the cursor.
class _TextAreaViewport extends Node {
  _TextAreaViewport({required this.model, required this.theme, required this.style, this.styleOverrides});

  final TextAreaModel model;
  final Theme theme;
  final TextAreaStyle style;
  final Map<WidgetState, Style>? styleOverrides;

  // Captured from the layout context so paint measures text the way the frame
  // does — a cjk frame reaches the content, not just the box chrome.
  TextMeasurer _measurer = const TermUnicodeMeasurer();

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    _measurer = context.measurer;
    // The model does its own cursor/selection/wrap geometry during update,
    // where no layout context reaches it — hand it the same ruler paint uses
    // so that math never disagrees with what is on screen.
    model.measurer = context.measurer;
    return constraints.constrain(Size(constraints.maxW ?? 0, constraints.maxH ?? 0));
  }

  @override
  void paintSelf(Surface surface) {
    final clip = surface.clipRect;
    if (clip == null || clip.isEmpty) return;
    // Anchor at the placement rect, not the (possibly narrower) clip: a
    // clipping ancestor trims which cells actually draw, but the editor's own
    // wrap/scroll math must stay keyed to its laid-out size, or a partially
    // scrolled-off editor pins its content to the viewport edge.
    final area = Rect.create(x: rect.x, y: rect.y, width: rect.width, height: rect.height);

    final cursor = TextAreaRenderer(
      model,
      theme,
      styleOverrides,
      measurer: _measurer,
      style: style,
    ).paint(area, surface);
    // Only the real BufferSurface has a terminal cursor to report — a
    // RecordingSurface (goldens) has nothing to carry it to. Report only when
    // this editor owns the cursor (it is focused); an unfocused editor must not
    // write its null over a focused sibling's cursor earlier in the same frame.
    if (surface is BufferSurface && cursor != null) surface.placeCursor(cursor);
  }
}
