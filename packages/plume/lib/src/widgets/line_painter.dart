import 'package:characters/characters.dart';

import '../painting/surface.dart';
import '../painting/text_measurer.dart';
import 'text.dart' show Text, TextAlign, TextOverflow, TextRun;

/// The glyph appended in place of a truncated tail under [TextOverflow.ellipsis].
const String ellipsisIndicator = '…';

/// One grapheme cluster with its paint token and measured display width — the
/// unit every line-placement decision (wrap, align, skip, clip, emit) works
/// in, once styled runs have been walked grapheme by grapheme.
class TextCluster<T> {
  /// Creates a cluster for one [grapheme], carrying [token] and its measured
  /// [width].
  const TextCluster(this.grapheme, this.token, this.width);

  /// The grapheme cluster's text.
  final String grapheme;

  /// The opaque paint token the grapheme draws with.
  final T token;

  /// The grapheme's measured display width, in cells.
  final int width;
}

/// Flattens [runs] into grapheme clusters, measuring each with [measurer].
///
/// A `\n` grapheme is kept, at width 0 — a caller wrapping across paragraphs
/// (line-breaking) looks for it; a caller painting a single line (kiko's
/// `Line` never carries an embedded newline) never sees one in practice.
List<TextCluster<T>> clusterRuns<T>(List<TextRun<T>> runs, TextMeasurer measurer) {
  final out = <TextCluster<T>>[];
  for (final run in runs) {
    for (final grapheme in run.text.characters) {
      final width = grapheme == '\n' ? 0 : measurer.widthOf(grapheme);
      out.add(TextCluster(grapheme, run.token, width));
    }
  }
  return out;
}

/// The total display width of [line].
int clusterLineWidth<T>(List<TextCluster<T>> line) {
  var total = 0;
  for (final cluster in line) {
    total += cluster.width;
  }
  return total;
}

/// Drops whole clusters covering the first [skipColumns] display columns of
/// [line] — a horizontal scroll offset.
///
/// A cluster straddling the boundary is dropped whole rather than rendered
/// partially, the same cut-on-whole-clusters rule clip trimming uses. That can
/// leave a blank gap narrower than the dropped cluster; the gap width is the
/// second return value, meant to be added to the paint start column so the
/// remaining content lands where it visually should.
(List<TextCluster<T>>, int) skipClusters<T>(List<TextCluster<T>> line, int skipColumns) {
  if (skipColumns <= 0) return (line, 0);
  var x = 0;
  var i = 0;
  while (i < line.length && x + line[i].width <= skipColumns) {
    x += line[i].width;
    i++;
  }
  if (i < line.length && x < skipColumns) {
    // The next cluster straddles the boundary — drop it whole too.
    x += line[i].width;
    i++;
  }
  return (line.sublist(i), x - skipColumns);
}

/// Aligns [line] within [width] columns starting at [boxX], or applies
/// [overflow] when it is too wide. Returns the clusters to draw and the
/// column to start drawing at. [indicatorWidth] is the measured width of the
/// ellipsis glyph, used only under [TextOverflow.ellipsis].
(List<TextCluster<T>>, int) resolveAlign<T>(
  List<TextCluster<T>> line, {
  required int boxX,
  required int width,
  required TextAlign align,
  required TextOverflow overflow,
  required int indicatorWidth,
}) {
  final lineWidth = clusterLineWidth(line);
  if (lineWidth <= width) {
    final shift = switch (align) {
      TextAlign.start => 0,
      TextAlign.center => (width - lineWidth) ~/ 2,
      TextAlign.end => width - lineWidth,
    };
    return (line, boxX + shift);
  }
  return switch (overflow) {
    TextOverflow.clip => (_clip(line, width), boxX),
    TextOverflow.ellipsis => (_ellipsize(line, width, indicatorWidth), boxX),
  };
}

List<TextCluster<T>> _clip<T>(List<TextCluster<T>> line, int available) {
  final out = <TextCluster<T>>[];
  var width = 0;
  for (final cluster in line) {
    if (width + cluster.width > available) {
      break;
    }
    out.add(cluster);
    width += cluster.width;
  }
  return out;
}

