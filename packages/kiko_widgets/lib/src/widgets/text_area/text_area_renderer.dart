import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:termunicode/termunicode.dart';

import 'selection.dart';
import 'text_area_model.dart';

/// Paints a [TextAreaModel] through a plume [Surface].
///
/// The rendering — wrapped lines, the line-number gutter, selection
/// highlighting, vertical scroll, and the placeholder — lives here so both the
/// plume `textArea` viewport and any other caller draw an editor the same
/// way. [paint] returns where the terminal cursor belongs when the model is
/// focused, or `null` — plume's `Surface` has no cursor concept of its own (no
/// terminal to blink one in), so reporting it back is the caller's job.
class TextAreaRenderer {
  /// Creates a renderer for [model], styled by [theme] and [styleOverrides].
  TextAreaRenderer(this.model, this.theme, this.styleOverrides)
    : _regionStyle = TextAreaStyle.fromTheme(theme).merge(model.style);

  /// The model containing state and config.
  final TextAreaModel model;

  /// Theme for deriving styles.
  final Theme theme;

  /// Optional per-state style overrides.
  final Map<WidgetState, Style>? styleOverrides;

  /// Region styles resolved at construction.
  final TextAreaStyle _regionStyle;

  /// Resolves the base text style from theme + model state.
  Style _resolveStyle() {
    final resolver = StyleResolver(theme);
    final states = <WidgetState>{
      if (model.focused) WidgetState.focused,
    };
    return resolver.resolve(
      Style(fg: theme.background.fg),
      states,
      overrides: {...?styleOverrides},
    );
  }

  /// Paints the editor into [area] of [surface], returning where the
  /// terminal cursor belongs when the model is focused, or `null`.
  Position? paint(Rect area, Surface surface) {
    if (area.isEmpty) return null;

    final m = model;
    final ta = m.textArea;

    // Calculate line number gutter width
    final gutterWidth = m.showLineNumbers ? _gutterWidth(ta.lineCount) : 0;
    final textAreaWidth = area.width - gutterWidth;

    if (textAreaWidth <= 0) return null;

    // Update visual width to match widget width (enables dynamic wrapping)
    ta.visualWidth = textAreaWidth;

    // Adjust scroll to keep cursor visible
    m.adjustScroll(area.height);

    // Show placeholder if empty
    if (ta.length() == 0 && m.placeholder.isNotEmpty) {
      return _renderPlaceholder(area, surface, gutterWidth);
    }

    // Render content
    return _renderContent(area, surface, gutterWidth, textAreaWidth);
  }

  Position? _renderPlaceholder(Rect area, Surface surface, int gutterWidth) {
    final textArea = area.copyWith(
      x: area.x + gutterWidth,
      width: area.width - gutterWidth,
    );
    paintLine(
      surface,
      Line(model.placeholder, style: _regionStyle.placeholder),
      x: textArea.x,
      y: textArea.y,
      width: textArea.width,
    );

    return model.focused ? Position(textArea.x, textArea.y) : null;
  }

  Position? _renderContent(
    Rect area,
    Surface surface,
    int gutterWidth,
    int textAreaWidth,
  ) {
    final m = model;
    final ta = m.textArea;

    var visualRow = 0; // tracks visual row across all buffer lines
    var screenY = 0; // current screen Y position
    Position? cursor;

    // Iterate through buffer lines
    for (var bufferRow = 0; bufferRow < ta.lineCount; bufferRow++) {
      final wrappedLines = ta.wrappedLines(bufferRow, bufferRow + 1).first;

      for (var wrapOffset = 0; wrapOffset < wrappedLines.length; wrapOffset++) {
        // Skip lines before scroll offset
        if (visualRow < m.scrollOffset) {
          visualRow++;
          continue;
        }

        // Stop if past visible area
        if (screenY >= area.height) break;

        final y = area.y + screenY;
        final line = wrappedLines[wrapOffset];

        // Render line number (only on first wrap of each buffer line)
        if (m.showLineNumbers) {
          _renderLineNumber(
            surface,
            area.x,
            y,
            gutterWidth,
            wrapOffset == 0 ? bufferRow + 1 : null,
          );
        }

        // Render text content
        final textX = area.x + gutterWidth;

        _renderLine(
          surface,
          Rect.create(x: textX, y: y, width: textAreaWidth, height: 1),
          line,
          bufferRow,
          wrapOffset,
        );

        // Position cursor if on this line
        if (m.focused && bufferRow == ta.row && wrapOffset == m.currentLineInfo.rowOffset) {
          final cursorX = textX + m.currentLineInfo.visualOffset;
          if (cursorX < textX + textAreaWidth) {
            cursor = Position(cursorX, y);
          }
        }

        screenY++;
        visualRow++;
      }

      if (screenY >= area.height) break;
    }

    return cursor;
  }

  void _renderLineNumber(
    Surface surface,
    int x,
    int y,
    int gutterWidth,
    int? lineNum,
  ) {
    final text = lineNum != null ? lineNum.toString().padLeft(gutterWidth - 1) : ' ' * (gutterWidth - 1);
    paintLine(
      surface,
      Line('$text ', style: _regionStyle.lineNumber),
      x: x,
      y: y,
      width: gutterWidth,
    );
  }

  void _renderLine(
    Surface surface,
    Rect area,
    Characters line,
    int bufferRow,
    int wrapOffset,
  ) {
    final ta = model.textArea;
    final parts = ta.selectedBlock.getLineParts(bufferRow, wrapOffset, line);

    final textStyle = _resolveStyle();

    if (parts == null || parts.isEmpty) {
      // No selection, render plain
      paintLine(
        surface,
        Line(line.string, style: textStyle),
        x: area.x,
        y: area.y,
        width: area.width,
      );
      return;
    }

    // Render with selection highlighting
    var x = area.x;
    for (final part in parts) {
      if (part.part.isEmpty) continue;

      final style = part.kind == PartKind.selection ? (_regionStyle.selection ?? const Style()) : textStyle;
      final partWidth = widthChars(part.part);

      paintLine(
        surface,
        Line(part.part.string, style: style),
        x: x,
        y: area.y,
        width: partWidth,
      );
      x += partWidth;
    }
  }

  int _gutterWidth(int lineCount) {
    // Width = digits + 1 space
    return lineCount.toString().length + 1;
  }
}
