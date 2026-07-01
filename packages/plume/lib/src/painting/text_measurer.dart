import 'package:characters/characters.dart';

/// Measures how wide text renders on a cell grid.
///
/// This is the one place the engine needs to know how many cells a string
/// occupies. Backends inject a real measurer (a terminal one accounts for wide
/// glyphs); tests use [MonospaceMeasurer]. Width is the only backend-specific
/// primitive: line breaking lives in the `Text` widget, which needs the
/// per-cluster style tokens that a plain-string wrapper cannot carry.
// A single abstract member is intentional: this is the injection seam backends
// implement, not a candidate for a plain function typedef.
// ignore: one_member_abstracts
abstract class TextMeasurer {
  /// Allows subclasses to be `const`.
  const TextMeasurer();

  /// The display width of [text] in cells.
  ///
  /// Must be additive over grapheme clusters: the width of a string equals the
  /// sum of the widths of its clusters (as split by `text.characters`). The
  /// `Text` widget measures one cluster at a time and sums the results, so a
  /// measurer whose whole-string width disagreed with the per-cluster total
  /// would make text mis-measure lines while the whole-string width still
  /// looked right.
  int widthOf(String text);
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