List<TextCluster<T>> _ellipsize<T>(List<TextCluster<T>> line, int available, int indicatorWidth) {
  if (available <= 0) {
    return <TextCluster<T>>[];
  }
  final out = <TextCluster<T>>[];
  var width = 0;
  // Reserve room for the indicator using its measured width, not a hardcoded
  // 1, so the reservation and the appended glyph always agree.
  final budget = available - indicatorWidth;
  for (final cluster in line) {
    if (width + cluster.width > budget) {
      break;
    }
    out.add(cluster);
    width += cluster.width;
  }
  final token = out.isNotEmpty ? out.last.token : line.first.token;
  out.add(TextCluster(ellipsisIndicator, token, indicatorWidth));
  return out;
}

/// Drops the clusters of [clusters] (starting at column [startX]) that fall
/// outside the horizontal span `[clipLeft, clipRight)`, cutting only on whole
/// clusters. Returns the surviving clusters and the column the first survivor
/// starts at.
(List<TextCluster<T>>, int) trimToClip<T>(List<TextCluster<T>> clusters, int startX, int clipLeft, int clipRight) {
  final out = <TextCluster<T>>[];
  var x = startX;
  var firstX = startX;
  var started = false;
  for (final cluster in clusters) {
    final end = x + cluster.width;
    if (x >= clipLeft && end <= clipRight) {
      if (!started) {
        firstX = x;
        started = true;
      }
      out.add(cluster);
    } else if (x >= clipLeft) {
      // Reached (or straddled) the right edge — nothing further fits.
      break;
    }
    x += cluster.width;
  }
  return (out, firstX);
}

/// Paints [line] into [surface] at ([x], [y]), trimming to the surface's
/// active clip first — the shared tail of every line-painting path.
void paintClusterLine<T>(Surface<T> surface, List<TextCluster<T>> line, {required int x, required int y}) {
  final clip = surface.clipRect;
  if (clip == null) {
    _emitClusters(surface, line, x, y);
    return;
  }
  final (trimmed, trimmedStart) = trimToClip(line, x, clip.left, clip.right);
  _emitClusters(surface, trimmed, trimmedStart, y);
}

void _emitClusters<T>(Surface<T> surface, List<TextCluster<T>> clusters, int startX, int y) {
  if (clusters.isEmpty) {
    return;
  }
  var x = startX;
  var runStart = startX;
  var currentToken = clusters.first.token;
  final buffer = StringBuffer();
  for (final cluster in clusters) {
    if (cluster.token != currentToken && buffer.isNotEmpty) {
      surface.drawText(runStart, y, buffer.toString(), currentToken);
      buffer.clear();
      runStart = x;
      currentToken = cluster.token;
    }
    buffer.write(cluster.grapheme);
    x += cluster.width;
  }
  if (buffer.isNotEmpty) {
    surface.drawText(runStart, y, buffer.toString(), currentToken);
  }
}

/// Paints one line of [runs] into [surface] at ([x], [y]), aligned and
/// clipped within [width] columns — the shared entry point for painting a
/// single line of styled text outside a full plume layout pass (a kiko
/// viewport row, for instance).
///
/// [Text] itself does not call this — it already has wrapped, measured lines
/// from its own layout pass and uses the lower-level pieces above directly.
/// This is for a caller with only a flat run list and nowhere to lay one out.
///
/// [skipColumns] drops that many leading display columns before alignment —
/// a horizontal scroll offset. It is meant for [TextAlign.start] content;
/// combined with center/end alignment the remaining columns still shift as
/// normal, a combination no caller needs today.
void paintRuns<T>(
  Surface<T> surface,
  List<TextRun<T>> runs,
  TextMeasurer measurer, {
  required int x,
  required int y,
  required int width,
  TextAlign align = TextAlign.start,
  TextOverflow overflow = TextOverflow.clip,
  int skipColumns = 0,
}) {
  var line = clusterRuns(runs, measurer);
  var boxX = x;
  if (skipColumns > 0) {
    final (skipped, gap) = skipClusters(line, skipColumns);
    line = skipped;
    boxX += gap;
  }
  final indicatorWidth = measurer.widthOf(ellipsisIndicator);
  final (resolved, startX) = resolveAlign(
    line,
    boxX: boxX,
    width: width,
    align: align,
    overflow: overflow,
    indicatorWidth: indicatorWidth,
  );
  paintClusterLine(surface, resolved, x: startX, y: y);
}
