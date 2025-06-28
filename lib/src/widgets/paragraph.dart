import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart';

import '../buffer.dart';
import '../extensions/iterator.dart';
import '../layout/alignment.dart';
import '../layout/position.dart';
import '../layout/rect.dart';
import '../style.dart';
import '../text/line.dart';
import '../text/span.dart';
import '../text/text.dart';
import '../widgets/frame.dart';

/// Wrap definition
typedef Wrap = ({bool trim});

/// A widget to display some text.
///
/// It is used to display a block of text. The text can be styled and aligned.
/// It can also be wrapped to the next line if it is too long to fit in the
/// given area.
//TODO(nelson):
// - add cache support for the wrapped lines
// - add scroll support to show part of the paragraph
class Paragraph implements Widget {
  /// Widget style
  Style style;

  /// Wrap option
  Wrap wrap;

  /// The text to display
  Text text;
  Position _scroll;

  /// Alignment of the text
  Alignment alignment;

  /// Creates a new paragraph widget.
  Paragraph({
    required String content,
    this.style = const Style(),
    this.wrap = (trim: false),
    Position scroll = Position.origin,
    this.alignment = Alignment.left,
  })  : _scroll = scroll,
        text = Text.raw(content);

  /// Creates a paragraph from a [Text] object.
  factory Paragraph.withText(Text text) {
    return Paragraph(content: '')..text = text;
  }

  /// Sets the scroll position of the text.
  void setScroll(Offset scroll) => _scroll = Position(scroll.x, scroll.y);

  /// Gets the scroll position
  Position get scroll => _scroll;

  /// Get the longest line width of the text.
  int get lineWidth => text.width;

  /// Returns the number of lines that the text will be rendered in.
  /// This takes into account the width of the text, the width of the area and
  /// the wrap option.
  int lineCount(int width) {
    if (width < 1) return 0;
    if (!wrap.trim) return text.height;

    throw Exception('lineCount with Trim enabled is Not implemented yet');
  }

  bool _isSpace(String chr) => chr == ' ';

  // TODO(nelson): need to take care or the area height,
  // this is rendereing all the paragraph and when send to the buffer
  // the buffer height could be less than the lines wrapped.

  @override
  // void render(Rect area, Buffer buffer) {
  //   if (area.isEmpty) return;
  //
  //   buffer.setStyle(area, style);
  //   final wrappedLines = <Line>[];
  //
  //   for (final line in text.lines) {
  //     if (line.width <= area.width) {
  //       wrappedLines.add(line);
  //     } else {
  //       wrappedLines.addAll(_spanAtWidth(line.spans, area.width));
  //     }
  //   }
  //
  //   for (final (wl, row) in wrappedLines.zip(area.rows)) {
  //     wl.render(row, buffer);
  //   }
  // }
  //
  void render(Rect area, Buffer buffer) {
    if (area.isEmpty) return;

    buffer.setStyle(area, style);
    final wrappedLines = _wrapLines(text.lines, area.width);

    for (final (wl, row) in wrappedLines.zip(area.rows)) {
      wl.render(row, buffer);
    }
  }

  List<Line> _wrapLines(Lines lines, int areaWidth) {
    if (areaWidth <= 0) return [];

    final wrappedLines = <Line>[];
    for (final line in lines) {
      if (line.width <= areaWidth) {
        wrappedLines.add(line);
      } else {
        wrappedLines.addAll(_wrapSpansAtWidth(line.spans, areaWidth));
      }
    }
    return wrappedLines;
  }

  List<Line> _wrapSpansAtWidth(Spans spans, int lineWidth) {
    final wrappedLines = <Line>[];
    var currentLine = Line();
    final spanBuffer = StringBuffer();
    final wordBuffer = StringBuffer();
    var currentLineWidth = 0;

    void addCurrentSpan(Style style) {
      if (spanBuffer.isNotEmpty) {
        currentLine = currentLine.add(Span(content: spanBuffer.toString(), style: style));
        spanBuffer.clear();
      }
    }

    void startNewLine() {
      if (currentLine.width > 0) {
        wrappedLines.add(currentLine);
        currentLine = Line();
        currentLineWidth = 0;
      }
    }

    void addWordToLine(String word, Style style) {
      final wordWidth = widthString(word);

      // If this would overflow the line
      if (currentLineWidth + wordWidth > lineWidth) {
        // Add current span and start new line
        addCurrentSpan(style);
        startNewLine();

        // Add word to new span buffer
        spanBuffer.write(word);
        currentLineWidth = wordWidth;
      } else {
        // Add to current span
        spanBuffer.write(word);
        currentLineWidth += wordWidth;
      }
    }

    for (final span in spans) {
      final iterator = span.content.characters.iterator;

      while (iterator.moveNext()) {
        final char = iterator.current;

        if (_isSpace(char)) {
          if (wordBuffer.isNotEmpty) {
            final word = wordBuffer.toString();
            addWordToLine(word, span.style);
            wordBuffer.clear();
          }

          // Handle the space
          final spaceWidth = widthString(char);
          if (currentLineWidth + spaceWidth > lineWidth) {
            addCurrentSpan(span.style);
            startNewLine();
            // Don't carry over the space to new line
          } else {
            spanBuffer.write(char);
            currentLineWidth += spaceWidth;
          }
        } else {
          final charWidth = widthString(char);

          // If this single character won't fit on a line
          if (charWidth > lineWidth) {
            // Add current buffers and start new line
            if (wordBuffer.isNotEmpty) {
              addWordToLine(wordBuffer.toString(), span.style);
              wordBuffer.clear();
            }
            addCurrentSpan(span.style);
            startNewLine();

            // Add the character to a new line
            spanBuffer.write(char);
            currentLineWidth = charWidth;
          } else {
            wordBuffer.write(char);
          }
        }
      }

      // Handle any remaining word at end of span
      if (wordBuffer.isNotEmpty) {
        addWordToLine(wordBuffer.toString(), span.style);
        wordBuffer.clear();
      }

      // Add the span to current line
      addCurrentSpan(span.style);
    }

    // Add final line if not empty
    if (currentLine.width > 0) {
      wrappedLines.add(currentLine);
    }

    return wrappedLines;
  }
}
