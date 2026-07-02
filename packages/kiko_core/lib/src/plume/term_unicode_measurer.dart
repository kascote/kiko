import 'package:plume/plume.dart' show TextMeasurer;
import 'package:termunicode/termunicode.dart';

/// A plume [TextMeasurer] backed by `termunicode`, so layout sizes text exactly
/// as kiko renders it — wide (CJK/emoji) glyphs count as two cells, combining
/// marks as zero.
///
/// This is the production measurer; plume's tests use its `MonospaceMeasurer`.
/// It measures with the same [widthString] the buffer paints with, so layout
/// and paint never disagree about how wide a run is.
///
/// It satisfies plume's additivity precondition for free: [widthString] sums the
/// width of each grapheme cluster split by `String.characters` — the very split
/// plume's `Text` widget wraps on — so the width of a whole string always equals
/// the sum of the widths of its clusters.
class TermUnicodeMeasurer extends TextMeasurer {
  /// Creates a measurer.
  ///
  /// When [cjk] is true, ambiguous-width characters are treated as wide (two
  /// cells), matching a terminal configured for a Chinese/Japanese/Korean
  /// locale.
  const TermUnicodeMeasurer({this.cjk = false});

  /// Whether ambiguous-width characters count as two cells.
  final bool cjk;

  @override
  int widthOf(String text) => widthString(text, cjk: cjk);
}
