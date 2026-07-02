import '../geometry/rect.dart';
import 'surface.dart';

/// A [Surface] base that enforces the active clip on every draw call.
///
/// It owns a clip stack and the intersection logic, so a concrete surface only
/// implements the raw sinks ([rawFillRect] / [rawDrawBorder] / [rawDrawText])
/// and never sees the clip machinery. Because leaves draw through the public
/// [drawText] / [fillRect] / [drawBorder] methods, the clip cannot be bypassed
/// by a leaf.
///
/// Each draw call is measured against the active clip:
/// - a fill or border with no overlap is dropped, otherwise it is passed
///   through with the clip carried when the clip does not fully contain it;
/// - a border is always passed with its original rect, never a shrunken one, so
///   the backend drops the perimeter cells outside the clip rather than drawing
///   a false edge at the clip line;
/// - a text run on a row outside the clip is dropped whole (measurement-free);
///   horizontal trimming needs glyph widths the surface does not have, so the
///   leaf trims and the surface carries the clip only as a backstop for a run
///   that starts outside it.
///
/// A carried clip is `null` whenever the clip fully contains the footprint, so
/// an unclipped draw records exactly as it did before clipping existed.
abstract class ClippingSurface<T> implements Surface<T> {
  final List<Rect> _clips = <Rect>[];

  @override
  Rect? get clipRect => _clips.isEmpty ? null : _clips.last;

  @override
  void pushClip(Rect rect) {
    final top = clipRect;
    _clips.add(top == null ? rect : top.intersect(rect));
  }

  @override
  void popClip() {
    _clips.removeLast();
  }

  @override
  void fillRect(Rect rect, T token) {
    final clip = clipRect;
    if (clip == null) {
      rawFillRect(rect, token, null);
      return;
    }
    if (clip.intersect(rect).isEmpty) {
      return;
    }
    rawFillRect(rect, token, clip.containsRect(rect) ? null : clip);
  }

  @override
  void drawBorder(Rect rect, T token) {
    final clip = clipRect;
    if (clip == null) {
      rawDrawBorder(rect, token, null);
      return;
    }
    if (clip.intersect(rect).isEmpty) {
      return;
    }
    rawDrawBorder(rect, token, clip.containsRect(rect) ? null : clip);
  }

  @override
  void drawText(int x, int y, String run, T token) {
    final clip = clipRect;
    if (clip == null) {
      rawDrawText(x, y, run, token, null);
      return;
    }
    // A run occupies a single row, so a row outside the clip drops with no
    // measurement, and a run starting at or past the right edge is entirely
    // outside horizontally.
    if (y < clip.top || y >= clip.bottom || x >= clip.right) {
      return;
    }
    // A run starting inside the clip is trusted to have been trimmed by the
    // leaf (which has the glyph widths); a run starting left of the clip
    // carries it as a backstop.
    rawDrawText(x, y, run, token, x < clip.left ? clip : null);
  }

  /// Fills [rect] with [token], honoring [clip] if non-null.
  void rawFillRect(Rect rect, T token, Rect? clip);

  /// Draws a border around [rect] with [token], honoring [clip] if non-null.
  void rawDrawBorder(Rect rect, T token, Rect? clip);

  /// Draws [run] at ([x], [y]) with [token], honoring [clip] if non-null.
  void rawDrawText(int x, int y, String run, T token, Rect? clip);
}
