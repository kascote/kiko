import 'package:plume/plume.dart' as plume;

import '../layout/alignment.dart';
import '../style.dart';
import '../text/line.dart';
import '../text/span.dart';
import '../text/text.dart';
import 'paint_token.dart';

/// Flattens kiko's `Span`/`Line` text into the plume nodes a layout tree draws.
///
/// kiko authors text as styled `Span`s grouped into `Line`s; plume lays out flat
/// runs of graphemes paired with an opaque paint token. These functions bridge
/// the two, folding the kiko style chain into one [PaintToken] per run so the
/// multi-colour authoring API survives into the plume tree.

/// Turns one [span] into a plume run, resolving its style against [base].
///
/// The run keeps the span's text verbatim; its token carries [base] overlaid
/// with the span's own style, so a caller passes the surrounding style as [base]
/// and the span's style wins where the two disagree.
plume.TextRun<PaintToken> spanRun(Span span, {Style base = const Style()}) =>
    plume.TextRun(span.content, PaintToken(base.patch(span.style)));

/// Turns one [line] into a single plume text node, one visual row of runs.
///
/// Each span becomes a run whose style resolves through the chain [base] ▸
/// line ▸ span, matching how kiko paints a line directly. Horizontal placement
/// follows the line's own alignment, falling back to [fallbackAlign] and then to
/// the left when neither is set.
plume.Text<PaintToken> lineNode(Line line, {Style base = const Style(), Alignment? fallbackAlign}) {
  final lineBase = base.patch(line.style);
  return plume.Text<PaintToken>(
    <plume.TextRun<PaintToken>>[for (final span in line.spans) spanRun(span, base: lineBase)],
    align: mapAlign(line.alignment ?? fallbackAlign),
  );
}

/// Maps a kiko [Alignment] onto the plume [plume.TextAlign] it corresponds to.
///
/// A `null` alignment — no preference — reads as left, plume's [plume.TextAlign.start].
plume.TextAlign mapAlign(Alignment? alignment) => switch (alignment) {
  Alignment.left || null => plume.TextAlign.start,
  Alignment.center => plume.TextAlign.center,
  Alignment.right => plume.TextAlign.end,
};

/// Turns a multi-line kiko [Text] into a plume node — the plume-native leaf for
/// a paragraph.
///
/// Each line flattens through [lineNode] with the style chain [base] ▸ text ▸
/// line ▸ span. A single line becomes one plume text node, shrink-wrapping to
/// its content. Because each kiko line can align itself independently but a
/// plume text node has one block alignment, several lines become a stretched
/// [plume.Column] of one text node per line — every line then fills the block
/// width and aligns its own content within it. A line without its own alignment
/// falls back to the text's, then to [fallbackAlign].
plume.RenderNode<PaintToken> textNode(Text text, {Style base = const Style(), Alignment? fallbackAlign}) {
  final textBase = base.patch(text.style);
  final blockAlign = text.alignment ?? fallbackAlign;
  final lines = <plume.RenderNode<PaintToken>>[
    for (final line in text.lines) lineNode(line, base: textBase, fallbackAlign: blockAlign),
  ];
  if (lines.length == 1) return lines.first;
  return plume.Column<PaintToken>(children: lines, crossAxisAlignment: plume.CrossAxisAlignment.stretch);
}
