import 'package:meta/meta.dart';

import '../geometry/box_constraints.dart';
import '../geometry/size.dart';
import '../painting/surface.dart';
import '../painting/text_measurer.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import 'line_painter.dart';

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

/// A run of graphemes sharing one opaque paint token.
@immutable
class TextRun<T> {
  /// Creates a run drawing [text] with [token].
  const TextRun(this.text, this.token);

  /// The graphemes of the run.
  final String text;

  /// The opaque paint token carried through to the surface.
  final T token;

  @override
  bool operator ==(Object other) => other is TextRun<T> && other.text == text && other.token == token;

  @override
  int get hashCode => Object.hash(text, token);

  @override
  String toString() => 'TextRun("$text", $token)';
}

/// A leaf that lays out and paints styled text.
///
/// The input is already flattened to a list of [TextRun]s (kiko's `Line`/`Span`
/// hierarchy collapses to this at the boundary). Wrapping, [maxLines] and
/// [align] are layout concerns — they change the reported size; [overflow] is a
/// paint concern — it only affects which glyphs land in the already-decided
/// box. Paint tokens are carried, never interpreted.
class Text<T> extends RenderNode<T> {
  /// Creates a text node from [runs].
  Text(
    this.runs, {
    this.softWrap = false,
    this.maxLines,
    this.align = TextAlign.start,
    this.overflow = TextOverflow.clip,
  });

  /// The styled runs to lay out, in order.
  final List<TextRun<T>> runs;

  /// Whether lines wrap to fit the available width. Off by default: on a cell
  /// grid, wrapping is opt-in so text never silently grows taller.
  final bool softWrap;

  /// The most lines to keep, or `null` for no cap.
  final int? maxLines;

  /// How lines are aligned within the box width.
  final TextAlign align;

  /// What happens to a line wider than the box.
  final TextOverflow overflow;

  List<List<TextCluster<T>>> _lines = <List<TextCluster<T>>>[];

  // Cell width of the ellipsis glyph, measured once during layout so paint
  // never assumes the indicator is one cell wide.
  int _indicatorWidth = 1;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final maxW = constraints.maxW;
    _indicatorWidth = context.measurer.widthOf(ellipsisIndicator);
    _lines = _layoutLines(context.measurer, maxW);

    var natural = 0;
    for (final line in _lines) {
      final w = clusterLineWidth(line);
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

  List<List<TextCluster<T>>> _layoutLines(TextMeasurer measurer, int? maxWidth) {
    final lines = <List<TextCluster<T>>>[];
    for (final paragraph in _splitParagraphs(clusterRuns(runs, measurer))) {
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

  List<List<TextCluster<T>>> _splitParagraphs(List<TextCluster<T>> clusters) {
    final paragraphs = <List<TextCluster<T>>>[];
    var current = <TextCluster<T>>[];
    for (final cluster in clusters) {
      if (cluster.grapheme == '\n') {
        paragraphs.add(current);
        current = <TextCluster<T>>[];
      } else {
        current.add(cluster);
      }
    }
    paragraphs.add(current);
    return paragraphs;
  }

  List<List<TextCluster<T>>> _wrap(List<TextCluster<T>> paragraph, int maxWidth) {
    final lines = <List<TextCluster<T>>>[];
    var line = <TextCluster<T>>[];
    var lineWidth = 0;
    TextCluster<T>? pendingSpace;
    var i = 0;
    while (i < paragraph.length) {
      if (paragraph[i].grapheme == ' ') {
        pendingSpace = paragraph[i];
        i++;
        continue;
      }
      final word = <TextCluster<T>>[];
      var wordWidth = 0;
      while (i < paragraph.length && paragraph[i].grapheme != ' ') {
        word.add(paragraph[i]);
        wordWidth += paragraph[i].width;
        i++;
      }
      final spaceWidth = (pendingSpace != null && line.isNotEmpty) ? pendingSpace.width : 0;
      if (line.isNotEmpty && lineWidth + spaceWidth + wordWidth > maxWidth) {
        lines.add(line);
        line = <TextCluster<T>>[];
        lineWidth = 0;
        pendingSpace = null;
      }
      if (wordWidth > maxWidth) {
        if (line.isNotEmpty) {
          lines.add(line);
          line = <TextCluster<T>>[];
          lineWidth = 0;
        }
        final chunks = _hardBreak(word, maxWidth);
        for (var k = 0; k < chunks.length - 1; k++) {
          lines.add(chunks[k]);
        }
        line = chunks.last;
        lineWidth = clusterLineWidth(line);
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

  List<List<TextCluster<T>>> _hardBreak(List<TextCluster<T>> word, int maxWidth) {
    final chunks = <List<TextCluster<T>>>[];
    var chunk = <TextCluster<T>>[];
    var width = 0;
    for (final cluster in word) {
      if (chunk.isNotEmpty && width + cluster.width > maxWidth) {
        chunks.add(chunk);
        chunk = <TextCluster<T>>[];
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

  @override
  void paintSelf(Surface<T> surface) {
    // Cap at the box height: a text with more lines than its assigned rect
    // never emits the doomed rows below its box. Rows outside a narrower
    // ancestor clip are dropped by the surface.
    final rows = _lines.length < rect.height ? _lines.length : rect.height;
    for (var i = 0; i < rows; i++) {
      final (resolved, startX) = resolveAlign(
        _lines[i],
        boxX: rect.x,
        width: rect.width,
        align: align,
        overflow: overflow,
        indicatorWidth: _indicatorWidth,
      );
      paintClusterLine(surface, resolved, x: startX, y: rect.y + i);
    }
  }
}
