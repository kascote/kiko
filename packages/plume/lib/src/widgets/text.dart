import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import '../geometry/box_constraints.dart';
import '../geometry/size.dart';
import '../painting/surface.dart';
import '../painting/text_measurer.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';

/// How the lines of a [Text] are aligned horizontally within its width.
enum TextAlign {
  /// Lines start at the left edge.
  start,

  /// Lines are centered.
  center,

  /// Lines end at the right edge.
  end,
}

/// What a [Text] does with a line too wide for its box (only reachable when
/// [Text.softWrap] is off).
///
/// Neither option paints outside the box: paint-side clipping bounds every node
/// to its assigned rect, so these choose only how the visible portion ends.
enum TextOverflow {
  /// Drop whatever spills past the right edge.
  clip,

  /// Replace the overflowing tail with an ellipsis indicator.
  ellipsis,
}

/// A run of graphemes sharing one opaque style token.
@immutable
class TextRun<S> {
  /// Creates a run drawing [text] with [style].
  const TextRun(this.text, this.style);

  /// The graphemes of the run.
  final String text;

  /// The opaque style token carried through to the surface.
  final S style;

  @override
  bool operator ==(Object other) => other is TextRun<S> && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => 'TextRun("$text", $style)';
}

/// One grapheme cluster with its style and measured width.
class _Cluster<S> {
  const _Cluster(this.grapheme, this.style, this.width);

  final String grapheme;
  final S style;
  final int width;
}

/// A leaf that lays out and paints styled text.
///
/// The input is already flattened to a list of [TextRun]s (kiko's `Line`/`Span`
/// hierarchy collapses to this at the boundary). Wrapping, [maxLines] and
/// [align] are layout concerns — they change the reported size; [overflow] is a
/// paint concern — it only affects which glyphs land in the already-decided
/// box. Styles are carried, never interpreted.
class Text<S> extends RenderNode<S> {
  /// Creates a text node from [runs].
  Text(
    this.runs, {
    this.softWrap = false,
    this.maxLines,
    this.align = TextAlign.start,
    this.overflow = TextOverflow.clip,
  });

  /// The styled runs to lay out, in order.
  final List<TextRun<S>> runs;

  /// Whether lines wrap to fit the available width. Off by default: on a cell
  /// grid, wrapping is opt-in so text never silently grows taller.
  final bool softWrap;

  /// The most lines to keep, or `null` for no cap.
  final int? maxLines;

  /// How lines are aligned within the box width.
  final TextAlign align;

  /// What happens to a line wider than the box.
  final TextOverflow overflow;

  /// The string appended to a truncated line under [TextOverflow.ellipsis].
  static const String _ellipsisIndicator = '…';

  List<List<_Cluster<S>>> _lines = <List<_Cluster<S>>>[];

  // Cell width of [_ellipsisIndicator], measured once during layout so paint
  // never assumes the indicator is one cell wide.
  int _indicatorWidth = 1;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final maxW = constraints.maxW;
    _indicatorWidth = context.measurer.widthOf(_ellipsisIndicator);
    _lines = _layoutLines(context.measurer, maxW);

    var natural = 0;
    for (final line in _lines) {
      final w = _lineWidth(line);
      if (w > natural) {
        natural = w;
      }
    }

