import 'package:plume/plume.dart' as plume;

import '../layout/alignment.dart';
import '../style.dart';
import '../text/line.dart';
import '../widgets/border_type.dart';
import 'paint_token.dart';
import 'text_flatten.dart';

/// Builds a decorated box as a plume node — kiko's replacement for `Block`.
///
/// This wraps plume's [plume.BorderBox], mapping kiko's own vocabulary onto it:
/// a [border] type and [borderStyle] become the one border token, a non-empty
/// [background] style becomes the fill, and each title `Line` becomes a label on
/// its edge. Titles keep their multi-colour styling because every title flattens
/// through [lineNode] into a real text node.
///
/// A title's own [Line.alignment] decides where it sits along its edge; several
/// titles sharing an edge and alignment pack together. The border is uniform —
/// one type and colour for the whole box — matching how the ported widgets frame
/// their content.
plume.RenderNode<PaintToken> box({
  required plume.RenderNode<PaintToken> child,
  BorderType border = BorderType.none,
  Style borderStyle = const Style(),
  Style background = const Style(),
  plume.EdgeInsets padding = plume.EdgeInsets.zero,
  List<Line> topTitles = const <Line>[],
  List<Line> bottomTitles = const <Line>[],
}) {
  final borderToken = border == BorderType.none ? null : PaintToken(borderStyle, border: border.symbols(border));
  final backgroundToken = background == const Style() ? null : PaintToken(background);
  final labels = <plume.EdgeLabel<PaintToken>>[
    for (final line in topTitles) _titleLabel(line, plume.EdgeSide.top),
    for (final line in bottomTitles) _titleLabel(line, plume.EdgeSide.bottom),
  ];

  return plume.BorderBox<PaintToken>(
    child: child,
    border: borderToken,
    background: backgroundToken,
    padding: padding,
    labels: labels,
  );
}

/// Wraps a title [line] as an edge label on [side], placed by the line's own
/// alignment.
plume.EdgeLabel<PaintToken> _titleLabel(Line line, plume.EdgeSide side) =>
    plume.EdgeLabel<PaintToken>(child: lineNode(line), side: side, align: _labelAlign(line.alignment));

/// Maps a kiko [Alignment] onto the plume [plume.LabelAlign] a title uses to sit
/// along its edge; no preference reads as the left corner.
plume.LabelAlign _labelAlign(Alignment? alignment) => switch (alignment) {
  Alignment.left || null => plume.LabelAlign.start,
  Alignment.center => plume.LabelAlign.center,
  Alignment.right => plume.LabelAlign.end,
};
