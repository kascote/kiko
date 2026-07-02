import 'package:meta/meta.dart';

import '../style.dart';
import '../widgets/block/block.dart' show BorderSet;

/// The opaque paint token kiko hands to a plume layout tree.
///
/// Plume lays out geometry over a token type it never inspects, then hands each
/// token back at paint time (see plume's `Surface`). Kiko binds that type to
/// this and decodes it in `BufferSurface` — the one place a token becomes real
/// buffer cells.
///
/// The token bundles everything a widget needs painted, not only a style: a
/// [Style] for every cell's colors and modifiers, plus the [border] glyph set a
/// bordered box carries. A [Style] is therefore one *field* of the token, never
/// the token itself — the whole point of the seam is that the thing carried to
/// paint is more than a style as soon as borders (or later decoration) appear.
@immutable
class PaintToken {
  /// Creates a token that paints with [style] and, for a bordered box, [border].
  const PaintToken(this.style, {this.border});

  /// The colors and modifiers applied to every cell this token paints.
  final Style style;

  /// The box-drawing glyphs a border is drawn with, or `null` for a token that
  /// paints no border. Carried untouched until `BufferSurface` draws the border.
  final BorderSet? border;

  @override
  bool operator ==(Object other) => other is PaintToken && other.style == style && other.border == border;

  @override
  int get hashCode => Object.hash(style, border);

  @override
  String toString() => border == null ? 'PaintToken($style)' : 'PaintToken($style, border: $border)';
}
