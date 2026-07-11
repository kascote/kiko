import 'package:kiko/kiko.dart';

import 'text_area_model.dart';
import 'text_area_renderer.dart';

/// A multi-line TextArea as a view — the plume-native view for [TextAreaModel].
///
/// This is the scrolling body on its own, with no frame around it: a custom node
/// that fills its area and paints the editor — wrapped lines, the line-number
/// gutter, selection, and the placeholder — through the plume paint protocol.
/// That rendering is the text area's own [TextAreaRenderer]. The terminal cursor
/// the editor asks for is carried back to the surface when painting through the
/// real `BufferSurface` (plume itself has no cursor concept). Wrap it in a [Box]
/// for a border or edge titles. The node is stamped with the model id so a click
/// routes back through [HitMap.hitId].
final class TextArea implements View {
  /// Creates a text area over [model], styled by [theme].
  const TextArea({
    required this.model,
    required this.theme,
    this.styleOverrides,
  });

  /// The model whose text, cursor, selection, and scroll this view renders.
  final TextAreaModel model;

  /// The theme that resolves editor styles.
  final Theme theme;

  /// Per-state style overrides applied on top of the theme's editor styles.
  final Map<WidgetState, Style>? styleOverrides;

  @override
  Node build() => _TextAreaViewport(model: model, theme: theme, styleOverrides: styleOverrides)..tag = model.id;
}

/// The self-painting body of a [TextArea]: fills the space the box gives it,
/// paints the editor through the plume `Surface`, and reports the cursor.
class _TextAreaViewport extends Node {
  _TextAreaViewport({required this.model, required this.theme, this.styleOverrides});

  final TextAreaModel model;
  final Theme theme;
  final Map<WidgetState, Style>? styleOverrides;

  // Captured from the layout context so paint measures text the way the frame
  // does — a cjk frame reaches the content, not just the box chrome.
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

    final cursor = TextAreaRenderer(model, theme, styleOverrides, measurer: _measurer).paint(area, surface);
    // Only the real BufferSurface has a terminal cursor to report — a
    // RecordingSurface (goldens) has nothing to carry it to. Report only when
    // this editor owns the cursor (it is focused); an unfocused editor must not
    // write its null over a focused sibling's cursor earlier in the same frame.
    if (surface is BufferSurface && cursor != null) surface.cursor = cursor;
  }
}
