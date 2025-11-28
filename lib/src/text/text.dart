import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../buffer.dart';
import '../extensions/iterator.dart';
import '../extensions/string.dart';
import '../layout/alignment.dart';
import '../layout/rect.dart';
import '../style.dart';
import '../widgets/frame.dart';
import 'line.dart';
import 'span.dart';

/// A string split over one or more lines.
///
/// [Text] is used wherever text is displayed in the terminal and represents
/// one or more [Line]s of text. When a [Text] is rendered, each line is
/// rendered as a single line of text from top to bottom of the area. The text
/// can be styled and aligned.
@immutable
class Text implements Widget {
  /// The lines of text.
  final Iterable<Line> _lines;

  /// The style of the text.
  final Style style;

  /// The alignment of the text.
  final Alignment? alignment;

  /// Creates a new text widget.
  Text({required List<Line> lines, Style? style, this.alignment})
    : _lines = List.from(lines),
      style = style ?? const Style();

  /// Creates a new text widget from a raw string.
  Text.raw(String lines, {Style? style, this.alignment})
    : _lines = lines.lines().map((line) => Line.fromSpan(Span(content: line))),
      style = style != null ? const Style().patch(style) : const Style();

  // /// Creates a new text widget from a styled string.
  // factory Text.styled(String content, Style style) {
  //   return Text.raw(content, style: const Style().patch(style));
  // }

  /// Creates a new text widget from a list of lines.
  factory Text.fromLines(
    List<Line> lines, {
    Style? style,
    Alignment? alignment,
  }) => Text(
    lines: List.from(lines),
    style: style ?? const Style(),
    alignment: alignment ?? Alignment.left,
  );

  /// Gets the lines of text.
  Lines get lines => Lines(this);

  /// Returns the width of longest Text's line in `terminal` characters.
  ///
  /// `Terminal characters` refers to that some characters could be wider than
  /// others, like emojis or CJK characters. The width of a character is
  /// determined by the Unicode standard.
  int get width => _lines.fold(0, (acc, line) => math.max(acc, line.width));

  /// Returns how many lines the text has.
  int get height => _lines.length;

  /// Patches the style of the text.
  Text patchStyle(Style style) => copyWith(style: this.style.patch(style));

  /// Resets the style of the text.
  Text resetStyle() => patchStyle(const Style.reset());

  /// Add a [Text] to this Text as a set of lines
  Text add(Text text) => copyWith(
    lines: _lines.toList()..addAll(List.from(text.lines)),
  );

  /// Add a [Line] to this text
  Text addLine(Line line) => Text(
    lines: _lines.toList()..add(line),
    style: style,
    alignment: alignment,
  );

  /// Add a [Span] to this text. If the text is empty, a new line is created.
  /// Otherwise, the span is added to the last line.
  Text addSpan(Span span) {
    if (_lines.isEmpty) {
      return copyWith(lines: [Line.fromSpan(span)]);
    } else {
      return copyWith(lines: List.from(_lines)..last.add(span));
    }
  }

  @override
  void render(Rect area, Buffer buf) {
    final textArea = area.intersection(buf.area);
    buf.setStyle(textArea, style);

    for (final (line, lineArea) in _lines.zip(textArea.rows)) {
      line.renderWidthAlignment(lineArea, buf, alignment);
    }
  }

  /// Creates a copy of this Text but with the given fields replaced with the new values.
  Text copyWith({List<Line>? lines, Style? style, Alignment? alignment}) {
    return Text(
      lines: lines ?? List.from(_lines),
      style: style ?? this.style,
      alignment: alignment ?? this.alignment,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer()
      ..writeln(_lines.map((line) => line.toString()).join())
      ..writeln(style.toString())
      ..writeln(alignment.toString());
    return sb.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Text && style == other.style && alignment == other.alignment) {
      return const IterableEquality<Line>().equals(_lines, other.lines);
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Text, Object.hashAll(_lines), style, alignment);
}

/// An iterator over the Text's lines
class Lines extends Iterable<Line> {
  /// The text to iterate over
  final Text text;

  /// Creates a new Lines iterator:w
  Lines(this.text);

  @override
  Iterator<Line> get iterator => text._lines.iterator;
}
