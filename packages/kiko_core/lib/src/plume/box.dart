import 'package:plume/plume.dart' as plume;

import '../style.dart';
import '../text/line.dart';
import '../widgets/border_type.dart';
import 'aliases.dart';
import 'paint_token.dart';
import 'view.dart';

/// A decorated box — kiko's framed container, the replacement for `Block`.
///
/// A [Box] draws a border and an optional background around a single [child]
/// view, with [topTitles] and [bottomTitles] riding on its edges. It is the
/// view wrapper over plume's [plume.BorderBox]: [build] maps kiko's own
/// vocabulary onto it — a [border] type and [borderStyle] become the one border
/// token, a non-empty [background] style becomes the fill, and each title line
/// becomes a label on its edge. Titles keep their multi-colour styling because
/// every title inflates through [Line.build] into a real text node.
///
/// Each title sits at the start of its edge; titles sharing an edge pack
/// together. The border is uniform — one type and colour for the whole box —
/// matching how the ported widgets frame their content.
final class Box implements View {
  /// Frames [child] with an optional border, background, padding, and titles.
  const Box({
    required this.child,
    this.border = BorderType.none,
    this.borderStyle = const Style(),
    this.background = const Style(),
    this.padding = plume.EdgeInsets.zero,
    this.topTitles = const <Line>[],
    this.bottomTitles = const <Line>[],
  });

  /// The framed child view.
  final View child;

  /// The border glyph set drawn around the box, or [BorderType.none] for no
  /// border.
  final BorderType border;

  /// The colour and modifiers of the border glyphs.
  final Style borderStyle;

  /// The fill painted behind the child, or an empty style for no fill.
  final Style background;

  /// Inner padding between the border and the child.
  final plume.EdgeInsets padding;

  /// The titles riding on the top edge, packed from the start.
  final List<Line> topTitles;

  /// The titles riding on the bottom edge, packed from the start.
  final List<Line> bottomTitles;

  @override
  Node build() {
    final borderToken = border == BorderType.none ? null : PaintToken(borderStyle, border: border.symbols);
    final backgroundToken = background == const Style() ? null : PaintToken(background);
    return plume.BorderBox<PaintToken>(
      child: child.build(),
      border: borderToken,
      background: backgroundToken,
      padding: padding,
      labels: <plume.EdgeLabel<PaintToken>>[
        for (final line in topTitles) _titleLabel(line, plume.EdgeSide.top),
        for (final line in bottomTitles) _titleLabel(line, plume.EdgeSide.bottom),
      ],
    );
  }

  /// Wraps a title [line] as an edge label at the start of [side].
  static plume.EdgeLabel<PaintToken> _titleLabel(Line line, plume.EdgeSide side) =>
      plume.EdgeLabel<PaintToken>(child: line.build(), side: side);
}
