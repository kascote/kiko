import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../extensions/string.dart';
import '../plume/aliases.dart';
import '../plume/text_flatten.dart';
import '../plume/view.dart';
import '../style.dart';
import 'styled_char.dart';
import 'text.dart';

/// A line of text, consisting of one or more [Text]s.
///
/// [Line]s are used wherever text is displayed in the terminal and represent a
/// single line of text. When a [Line] is rendered, it is rendered as a single
/// line of text, with each [Text] being rendered in order (left to right).
///
/// A [Line] is a view: it inflates to a fresh plume text node aligned at the
/// start. Where the line sits is decided by whatever lays it out.
///
/// Any newlines in the content are removed when creating a [Line] using the
/// constructor or conversion methods.
@immutable
class Line implements View {
  final Iterable<Text> _texts;

  /// The style of the line.
  final Style style;

  /// Creates a new [Line] with the given content and style.
  Line(String? content, {Style? style})
    : _texts = List<Text>.unmodifiable((content ?? '').lines().map<Text>(Text.new)),
      style = style ?? const Style();

  /// Creates a new [Line] from a list of [Text]s
  Line.fromTexts(List<Text> texts, {Style? style})
    : _texts = List<Text>.unmodifiable(texts),
      style = style ?? const Style();

  // Callers must pass an unmodifiable list so the Line stays immutable.
  const Line._(this._texts, this.style);

  /// Creates an empty Line
  factory Line.empty({Style? style}) => Line._(const [], style ?? const Style());

  /// Add a [Text] to the line
  Line add(Text text) => Line._(List<Text>.unmodifiable([..._texts, text]), style);

  /// Returns the width of the line in cells, as measured by [measurer]. This
  /// is the sum of the widths of all the [Text]s in the line.
  int width(TextMeasurer measurer) => _texts.fold(0, (acc, text) => acc + text.width(measurer));

  /// The [Text]s that make up this line, in order (left to right).
  ///
  /// The returned iterable is unmodifiable — a [Line] never changes after it
  /// is built.
  Iterable<Text> get texts => _texts;

  /// Returns an iterator over the graphemes held by this line.
  ///
  /// [baseStyle] is the [Style] that will be patched with each grapheme
  /// [Style] to get the resulting [Style].
  ///
  Iterable<StyledChar> styledChars(Style baseStyle) sync* {
    final newStyle = baseStyle.patch(style);
    for (final text in _texts) {
      yield* text.styledChars(newStyle);
    }
  }

  /// Patches the style of this Line, adding modifiers from the given style.
  ///
  /// This is useful for when you want to apply a style to a line that already
  /// has some styling. In contrast to [Line.style], this method will not
  /// overwrite the existing style, but instead will add the given style's
  /// modifiers to this Line's style.
  Line patchStyle(Style newStyle) => Line._(_texts, style.patch(newStyle));

  /// Patches this line's own style over [base], so the line wins.
  ///
  /// Use this where a widget cannot paint through `paintLine(base:)` and must
  /// build a [Line] that already carries the surrounding slot or state style
  /// underneath its own. It is the inverse of [patchStyle]: there, the
  /// argument wins; here, the line does.
  Line over(Style base) => Line._(_texts, base.patch(style));

  /// Resets the style of this Line to the default style.
  Line resetStyle() => Line._(_texts, style.patch(const Style.reset()));

  /// Creates a copy of this Line but with the given fields replaced with the new values.
  Line copyWith({List<Text>? texts, Style? style}) {
    return Line._(
      texts != null ? List<Text>.unmodifiable(texts) : _texts,
      style ?? this.style,
    );
  }

  @override
  Node build() => lineNode(this);

  @override
  String toString() {
    final sb = StringBuffer()
      ..writeln('Line(')
      ..writeln('  texts: $_texts,')
      ..writeln('  style: $style')
      ..writeln(')');
    return sb.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is Line) {
      if (style == other.style && _texts.length == other.texts.length) {
        return const IterableEquality<Text>().equals(_texts, other.texts);
      }
    }

    return false;
  }

  @override
  int get hashCode => Object.hash(Line, Object.hashAll(_texts), style);
}
