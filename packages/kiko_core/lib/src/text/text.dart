import 'package:characters/characters.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

import '../extensions/string.dart';
import '../plume/aliases.dart';
import '../plume/text_flatten.dart';
import '../plume/view.dart';
import '../style.dart';
import 'styled_char.dart';

/// A styled run of text, and the smallest unit of text that can be styled.
///
/// A [Text] is a contiguous stretch of characters that all share one [style].
/// It is usually grouped into a `Line` to build a row where each run may carry
/// a different style, but a `Text` is also a view in its own right: standing
/// alone it is a one-run line.
///
/// As a view it inflates to a fresh plume text node aligned at the start;
/// where the run sits is decided by whatever lays it out.
@immutable
class Text implements View {
  final String _content;
  final Style _style;

  /// Creates a new Text with the given content and style.
  const Text(String content, {Style? style}) : _content = content, _style = style ?? const Style();

  /// Returns the style of the Text.
  Style get style => _style;

  /// Returns the content of the Text.
  String get content => _content;

  /// Patches the style of the Text, adding modifiers from the given style.
  Text patchStyle(Style style) => copyWith(style: _style.patch(style));

  /// Resets the style of the Text.
  Text resetStyle() => copyWith(style: _style.patch(const Style.reset()));

  /// Returns the width of the Text in `terminal` characters.
  ///
  /// `Terminal characters` refers to that some characters could be wider than
  /// others, like emojis or CJK characters. The width of a character is
  /// determined by the Unicode standard.
  int get width => widthString(_content);

  /// Returns an iterator over the graphemes held by this text. Each grapheme
  /// is returned as a [StyledChar] with the style of the text.
  /// The [baseStyle] passed is patched against the current Text.style
  Iterable<StyledChar> styledChars(Style baseStyle) sync* {
    final newStyle = baseStyle.patch(_style);
    for (final char in _content.characters) {
      if (char != '\n') {
        yield StyledChar(char, newStyle);
      }
    }
  }

  /// Returns a new Text with the given content.
  Text copyWith({String? content, Style? style}) {
    return Text(content ?? _content, style: style ?? _style);
  }

  @override
  Node build() => textNode(this);

  @override
  String toString() => 'Text(${_content.lines().join()}, $_style)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Text && runtimeType == other.runtimeType && _content == other._content && _style == other._style;
  }

  @override
  int get hashCode => Object.hash(Text, _content, _style);
}
