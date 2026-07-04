import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../extensions/string.dart';
import '../layout/alignment.dart';
import '../style.dart';
import 'styled_char.dart';
import 'text.dart';

/// A line of text, consisting of one or more [Text]s.
///
/// [Line]s are used wherever text is displayed in the terminal and represent a
/// single line of text. When a [Line] is rendered, it is rendered as a single
/// line of text, with each [Text] being rendered in order (left to right).
///
/// Any newlines in the content are removed when creating a [Line] using the
/// constructor or conversion methods.
@immutable
class Line {
  final Iterable<Text> _spans;

  /// The style of the line.
  final Style style;

  /// The alignment of the line.
  final Alignment? alignment;

  /// Creates a new [Line] with the given content, style, and alignment.
  Line(String? content, {Style? style, this.alignment})
    : _spans = (content ?? '').lines().map<Text>(Text.new),
      style = style ?? const Style();

  /// Creates a new [Line] from a list of [Text]s
  Line.fromSpans(List<Text> spans, {Style? style, this.alignment})
    : _spans = List.from(spans),
      style = style ?? const Style();

  const Line._(this._spans, this.style, this.alignment);

  /// Creates a new [Line] from a single [Text]
  factory Line.fromSpan(Text span, {Style? style, Alignment? alignment}) => Line.fromSpans(
    [span],
    style: style,
    alignment: alignment,
  );

  /// Creates an empty Line
  factory Line.empty({Style? style, Alignment? alignment}) => Line._(const [], style ?? const Style(), alignment);

  /// Add a [Text] to the line
  Line add(Text span) => Line._(_spans.toList()..add(span), style, alignment);

  /// Returns the width of the line in `terminal` characters. This is the sum
  /// of the widths of all the [Text]s in the line.
  ///
  /// `Terminal characters` refers to that some characters could be wider than
  /// others, like emojis or CJK characters. The width of a character is
  /// determined by the Unicode standard.
  int get width => _spans.fold(0, (acc, span) => acc + span.width);

  /// Returns an Iterator over the [Text]s in this line.
  Spans get spans => Spans(this);

  /// Returns an iterator over the graphemes held by this line.
  ///
  /// [baseStyle] is the [Style] that will be patched with each grapheme
  /// [Style] to get the resulting [Style].
  ///
  Iterable<StyledChar> styledChars(Style baseStyle) sync* {
    final newStyle = baseStyle.patch(style);
    for (final span in _spans) {
      yield* span.styledChars(newStyle);
    }
  }

  /// Patches the style of this Line, adding modifiers from the given style.
  ///
  /// This is useful for when you want to apply a style to a line that already
  /// has some styling. In contrast to [Line.style], this method will not
  /// overwrite the existing style, but instead will add the given style's
  /// modifiers to this Line's style.
  Line patchStyle(Style newStyle) => Line._(_spans, style.patch(newStyle), alignment);

  /// Resets the style of this Line to the default style.
  Line resetStyle() => Line._(_spans, style.patch(const Style.reset()), alignment);

  /// Creates a copy of this Line but with the given fields replaced with the new values.
  Line copyWith({List<Text>? spans, Style? style, Alignment? alignment}) {
    return Line._(
      spans ?? List.from(_spans),
      style ?? this.style,
      alignment ?? this.alignment,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer()
      ..writeln('Line(')
      ..writeln('  spans: $_spans,')
      ..writeln('  style: $style,')
      ..writeln('  alignment: $alignment')
      ..writeln(')');
    return sb.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is Line) {
      if (style == other.style && alignment == other.alignment && _spans.length == other.spans.length) {
        return const IterableEquality<Text>().equals(_spans, other.spans);
      }
    }

    return false;
  }

  @override
  int get hashCode => Object.hash(Line, Object.hashAll(_spans), style, alignment);
}

/// An iterator over the Line's spans.
class Spans extends Iterable<Text> {
  /// The line that this iterator is iterating over.
  final Line line;

  /// Creates a new iterator over the spans of the given line.
  Spans(this.line);

  @override
  Iterator<Text> get iterator => line._spans.iterator;
}
