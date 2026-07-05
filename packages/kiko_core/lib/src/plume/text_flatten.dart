import 'package:plume/plume.dart' as plume;

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
///
/// ## Naming: `Text` is a false friend across this bridge
///
/// The word `Text` names two different scales on the two sides handled here, so
/// read the prefix, not just the word:
///
/// - **kiko `Text`** (unprefixed, from `../text/text.dart`) is one styled *run* —
///   a contiguous stretch of characters sharing a single style. It is the chunk,
///   the smallest styleable unit.
/// - **`plume.Text`** (always prefixed) is a whole *row* — a text node built from
///   a `List<plume.TextRun>` that a layout tree positions as one visual line.
///
/// So the scale mapping this file performs is deliberately *not* name-for-name:
///
/// | kiko (authoring) | plume (engine) | scale       |
/// | ---------------- | -------------- | ----------- |
/// | `Text`           | `plume.TextRun`| one run     |
/// | `Line`           | `plume.Text`   | one row     |
///
/// A kiko `Text` (chunk) becomes a `plume.TextRun` (chunk); a kiko `Line` (row)
/// becomes a `plume.Text` (row). Keeping the `plume.` prefix on every plume type
/// is what keeps the two `Text`s from blurring — never drop it in this file.

/// Turns one kiko [text] chunk into a `plume.TextRun`, resolving its style
/// against [base].
///
/// The run keeps the text verbatim; its token carries [base] overlaid with the
/// text's own style, so a caller passes the surrounding style as [base] and the
/// text's style wins where the two disagree.
plume.TextRun<PaintToken> textRun(Text text, {Style base = const Style()}) =>
    plume.TextRun(text.content, PaintToken(base.patch(text.style)));

/// Turns one standalone kiko [text] chunk into a single-run `plume.Text` row.
///
/// The run resolves through [base] ▸ the text's own style. The node aligns at
/// the start — position is the parent's job, not the text's.
plume.Text<PaintToken> textNode(Text text, {Style base = const Style()}) =>
    plume.Text<PaintToken>(<plume.TextRun<PaintToken>>[textRun(text, base: base)]);

/// Turns one kiko [line] into a single `plume.Text` node, one visual row of runs.
///
/// Each kiko `Text` becomes a run whose style resolves through the chain [base] ▸
/// line ▸ text, matching how kiko paints a line directly. The node aligns at the
/// start; a caller that owns a rect (a viewport row) chooses placement itself.
plume.Text<PaintToken> lineNode(Line line, {Style base = const Style()}) {
  final lineBase = base.patch(line.style);
  return plume.Text<PaintToken>(
    <plume.TextRun<PaintToken>>[for (final text in line.texts) textRun(text, base: lineBase)],
  );
}
