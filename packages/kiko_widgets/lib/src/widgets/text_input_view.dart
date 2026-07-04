import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:termunicode/termunicode.dart';

import 'text_input_model.dart';

/// Builds a single-line text input as a plume node — the plume-native view for
/// [TextInputModel].
///
/// A self-painting node: the placeholder when the input is empty, the obscure
/// character repeated when [TextInputModel.obscureText] is set, or the text
/// itself, horizontally scrolled to keep the cursor in view via
/// [TextInputModel.adjustScroll] (a plain box-plus-run form can't do this —
/// scrolling needs the actual on-screen width, known only at paint time), then
/// [TextInputModel.fillChar] repeated across whatever width is left. Styles
/// come from the [theme] and the model's focus state, with region styles
/// (placeholder, fill, obscured) from [TextInputStyle.fromTheme] merged with
/// the model's own. The subtree root is stamped with the model id so a click
/// routes back through [Frame.hitId]; the terminal cursor is reported through
/// the surface, the same way the `textArea` viewport does.
plume.RenderNode<PaintToken> textInput(TextInputModel model, Theme theme, {Map<WidgetState, Style>? styleOverrides}) =>
    _TextInputViewport(model: model, theme: theme, styleOverrides: styleOverrides)..tag = model.id;

/// The self-painting body of a [textInput]: fills the space the box gives it,
/// paints the field through the plume `Surface`, and reports the cursor.
class _TextInputViewport extends plume.RenderNode<PaintToken> {
  _TextInputViewport({required this.model, required this.theme, this.styleOverrides})
    : _regionStyle = TextInputStyle.fromTheme(theme).merge(model.style);

  final TextInputModel model;
  final Theme theme;
  final Map<WidgetState, Style>? styleOverrides;
  final TextInputStyle _regionStyle;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) =>
      constraints.constrain(plume.Size(constraints.maxW ?? 0, constraints.maxH ?? 0));

  @override
  void paintSelf(plume.Surface<PaintToken> surface) {
    final clip = surface.clipRect ?? rect;
    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    if (area.isEmpty) return;

    final cursor = _paint(area, surface);
    // Only the real BufferSurface has a terminal cursor to report — a
    // RecordingSurface (goldens) has nothing to carry it to.
    if (surface is BufferSurface) surface.cursor = cursor;
  }

  Position? _paint(Rect area, plume.Surface<PaintToken> surface) {
    final visibleWidth = area.width;
    final y = area.y;
    final m = model;

    final showPlaceholder = m.length == 0 && m.placeholder.isNotEmpty;
    int usedWidth;
    Position? cursor;

    if (showPlaceholder) {
      paintLine(
        surface,
        Line(m.placeholder, style: _regionStyle.placeholder),
        x: area.x,
        y: y,
        width: area.width,
      );
      usedWidth = widthString(m.placeholder).clamp(0, visibleWidth);
      if (m.focused) cursor = Position(area.x, y);
    } else {
      final (:displayText, :cursorDisplayPos, :scrollOffset) = m.adjustScroll(visibleWidth);

      final textStyle = m.obscureText ? (_regionStyle.obscured ?? _resolveStyle()) : _resolveStyle();
      paintLine(
        surface,
        Line(displayText.string, style: textStyle),
        x: area.x,
        y: y,
        width: area.width,
        skipColumns: scrollOffset,
      );

      final totalTextWidth = widthChars(displayText);
      usedWidth = (totalTextWidth - scrollOffset).clamp(0, visibleWidth);

      if (m.focused) {
        cursor = Position(area.x + (cursorDisplayPos - scrollOffset), y);
      }
    }

    // Fill remaining space with fillChar
    if (m.fillChar case final fillChar?) {
      // If maxLength is set, fill up to maxLength; otherwise fill visible width
      final targetWidth = m.maxLength != null ? m.maxLength!.clamp(0, visibleWidth) : visibleWidth;
      final remainingWidth = targetWidth - usedWidth;
      if (remainingWidth > 0) {
        final charWidth = widthString(fillChar);
        if (charWidth > 0) {
          final fillCount = remainingWidth ~/ charWidth;
          if (fillCount > 0) {
            paintLine(
              surface,
              Line(fillChar * fillCount, style: _regionStyle.fill),
              x: area.x + usedWidth,
              y: y,
              width: remainingWidth,
            );
          }
        }
      }
    }

    return cursor;
  }

  /// Resolves the input text style from the theme and the model's focus state.
  Style _resolveStyle() {
    final resolver = StyleResolver(theme);
    final states = <WidgetState>{if (model.focused) WidgetState.focused};
    return resolver.resolve(
      Style(fg: theme.background.fg),
      states,
      overrides: <WidgetState, Style>{...?styleOverrides},
    );
  }
}
