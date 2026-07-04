import 'package:characters/characters.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

import '../extensions/string.dart';
import '../layout/alignment.dart';
import '../style.dart';
import 'line.dart';
import 'styled_char.dart';

/// Represents a part of a line that is contiguous and where all characters
/// share the same style.
///
/// A [Text] is the smallest unit of text that can be styled. It is usually
/// combined in the [Line] type to represent a line of text where each `Text`
/// may have a different style
@immutable
class Text {
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

  /// Returns an iterator over the graphemes held by this span. Each grapheme
  /// is returned as a [StyledChar] with the style of the span.
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

  /// Returns a [Line] from the Text, with the alignment set to [Alignment.left]
  Line leftAlignedLine() => Line.fromSpan(this, alignment: Alignment.left);

  /// Returns a [Line] from the Text, with the alignment set to [Alignment.center]
  Line centerAlignedLine() => Line.fromSpan(this, alignment: Alignment.center);

  /// Returns a [Line] from the Text, with the alignment set to [Alignment.right]
  Line rightAlignedLine() => Line.fromSpan(this, alignment: Alignment.right);

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
