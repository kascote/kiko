import 'package:plume/plume.dart' as plume;

import '../layout/alignment.dart';
import '../style.dart';
import '../text/line.dart';
import 'paint_token.dart';
import 'term_unicode_measurer.dart';
import 'text_flatten.dart';

/// Paints one [Line] into [surface] at ([x], [y]) within [width] columns.
///
/// This is what a self-painting viewport (a data widget's visible row) calls
/// to draw its content through the plume paint protocol — [plume.Surface] —
/// instead of the retired `Widget.render` buffer bridge. The style chain
/// resolves as [base] ▸ the line's own style ▸ each span's style. The viewport
/// owns the row's rect, so it also owns placement: [align] positions the line
/// within [width], defaulting to the left.
///
/// [skipColumns] is a horizontal scroll offset (see plume's `paintRuns`) —
/// meant for left-aligned, single-line scrolling content such as a text
/// input; most callers leave it at zero.
void paintLine(
  plume.Surface<PaintToken> surface,
  Line line, {
  required int x,
  required int y,
  required int width,
  Style base = const Style(),
  Alignment align = Alignment.left,
  int skipColumns = 0,
  plume.TextMeasurer measurer = const TermUnicodeMeasurer(),
}) {
  final node = lineNode(line, base: base);
  plume.paintRuns(
    surface,
    node.runs,
    measurer,
    x: x,
    y: y,
    width: width,
    align: mapAlign(align),
    skipColumns: skipColumns,
  );
}

/// Fills one row — [width] columns starting at ([x], [y]) — with [style].
///
/// The plume-native replacement for painting a whole-row background by
/// patching a buffer area's style directly (the old `Buffer.setStyle` row
/// highlight). Paint order matters: call this before the row's [paintLine]
/// so the fill sits under the glyphs, the same order the buffer-bridge
/// viewports already painted in.
void fillRow(
  plume.Surface<PaintToken> surface, {
  required int x,
  required int y,
  required int width,
  required Style style,
}) {
  surface.fillRect(plume.Rect(x, y, width, 1), PaintToken(style));
}
