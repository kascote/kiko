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
///
/// These are the shared inflate step behind `Text.build`, `Line.build`, and
/// `paintLine`. They are internal to the package — authors compose `Text`/`Line`
/// as views and never call these directly.

/// Turns one [span] into a plume run, resolving its style against [base].
///
/// The run keeps the span's text verbatim; its token carries [base] overlaid
/// with the span's own style, so a caller passes the surrounding style as [base]
/// and the span's style wins where the two disagree.
plume.TextRun<PaintToken> spanRun(Text span, {Style base = const Style()}) =>
    plume.TextRun(span.content, PaintToken(base.patch(span.style)));

/// Turns one standalone [text] into a single-run plume text node.
///
/// The run resolves through [base] ▸ the text's own style. The node aligns at
/// the start — position is the parent's job, not the text's.
plume.Text<PaintToken> textNode(Text text, {Style base = const Style()}) =>
    plume.Text<PaintToken>(<plume.TextRun<PaintToken>>[spanRun(text, base: base)]);

/// Turns one [line] into a single plume text node, one visual row of runs.
///
/// Each span becomes a run whose style resolves through the chain [base] ▸
/// line ▸ span, matching how kiko paints a line directly. The node aligns at the
/// start; a caller that owns a rect (a viewport row) chooses placement itself.
plume.Text<PaintToken> lineNode(Line line, {Style base = const Style()}) {
  final lineBase = base.patch(line.style);
  return plume.Text<PaintToken>(
    <plume.TextRun<PaintToken>>[for (final span in line.spans) spanRun(span, base: lineBase)],
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
