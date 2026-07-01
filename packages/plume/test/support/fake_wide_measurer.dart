import 'package:characters/characters.dart';
import 'package:plume/plume.dart';

/// A test measurer that gives East-Asian and emoji clusters a width of two
/// cells and everything else one.
///
/// It exercises the width seam the [MonospaceMeasurer] can't: every wrap, clip,
/// ellipsis and alignment path has to cope with a glyph that is wider than one
/// cell. Width is summed over grapheme clusters, so a mixed string measures the
/// same as the sum of its parts. The wide ranges are a coarse approximation of
/// the real East-Asian-Width tables — good enough to prove the seam, and
/// deliberately free of any terminal library.
class FakeWideMeasurer extends TextMeasurer {
  /// Creates a fake wide measurer.
  const FakeWideMeasurer();

  @override
  int widthOf(String text) {
    var total = 0;
    for (final cluster in text.characters) {
      total += _isWide(cluster) ? 2 : 1;
    }
    return total;
  }

  bool _isWide(String cluster) {
    if (cluster.isEmpty) {
      return false;
    }
    final code = cluster.runes.first;
    return (code >= 0x1100 && code <= 0x115F) || // Hangul Jamo
        (code >= 0x2E80 && code <= 0xA4CF) || // CJK, Kana, Yi
        (code >= 0xAC00 && code <= 0xD7A3) || // Hangul syllables
        (code >= 0xF900 && code <= 0xFAFF) || // CJK compatibility ideographs
        (code >= 0xFF00 && code <= 0xFF60) || // Fullwidth forms
        (code >= 0xFFE0 && code <= 0xFFE6) || // Fullwidth signs
        (code >= 0x1F300 && code <= 0x1FAFF); // Emoji and symbols
  }
}
