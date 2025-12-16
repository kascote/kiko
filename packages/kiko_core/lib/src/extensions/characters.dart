import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart';

/// Extension methods for the [Characters] class.
extension CharUtils on Characters {
  /// Returns a new string containing the last [length] characters of this string.
  ///
  /// - If [length] is greater than the length of this string, the entire string is returned.
  /// - If [length] is less than or equal to zero, an empty string is returned.
  ///
  /// Unicode characters (emoji) will take into account the width of the character on the terminal.
  ///
  /// Example:
  /// ```dart
  /// String text = 'Hello, World!';
  /// print(text.truncateStart(5)); // Output: 'orld!'
  /// ```
  String truncateStart(int length) {
    if (length > widthChars(this)) {
      return '';
    }

    var remaining = length;
    return takeLastWhile((char) {
      remaining -= widthCp(char.runes.first);
      return remaining >= 0;
    }).string;
  }
}