    // A soft-wrapping text fills the available width so its lines can align
    // within it; otherwise it shrink-wraps to its longest line.
    final width = (softWrap && maxW != null) ? constraints.constrainWidth(maxW) : constraints.constrainWidth(natural);
    final height = constraints.constrainHeight(_lines.length);
    return Size(width, height);
  }

  List<List<_Cluster<S>>> _layoutLines(TextMeasurer measurer, int? maxWidth) {
    final lines = <List<_Cluster<S>>>[];
    for (final paragraph in _splitParagraphs(_flatten(measurer))) {
      if (!softWrap || maxWidth == null || maxWidth <= 0) {
        lines.add(paragraph);
      } else {
        lines.addAll(_wrap(paragraph, maxWidth));
      }
    }
    final cap = maxLines;
    if (cap != null && lines.length > cap) {
      return lines.sublist(0, cap);
    }
    return lines;
  }

  List<_Cluster<S>> _flatten(TextMeasurer measurer) {
    final out = <_Cluster<S>>[];
    for (final run in runs) {
      for (final grapheme in run.text.characters) {
        final width = grapheme == '\n' ? 0 : measurer.widthOf(grapheme);
        out.add(_Cluster(grapheme, run.style, width));
      }
    }
    return out;
  }

  List<List<_Cluster<S>>> _splitParagraphs(List<_Cluster<S>> clusters) {
    final paragraphs = <List<_Cluster<S>>>[];
    var current = <_Cluster<S>>[];
    for (final cluster in clusters) {
      if (cluster.grapheme == '\n') {
        paragraphs.add(current);
        current = <_Cluster<S>>[];
      } else {
        current.add(cluster);
      }
    }
    paragraphs.add(current);
    return paragraphs;
  }

  List<List<_Cluster<S>>> _wrap(List<_Cluster<S>> paragraph, int maxWidth) {
    final lines = <List<_Cluster<S>>>[];
    var line = <_Cluster<S>>[];
    var lineWidth = 0;
    _Cluster<S>? pendingSpace;
    var i = 0;
    while (i < paragraph.length) {
      if (paragraph[i].grapheme == ' ') {
        pendingSpace = paragraph[i];
        i++;
        continue;
      }
      final word = <_Cluster<S>>[];
      var wordWidth = 0;
      while (i < paragraph.length && paragraph[i].grapheme != ' ') {
        word.add(paragraph[i]);
        wordWidth += paragraph[i].width;
        i++;
      }
      final spaceWidth = (pendingSpace != null && line.isNotEmpty) ? pendingSpace.width : 0;
      if (line.isNotEmpty && lineWidth + spaceWidth + wordWidth > maxWidth) {
        lines.add(line);
        line = <_Cluster<S>>[];
        lineWidth = 0;
        pendingSpace = null;
      }
      if (wordWidth > maxWidth) {
        if (line.isNotEmpty) {
          lines.add(line);
          line = <_Cluster<S>>[];
          lineWidth = 0;
        }
        final chunks = _hardBreak(word, maxWidth);
        for (var k = 0; k < chunks.length - 1; k++) {
          lines.add(chunks[k]);
        }
        line = chunks.last;
        lineWidth = _lineWidth(line);
        pendingSpace = null;
      } else {
        if (line.isNotEmpty && pendingSpace != null) {
          line.add(pendingSpace);
          lineWidth += pendingSpace.width;
        }
        line.addAll(word);
        lineWidth += wordWidth;
        pendingSpace = null;
      }
    }
    lines.add(line);
    return lines;
  }

  List<List<_Cluster<S>>> _hardBreak(List<_Cluster<S>> word, int maxWidth) {
    final chunks = <List<_Cluster<S>>>[];
    var chunk = <_Cluster<S>>[];
    var width = 0;
    for (final cluster in word) {
      if (chunk.isNotEmpty && width + cluster.width > maxWidth) {
        chunks.add(chunk);
        chunk = <_Cluster<S>>[];
        width = 0;
      }
      chunk.add(cluster);
      width += cluster.width;
    }
    if (chunk.isNotEmpty) {
      chunks.add(chunk);
    }
    return chunks;
  }

  int _lineWidth(List<_Cluster<S>> line) {
    var total = 0;
    for (final cluster in line) {
      total += cluster.width;
    }
    return total;
  }

  @override
  void paintSelf(Surface<S> surface) {
    // Cap at the box height: a text with more lines than its assigned rect
    // never emits the doomed rows below its box. Rows outside a narrower
    // ancestor clip are dropped by the surface.
    final rows = _lines.length < rect.height ? _lines.length : rect.height;
    for (var i = 0; i < rows; i++) {
      _paintLine(surface, _lines[i], rect.y + i);
    }
  }

  void _paintLine(Surface<S> surface, List<_Cluster<S>> line, int y) {
    final (clusters, startX) = _resolveLine(line);
    // Trim horizontally to the effective clip (this rect intersected with every
    // ancestor's), so a line whose rect exceeds an ancestor is cut at glyph
    // boundaries rather than relying on the surface backstop.
    final clip = surface.clipRect;
    if (clip == null) {
      _emitRuns(surface, clusters, startX, y);
      return;
    }
    final (trimmed, trimmedStart) = _trimToClip(clusters, startX, clip.left, clip.right);
    _emitRuns(surface, trimmed, trimmedStart, y);
  }

  /// Aligns [line] within the box width, or applies the [overflow] policy when
  /// it is too wide, returning the clusters to draw and the column to start at.
  (List<_Cluster<S>>, int) _resolveLine(List<_Cluster<S>> line) {
    final available = rect.width;
    final lineWidth = _lineWidth(line);
    if (lineWidth <= available) {
      final shift = switch (align) {
        TextAlign.start => 0,
        TextAlign.center => (available - lineWidth) ~/ 2,
        TextAlign.end => available - lineWidth,
      };
      return (line, rect.x + shift);
    }
    return switch (overflow) {
      TextOverflow.clip => (_clip(line, available), rect.x),
      TextOverflow.ellipsis => (_ellipsize(line, available), rect.x),
    };
  }

  /// Drops the clusters of [clusters] (starting at column [startX]) that fall
  /// outside the horizontal span `[clipLeft, clipRight)`, cutting only on whole
  /// clusters. Returns the surviving clusters and the column the first survivor
  /// starts at.
  (List<_Cluster<S>>, int) _trimToClip(List<_Cluster<S>> clusters, int startX, int clipLeft, int clipRight) {
    final out = <_Cluster<S>>[];
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

  List<_Cluster<S>> _clip(List<_Cluster<S>> line, int available) {
    final out = <_Cluster<S>>[];
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

  List<_Cluster<S>> _ellipsize(List<_Cluster<S>> line, int available) {
    if (available <= 0) {
      return <_Cluster<S>>[];
    }
    final out = <_Cluster<S>>[];
    var width = 0;
    // Reserve room for the indicator using its measured width, not a hardcoded
    // 1, so the reservation and the appended glyph always agree.
    final budget = available - _indicatorWidth;
    for (final cluster in line) {
      if (width + cluster.width > budget) {
        break;
      }
      out.add(cluster);
      width += cluster.width;
    }
    final style = out.isNotEmpty ? out.last.style : line.first.style;
    out.add(_Cluster(_ellipsisIndicator, style, _indicatorWidth));
    return out;
  }

  void _emitRuns(Surface<S> surface, List<_Cluster<S>> clusters, int startX, int y) {
    if (clusters.isEmpty) {
      return;
    }
    var x = startX;
    var runStart = startX;
    var currentStyle = clusters.first.style;
    final buffer = StringBuffer();
    for (final cluster in clusters) {
      if (cluster.style != currentStyle && buffer.isNotEmpty) {
        surface.drawText(runStart, y, buffer.toString(), currentStyle);
        buffer.clear();
        runStart = x;
        currentStyle = cluster.style;
      }
      buffer.write(cluster.grapheme);
      x += cluster.width;
    }
    if (buffer.isNotEmpty) {
      surface.drawText(runStart, y, buffer.toString(), currentStyle);
    }
  }
}
