import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

import '../buffer.dart';
import '../extensions/characters.dart';
import '../extensions/integer.dart';
import '../extensions/string.dart';
import '../layout/alignment.dart';
import '../layout/rect.dart';
import '../style.dart';
import '../widgets/frame.dart';
import 'span.dart';
import 'styled_char.dart';

/// Helper record
typedef SpanRecord = (Span, int, int);

/// A line of text, consisting of one or more [Span]s.
///
/// [Line]s are used wherever text is displayed in the terminal and represent a
/// single line of text. When a [Line] is rendered, it is rendered as a single
/// line of text, with each [Span] being rendered in order (left to right).
///
/// Any newlines in the content are removed when creating a [Line] using the
/// constructor or conversion methods.
@immutable
class Line implements Widget {
  final Iterable<Span> _spans;

  /// The style of the line.
  final Style style;

  /// The alignment of the line.
  final Alignment? alignment;

  /// Creates a new [Line] with the given content, style, and alignment.
  Line({String? content, Style? style, this.alignment})
      : _spans = (content ?? '').lines().map<Span>((l) => Span(content: l)),
        style = style ?? const Style();

  /// Creates a new [Line] from a list of [Span]s
  Line.fromSpans(List<Span> spans, {Style? style, this.alignment})
      : _spans = List.from(spans),
        style = style ?? const Style();

  const Line._(this._spans, this.style, this.alignment);

  /// Creates a new [Line] from a single [Span]
  factory Line.fromSpan(Span span, {Style? style, Alignment? alignment}) => Line.fromSpans(
        [span],
        style: style,
        alignment: alignment,
      );

  /// Creates an empty Line
  factory Line.empty({Style? style, Alignment? alignment}) => Line._(const [], style ?? const Style(), alignment);

  /// Add a [Span] to the line
  Line add(Span span) => Line._(_spans.toList()..add(span), style, alignment);

  /// Returns the width of the line in `terminal` characters. This is the sum
  /// of the widths of all the [Span]s in the line.
  ///
  /// `Terminal characters` refers to that some characters could be wider than
  /// others, like emojis or CJK characters. The width of a character is
  /// determined by the Unicode standard.
  int get width => _spans.fold(0, (acc, span) => acc + span.width);

  /// Returns an Iterator over the [Span]s in this line.
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

  @override
  void render(Rect area, Buffer buf) => renderWidthAlignment(area, buf);

  /// Renders the line to the buffer, respecting the width of the area and the
  /// alignment of the line.
  void renderWidthAlignment(Rect area, Buffer buf, [Alignment? parentAlignment]) {
    final intArea = area.intersection(buf.area);
    if (intArea.isEmpty) return;

    final renderArea = intArea.copyWith(height: 1);
    final lineWidth = width;
    if (lineWidth == 0) return;

    buf.setStyle(renderArea, style);
    final areaWidth = renderArea.width;
    final canRenderCompleteLine = lineWidth <= areaWidth;
    final renderAlignment = alignment ?? parentAlignment;

    if (canRenderCompleteLine) {
      final indentWidth = switch (renderAlignment) {
        Alignment.left || null => 0,
        Alignment.center => areaWidth.saturatingSub(lineWidth) ~/ 2,
        Alignment.right => areaWidth.saturatingSub(lineWidth),
      };

      final areaA = renderArea.indentX(indentWidth);
      _renderSpans(areaA, buf, 0);
    } else {
      final skipWidth = switch (renderAlignment) {
        Alignment.left || null => 0,
        Alignment.center => lineWidth.saturatingSub(areaWidth) ~/ 2,
        Alignment.right => lineWidth.saturatingSub(areaWidth),
      };
      _renderSpans(renderArea, buf, skipWidth);
    }
  }

  void _renderSpans(Rect area, Buffer buf, int spanSkipWidth) {
    var spanArea = area.copyWith();
    for (final (span, spanWidth, offset) in _spanAfterWidth(_spans, spanSkipWidth)) {
      spanArea = spanArea.indentX(offset);
      if (spanArea.isEmpty) break;

      span.render(spanArea, buf);
      spanArea = spanArea.indentX(spanWidth);
    }
  }

  List<SpanRecord> _spanAfterWidth(Iterable<Span> spans, int skipWidth) {
    final records = <SpanRecord>[];
    var toSkip = skipWidth;

    return spans.fold(records, (acc, span) {
      final spanWidth = span.width;

      // Ignore spans that are completely before the offset. Decrement `spanSkipWidth` by
      // the span width until we find a span that is partially or completely visible.
      if (toSkip >= spanWidth) {
        toSkip = toSkip.saturatingSub(spanWidth);
        return acc;
      }

      // Apply the skip from the start of the span, not the end as the end will be trimmed
      // when rendering the span to the buffer
      final availableWidth = spanWidth.saturatingSub(toSkip);
      toSkip = 0; // ensure the next span is rendered in full

      if (spanWidth <= availableWidth) {
        // Span is fully visible.
        acc.add((span, spanWidth, 0));
        return acc;
      }

      // Span is only partially visible. As the end is truncated by the area width, only
      // truncate the start of the span.
      final contentTruncated = span.content.characters.truncateStart(availableWidth);
      final actualWidth = widthString(contentTruncated);
      final firstOffset = availableWidth.saturatingSub(actualWidth);
      acc.add((Span(content: contentTruncated, style: span.style), actualWidth, firstOffset));
      return acc;
    });
  }

  /// Creates a copy of this Line but with the given fields replaced with the new values.
  Line copyWith({List<Span>? spans, Style? style, Alignment? alignment}) {
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
        return const IterableEquality<Span>().equals(_spans, other.spans);
      }
    }

    return false;
  }

  @override
  int get hashCode => Object.hash(Line, Object.hashAll(_spans), style, alignment);
}

/// An iterator over the Line's spans.
class Spans extends Iterable<Span> {
  /// The line that this iterator is iterating over.
  final Line line;

  /// Creates a new iterator over the spans of the given line.
  Spans(this.line);

  @override
  Iterator<Span> get iterator => line._spans.iterator;
}
