/// Measurers that push on the width seam past what `FakeWideMeasurer` reaches.
///
/// `FakeWideMeasurer` only proves the "a glyph is two cells" case. These add the
/// three other shapes the layout has to survive: an indicator wider than one
/// cell, a cluster that takes no cells at all, and a glyph wider than a whole
/// small box. Most are additive — the width of a string is the sum of its
/// clusters' widths, the contract [Text] is built on — while
/// [NonAdditiveMeasurer] deliberately breaks that contract to pin what happens
/// when it is violated. Checking against *real* terminal widths (actual
/// ZWJ/flag/emoji tables) is a separate, conformance concern that belongs with
/// the production measurer, not here.
library;

import 'package:characters/characters.dart';
import 'package:plume/plume.dart';

/// Reports [indicatorWidth] cells for the ellipsis glyph `…` and one cell for
/// everything else.
///
/// This exercises the reservation math in `Text._ellipsize`, which subtracts the
/// measured indicator width from the budget rather than assuming one cell. With
/// a width-3 indicator a box narrower than the indicator drives the budget
/// negative — the latent edge the always-width-1 `…` never reaches.
class WideIndicatorMeasurer extends TextMeasurer {
  /// Creates a measurer whose ellipsis indicator is [indicatorWidth] cells wide.
  const WideIndicatorMeasurer([this.indicatorWidth = 3]);

  /// The cell width reported for the `…` glyph.
  final int indicatorWidth;

  @override
  int widthOf(String text) {
    var total = 0;
    for (final cluster in text.characters) {
      total += cluster == '…' ? indicatorWidth : 1;
    }
    return total;
  }
}

/// Reports zero cells for clusters that begin with a combining mark, a
/// zero-width space, or a zero-width joiner, and one cell otherwise.
///
/// A base-plus-mark cluster (`e` + U+0301) still measures one cell — its first
/// rune is the base — so the measurer stays additive: a lone mark is zero, an
/// attached one folds into its base. It exposes the zero-width path: a run whose
/// width is smaller than its cluster count, which naive `width == length` logic
/// would mishandle and a wrapper could loop on if it advanced by width.
class ZeroWidthMeasurer extends TextMeasurer {
  /// Creates a measurer that gives zero-width clusters no cells.
  const ZeroWidthMeasurer();

  @override
  int widthOf(String text) {
    var total = 0;
    for (final cluster in text.characters) {
      total += _isZeroWidth(cluster) ? 0 : 1;
    }
    return total;
  }

  bool _isZeroWidth(String cluster) {
    if (cluster.isEmpty) {
      return true;
    }
    final code = cluster.runes.first;
    return code == 0x200B || // zero-width space
        code == 0x200D || // zero-width joiner
        (code >= 0x0300 && code <= 0x036F); // combining diacritical marks
  }
}

/// Reports [glyphWidth] cells for a single designated [glyph] and one cell for
/// everything else.
///
/// With a width-5 glyph and a width-3 box, no line can ever hold the glyph:
/// hard-break cannot split it, clip and ellipsis must drop it whole, and the
/// wrapper must not spin. It proves a single cluster wider than the box degrades
/// sanely instead of overflowing or looping.
class OversizeGlyphMeasurer extends TextMeasurer {
  /// Creates a measurer where [glyph] is [glyphWidth] cells wide.
  const OversizeGlyphMeasurer(this.glyph, [this.glyphWidth = 5]);

  /// The single cluster that measures [glyphWidth] cells.
  final String glyph;

  /// The cell width reported for [glyph].
  final int glyphWidth;

  @override
  int widthOf(String text) {
    var total = 0;
    for (final cluster in text.characters) {
      total += cluster == glyph ? glyphWidth : 1;
    }
    return total;
  }
}

/// Reports one cell per cluster, plus one extra cell for any run of two or more
/// clusters — so `widthOf('aa')` is three, not two.
///
/// This deliberately violates the additivity precondition of [TextMeasurer].
/// [Text] measures clusters one at a time and trims to the box on that
/// per-cluster sum, so a run that fits per-cluster can still measure wider as a
/// whole and paint past the edge. It exists to pin that boundary, not to model a
/// real terminal. The safe, opposite direction (a measurer that under-counts the
/// whole run) would only make [Text] over-reserve space.
class NonAdditiveMeasurer extends TextMeasurer {
  /// Creates a non-additive measurer.
  const NonAdditiveMeasurer();

  @override
  int widthOf(String text) {
    final count = text.characters.length;
    if (count == 0) {
      return 0;
    }
    return count + (count >= 2 ? 1 : 0);
  }
}
