import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:plume/plume.dart' as plume;
import 'package:termunicode/termunicode.dart';

import '../buffer.dart';
import '../cell.dart';
import '../style.dart';

/// Paints a laid-out plume tree into a kiko [Buffer].
///
/// This is the production [plume.Surface]; plume's own tests paint into a
/// `RecordingSurface` instead. It is the one place the opaque style token is
/// decoded: plume is generic over a token type and never looks inside it, so
/// kiko binds that type to its own [Style] and redeems it here — every
/// [drawText]/[fillRect] call turns a carried [Style] into real [Buffer] cells.
///
/// Clipping is inherited from [plume.ClippingSurface]: the paint walk pushes
/// each node's rect and the base class trims draws to the active clip, handing
/// this class only the raw sinks below. Every write is additionally clamped to
/// the buffer's own bounds, so a draw that escaped its box is dropped rather
/// than throwing a [RangeError].
class BufferSurface extends plume.ClippingSurface<Style> {
  /// Creates a surface that paints into [_buffer].
  BufferSurface(this._buffer);

  final Buffer _buffer;

  @override
  void rawDrawText(int x, int y, String run, Style style, plume.Rect? clip) {
    final area = _buffer.area;
    // A run occupies one row: drop it whole when that row is off the buffer.
    if (y < area.top || y >= area.bottom) return;

    // The base surface rejects a row outside the clip before ever carrying one
    // down, so a carried clip always contains this row. Assert that invariant
    // rather than re-checking it; only the column trimming below is left to do.
    assert(
      clip == null || (y >= clip.top && y < clip.bottom),
      'carried clip must contain the run row',
    );

    // The drawable column span is the buffer intersected with the clip.
    final left = clip == null ? area.left : math.max(area.left, clip.left);
    final right = clip == null ? area.right : math.min(area.right, clip.right);

    var cx = x;
    for (final cluster in run.characters) {
      final w = widthString(cluster);

      // A zero-width cluster (a combining mark) folds into the cell before it,
      // as long as that cell is inside the drawable span.
      if (w == 0) {
        final prev = cx - 1;
        if (prev >= left && prev < right) {
          _buffer[(x: prev, y: y)] =
              _buffer[(x: prev, y: y)].appendSymbol(char: cluster, style: style);
        }
        continue;
      }

      final nextX = cx + w;
      // Entirely left of the drawable span: step over it without drawing.
      if (nextX <= left) {
        cx = nextX;
        continue;
      }
      // At or past the right edge: nothing more can fit.
      if (cx >= right) break;
      // A (wide) cluster straddling either edge cannot be drawn as whole cells,
      // so the fragment is dropped rather than painting half a glyph.
      if (cx < left || nextX > right) {
        cx = nextX;
        continue;
      }
      _buffer[(x: cx, y: y)] =
          _buffer[(x: cx, y: y)].setCell(char: cluster, style: style);
      // A wide glyph hides the cells it spans: mark them skipped so the buffer
      // diff leaves them alone rather than emitting a space over the glyph.
      for (var i = cx + 1; i < nextX; i++) {
        _buffer[(x: i, y: y)] = const Cell(skip: true);
      }
      cx = nextX;
    }
  }

  @override
  void rawFillRect(plume.Rect rect, Style style, plume.Rect? clip) {
    final region = _clampToBuffer(clip == null ? rect : rect.intersect(clip));
    for (var yy = region.top; yy < region.bottom; yy++) {
      for (var xx = region.left; xx < region.right; xx++) {
        _buffer[(x: xx, y: yy)] =
            _buffer[(x: xx, y: yy)].setCell(char: ' ', style: style);
      }
    }
  }

  @override
  void rawDrawBorder(plume.Rect rect, Style style, plume.Rect? clip) {
    // Deferred to the Block/Container port. The border charset (single /
    // rounded / double / thick) has to travel in the style token, which
    // kiko.Style does not yet carry — so a faithful border cannot be drawn from
    // a bare Style, and hardcoding one charset here would quietly contradict the
    // locked "charset rides in the token" design (spec 0037). The layout-example
    // pilot paints no borders, so this stays unimplemented until a bordered
    // widget is ported and the token shape is decided.
    throw UnimplementedError(
      'BufferSurface.drawBorder is deferred to the Block/Container port: the '
      'border charset must travel in the style token, which kiko.Style does '
      'not yet carry.',
    );
  }

  /// Intersects [r] with the buffer's own area, returned as a non-negative rect.
  plume.Rect _clampToBuffer(plume.Rect r) {
    final a = _buffer.area;
    final left = math.max(r.left, a.left);
    final top = math.max(r.top, a.top);
    final right = math.min(r.right, a.right);
    final bottom = math.min(r.bottom, a.bottom);
    final w = right - left;
    final h = bottom - top;
    return plume.Rect(left, top, w < 0 ? 0 : w, h < 0 ? 0 : h);
  }
}
