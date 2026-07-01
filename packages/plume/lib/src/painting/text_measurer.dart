import 'package:characters/characters.dart';

/// Measures text in grid cells, and wraps it to a width.
///
/// This is the one place the engine needs to know how wide a string renders.
/// Backends inject a real measurer (a terminal one accounts for wide glyphs);
/// tests use [MonospaceMeasurer]. Width is the only backend-specific part —
/// [wrap] is shared and defined in terms of [widthOf].
abstract class TextMeasurer {
  /// Allows subclasses to be `const`.
  const TextMeasurer();

  /// The display width of [text] in cells.
  int widthOf(String text);

  /// Breaks [text] into lines no wider than [maxWidth] cells.
  ///
  /// Explicit newlines force a break. Words are packed greedily; a single word
  /// wider than [maxWidth] is hard-broken across cells. A non-positive
  /// [maxWidth] returns the text unbroken (there is no width to wrap into).
  List<String> wrap(String text, int maxWidth) {
    final out = <String>[];
    for (final paragraph in text.split('\n')) {
      if (maxWidth <= 0 || widthOf(paragraph) <= maxWidth) {
        out.add(paragraph);
        continue;
      }
      var line = '';
      for (final word in paragraph.split(' ')) {
        final candidate = line.isEmpty ? word : '$line $word';
        if (widthOf(candidate) <= maxWidth) {
          line = candidate;
          continue;
        }
        if (line.isNotEmpty) {
          out.add(line);
        }
        line = word;
        while (widthOf(line) > maxWidth) {
          final head = _take(line, maxWidth);
          if (head.isEmpty) {
            break;
          }
          out.add(head);
          line = line.substring(head.length);
        }
      }
      out.add(line);
    }
    return out;
  }

  /// The longest prefix of [text] whose width does not exceed [maxWidth],
  /// cut only on grapheme-cluster boundaries.
  String _take(String text, int maxWidth) {
    final buffer = StringBuffer();
    var width = 0;
    for (final cluster in text.characters) {
      final w = widthOf(cluster);
      if (width + w > maxWidth) {
        break;
      }
      buffer.write(cluster);
      width += w;
    }
    return buffer.toString();
  }
}

/// A measurer that treats every grapheme cluster as exactly one cell wide.
///
/// Faithful for plain ASCII and a good, terminal-free default for tests; it does
/// not model wide (CJK/emoji) glyphs.
class MonospaceMeasurer extends TextMeasurer {
  /// Creates a monospace measurer.
  const MonospaceMeasurer();

  @override
  int widthOf(String text) => text.characters.length;
}
