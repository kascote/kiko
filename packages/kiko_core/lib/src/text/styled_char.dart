import 'package:characters/characters.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

import '../style.dart';

const _nbsp = '\u{00A0}';
const _zwsp = '\u{200B}';

/// A single character with a style
@immutable
class StyledChar {
  /// The character
  final Characters char;

  /// The style
  final Style style;

  /// Create a new styled character
  StyledChar(String char, this.style) : char = char.characters;

  /// Check if the character is a whitespace
  bool isWhitespace() {
    return char.string == _zwsp || char.string == ' ' && char.string != _nbsp;
  }

  /// Retruns the character width in terminal characters.
  int get width => widthChars(char);

  /// Sets the style of the character and returns a new object
  StyledChar setStyle(Style other) => StyledChar(char.string, other);

  @override
  String toString() {
    return 'StyledChar($char, $style)';
  }

  @override
  bool operator ==(Object other) {
    if (other is StyledChar) {
      return char == other.char && style == other.style;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(StyledChar, char, style);
}
