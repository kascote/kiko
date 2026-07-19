import 'package:characters/characters.dart';

import '../plume/aliases.dart';

/// Extension methods for the [Characters] class.
extension CharUtils on Characters {
  /// Returns a new string containing the last [length] cells of this string,
  /// as measured by [measurer].
  ///
  /// Truncation only ever keeps or drops a whole grapheme cluster — each
  /// cluster is measured (and included or excluded) as one unit, so a
  /// multi-codepoint character (an emoji with a skin-tone modifier, a flag)
  /// is never cut in half.
  ///
  /// - If [length] is greater than the width of this string, an empty string is returned.
  /// - If [length] is less than or equal to zero, an empty string is returned.
  ///
  /// Example:
  /// ```dart
  /// final text = 'Hello, World!'.characters;
  /// print(text.truncateStart(5, measurer)); // Output: 'orld!'
  /// ```
  String truncateStart(int length, TextMeasurer measurer) {
    final totalWidth = fold(0, (width, cluster) => width + measurer.widthOf(cluster));
    if (length > totalWidth) {
      return '';
    }

    var remaining = length;
    return takeLastWhile((cluster) {
      remaining -= measurer.widthOf(cluster);
      return remaining >= 0;
    }).string;
  }
}
