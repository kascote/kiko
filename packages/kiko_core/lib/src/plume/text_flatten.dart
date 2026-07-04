import 'package:plume/plume.dart' as plume;

import '../layout/alignment.dart';
import '../style.dart';
import '../text/line.dart';
import '../text/text.dart';
import 'paint_token.dart';

/// Flattens kiko's `Text`/`Line` text into the plume nodes a layout tree draws.
///
/// kiko authors text as styled `Text`s grouped into `Line`s; plume lays out flat
/// runs of graphemes paired with an opaque paint token. These functions bridge
/// the two, folding the kiko style chain into one [PaintToken] per run so the
/// multi-colour authoring API survives into the plume tree.

/// Turns one [span] into a plume run, resolving its style against [base].
///
/// The run keeps the span's text verbatim; its token carries [base] overlaid
/// with the span's own style, so a caller passes the surrounding style as [base]
/// and the span's style wins where the two disagree.
plume.TextRun<PaintToken> spanRun(Text span, {Style base = const Style()}) =>
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
