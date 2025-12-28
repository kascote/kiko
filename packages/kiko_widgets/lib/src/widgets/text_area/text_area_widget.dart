import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:termunicode/termunicode.dart';

import 'selection.dart';
import 'text_area_model.dart';

/// A multi-line text area widget with word wrapping.
///
/// Renders state from [TextAreaModel]. Supports:
/// - Word-boundary soft wrapping
/// - Optional line numbers
/// - Selection highlighting
/// - Vertical scrolling
class TextAreaWidget extends Widget {
  /// The model containing state and config.
  final TextAreaModel model;

  /// Creates a TextAreaWidget.
  TextAreaWidget(this.model);

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final renderArea = area.intersection(frame.buffer.area);
    if (renderArea.isEmpty) return;

    final m = model;
    final ta = m.textArea;

    // Calculate line number gutter width
    final gutterWidth = m.showLineNumbers ? _gutterWidth(ta.lineCount) : 0;
    final textAreaWidth = renderArea.width - gutterWidth;

    if (textAreaWidth <= 0) return;

    // Update visual width to match widget width (enables dynamic wrapping)
    ta.visualWidth = textAreaWidth;

    // Adjust scroll to keep cursor visible
    m.adjustScroll(renderArea.height);

    // Show placeholder if empty
    if (ta.length() == 0 && m.placeholder.isNotEmpty) {
      _renderPlaceholder(renderArea, frame, gutterWidth);
      return;
    }

    // Render content
    _renderContent(renderArea, frame, gutterWidth, textAreaWidth);
  }

  void _renderPlaceholder(Rect area, Frame frame, int gutterWidth) {
    final textArea = area.copyWith(
      x: area.x + gutterWidth,
      width: area.width - gutterWidth,
    );
    Span(model.placeholder, style: model.style.placeholder).render(textArea, frame);

    if (model.focused) {
      frame.cursorPosition = Position(textArea.x, textArea.y);
    }
  }

  void _renderContent(
    Rect area,
    Frame frame,
    int gutterWidth,
    int textAreaWidth,
  ) {
    final m = model;
    final ta = m.textArea;
    final buf = frame.buffer;

    var visualRow = 0; // tracks visual row across all buffer lines
    var screenY = 0; // current screen Y position

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
            buf,
            area.x,
            y,
            gutterWidth,
            wrapOffset == 0 ? bufferRow + 1 : null,
          );
        }

        // Render text content
        final textX = area.x + gutterWidth;
        final textRect = Rect.create(x: textX, y: y, width: textAreaWidth, height: 1);

        _renderLine(
          frame,
          textRect,
          line,
          bufferRow,
          wrapOffset,
        );

        // Position cursor if on this line
        if (m.focused && bufferRow == ta.row && wrapOffset == m.currentLineInfo.rowOffset) {
          final cursorX = textX + m.currentLineInfo.visualOffset;
          if (cursorX < textX + textAreaWidth) {
            frame.cursorPosition = Position(cursorX, y);
          }
        }

        screenY++;
        visualRow++;
      }

      if (screenY >= area.height) break;
    }
  }

  void _renderLineNumber(
    Buffer buf,
    int x,
    int y,
    int gutterWidth,
    int? lineNum,
  ) {
    final text = lineNum != null ? lineNum.toString().padLeft(gutterWidth - 1) : ' ' * (gutterWidth - 1);

    final lineRect = Rect.create(x: x, y: y, width: gutterWidth, height: 1);
    Span('$text ', style: model.style.lineNumber).render(
      lineRect,
      Frame(lineRect, buf, 0),
    );
  }

  void _renderLine(
    Frame frame,
    Rect area,
    Characters line,
    int bufferRow,
    int wrapOffset,
  ) {
    final ta = model.textArea;
    final parts = ta.selectedBlock.getLineParts(bufferRow, wrapOffset, line);

    final textStyle = model.style.text ?? const Style();

    if (parts == null || parts.isEmpty) {
      // No selection, render plain
      _renderSpan(frame, area, line.string, textStyle);
      return;
    }

    // Render with selection highlighting
    var x = area.x;
    for (final part in parts) {
      if (part.part.isEmpty) continue;

      final style = part.kind == PartKind.selection ? (model.style.selection ?? const Style()) : textStyle;
      final partWidth = widthChars(part.part);
      final partRect = Rect.create(x: x, y: area.y, width: partWidth, height: 1);

      _renderSpan(frame, partRect, part.part.string, style);
      x += partWidth;
    }
  }

  void _renderSpan(Frame frame, Rect area, String text, Style style) {
    Span(text, style: style).render(area, frame);
  }

  int _gutterWidth(int lineCount) {
    // Width = digits + 1 space
    return lineCount.toString().length + 1;
  }
}
