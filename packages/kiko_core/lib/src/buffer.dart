import 'dart:math' as math;
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:plume/plume.dart' show TextMeasurer;

import 'cell.dart';
import 'colors.dart';
import 'extensions/iterator.dart';
import 'layout/position.dart';
import 'layout/rect.dart';
import 'plume/term_unicode_measurer.dart';
import 'style.dart';
import 'text/line.dart';

/// Helper record used by the diff method
typedef CellPos = ({int x, int y, Cell cell});

/// Helper to render a character at a given position
typedef CharAtPos = ({int x, int y, String char, Style? style});

/// A buffer that maps to the desired content of the terminal after the draw
/// call
///
/// No widget in the library interacts directly with the terminal. Instead each
/// of them is required to draw their state to an intermediate buffer. It is
/// basically a grid where each cell contains a grapheme, a foreground color
/// and a background color. This grid will then be used to output the
/// appropriate escape sequences and characters to draw the UI as the user has
/// defined it.
class Buffer implements Equality<Buffer> {
  /// The area represented by this buffer
  late Rect area;

  /// The content of the buffer. The length of this List should always be equal
  /// to area.width * area.height
  late List<Cell> buf;

  /// Measured symbol width of each cell in [buf], kept parallel to it: same
  /// length, same index, and always in sync — `_widths[i]` equals
  /// `measurer.widthOf(buf[i].symbol)` for every index `i`.
  ///
  /// `Buffer.operator []=` used to re-measure the cell it was about to
  /// overwrite just to know how many trailing skip cells to clear. That width
  /// was already known the moment the cell was written — this sidecar caches
  /// it so `[]=` can read it back instead of paying `measurer.widthOf` twice
  /// per write.
  late Uint8List _widths;

  /// The width policy this buffer measures wide cells with.
  ///
  /// A terminal session settles on one ruler for its whole lifetime — see
  /// [TermUnicodeMeasurer]'s `cjk` flag — and both of a `Terminal`'s buffers
  /// are built with it, so a diff between them never compares cells measured
  /// two different ways.
  final TextMeasurer measurer;

  Buffer._(Rect rect, [Cell? cell, this.measurer = const TermUnicodeMeasurer()]) {
    area = rect;
    buf = List<Cell>.generate(
      rect.area,
      (idx) => cell != null ? cell.copyWith() : Cell.empty(),
      growable: false,
    );
    // Every cell starts out identical (the fill cell, or the empty cell), so
    // the fill width only needs measuring once for the whole buffer.
    final fillWidth = measurer.widthOf(cell?.symbol ?? Cell.empty().symbol);
    _widths = Uint8List(rect.area)..fillRange(0, rect.area, fillWidth);
  }

  /// Returns a Buffer with all cells set to empty
  Buffer.empty(Rect rect, {TextMeasurer measurer = const TermUnicodeMeasurer()}) : this._(rect, null, measurer);

  /// Returns a Buffer with all cells initialized with the attributes of the
  /// given Cell
  Buffer.filled(Rect rect, Cell cell, {TextMeasurer measurer = const TermUnicodeMeasurer()})
    : this._(rect, cell, measurer);

  /// Creates a copy of another buffer.
  ///
  /// Since [Cell] is immutable, a shallow copy of the cell list is sufficient.
  /// The copy measures with the same ruler as [other].
  factory Buffer.copyFrom(Buffer other) {
    return Buffer.empty(other.area, measurer: other.measurer)
      ..buf = List.from(other.buf, growable: false)
      .._widths = Uint8List.fromList(other._widths);
  }

  int? _indexOfOpt(Position pos) {
    if (!area.contains(pos)) return null;
    // remove offset
    final x = pos.x - area.x;
    final y = pos.y - area.y;
    return y * area.width + x;
  }

  // Recomputes every width from buf and compares it against the sidecar.
  // Only called from asserts after whole-buffer operations (resize, reset)
  // — never from the per-cell []= hot path, where it would make a single
  // write cost quadratic under debug asserts.
  bool _widthsInSync() {
    for (var i = 0; i < buf.length; i++) {
      if (_widths[i] != measurer.widthOf(buf[i].symbol)) return false;
    }
    return true;
  }

  /// Returns the index in the Buffer for the given global (x, y) coordinates.
  ///
  /// Global coordinates are offset by the Buffer's area offset (`x`/`y`).
  ///
  int indexOf(int x, int y) {
    final idx = _indexOfOpt(Position(x, y));
    if (idx == null) {
      throw RangeError('Position ($x,$y) is out of bounds. area: $area');
    }
    return idx;
  }

  /// Array access operator to get the cell at a given [TPoint]
  Cell operator [](TPoint point) => buf[indexOf(point.x, point.y)];

  /// Array access operator to set the cell at a given [Position]
  //
  // A single write always leaves the buffer well-formed: writing a wide
  // glyph marks its own trailing cells skip, and overwriting a cell that used
  // to be wide clears the stale skip its old trailing cells were left with.
  // No caller needs a follow-up pass to fix up trailing cells.
  //
  // A wide glyph that would not fit whole inside the row — its starting
  // column plus its width spills past the row's last column — is written as
  // a single blank cell instead, keeping the write's original style.
  void operator []=(TPoint point, Cell cell) {
    final idx = indexOf(point.x, point.y);
    // The old width was recorded in the sidecar the last time this cell's
    // symbol was set, so there's no need to re-measure it here.
    final oldCellWidth = _widths[idx];
    var newCellWidth = measurer.widthOf(cell.symbol);

    if (oldCellWidth > 1) {
      // If the old cell is a wide character, we need to remove the skip flag
      // from the next cells
      for (var i = 1; i < oldCellWidth; i++) {
        buf[indexOf(point.x + i, point.y)] = buf[indexOf(point.x + i, point.y)].copyWith(skip: false);
      }
    }

    var newCell = cell;
    if (newCellWidth > 1 && point.x + newCellWidth > area.x + area.width) {
      // The glyph cannot fit whole inside the row: clip it to a blank cell
      // rather than writing trailing cells past the row's last column.
      newCell = cell.copyWith(char: ' ', skip: false);
      newCellWidth = 1;
    }

    buf[idx] = newCell;
    _widths[idx] = newCellWidth;
    assert(
      _widths[idx] == measurer.widthOf(buf[idx].symbol),
      'sidecar width out of sync at $idx',
    );
    if (newCellWidth > 1) {
      for (var i = 1; i < newCellWidth; i++) {
        final trailingIdx = indexOf(point.x + i, point.y);
        buf[trailingIdx] = buf[trailingIdx].copyWith(char: ' ', skip: true);
        // The trailing cell's symbol just became a single blank space.
        _widths[trailingIdx] = 1;
      }
    }
  }

  /// Returns the (global) coordinates of a cell given its index
  ///
  /// Global coordinates are offset by the Buffer's area offset (`x`/`y`).
  TPoint posOf(int index) {
    if (index >= buf.length) {
      throw RangeError('Index $index is out of bounds. length: ${buf.length}');
    }
    return (
      x: area.x + (index % area.width),
      y: area.y + (index ~/ area.width),
    );
  }

  /// Set the style of all cells in the given area
  void setStyle(Rect area, Style style) {
    final r = this.area.intersection(area);

    for (var y = r.top; y < r.bottom; y++) {
      for (var x = r.left; x < r.right; x++) {
        this[(x: x, y: y)] = this[(x: x, y: y)].setStyle(style);
      }
    }
  }

  /// Resize the buffer so that the mapped area matches the given area and that
  /// the buffer length is equal to area.width * area.height
  void resize(Rect area) {
    buf = List<Cell>.generate(
      area.area,
      (idx) => Cell.empty(),
      growable: false,
    );
    // Every cell above is a fresh Cell.empty() (width 1), so the sidecar is
    // simply reallocated to the new length and filled the same way.
    _widths = Uint8List(area.area)..fillRange(0, area.area, 1);
    this.area = area;
    assert(_widthsInSync(), 'sidecar out of sync after resize');
  }

  /// Reset all cells in the buffer
  void reset() {
    for (var i = 0; i < buf.length; i++) {
      buf[i] = buf[i].reset();
    }
    // Cell.reset() always yields Cell.empty(), a single space (width 1).
    _widths.fillRange(0, _widths.length, 1);
    assert(_widthsInSync(), 'sidecar out of sync after reset');
  }

  /// Copies [source] onto this buffer over [rect], replacing cells outright.
  ///
  /// Use it to composite a rect-sized scratch buffer onto a frame buffer in
  /// one opaque blit. Both buffers share the same coordinate space, so no
  /// translation happens: the copy clips to the intersection of [rect],
  /// `source.area`, and this buffer's `area`.
  ///
  /// A destination wide glyph whose head sits outside the clipped region but
  /// whose trailing cell sits inside it is healed to a styled blank before
  /// its row is copied. A source wide glyph whose trailing cell would fall
  /// outside the region is written as a styled blank instead, so its skip
  /// mark never spills past the blit.
  void blitFrom(Buffer source, Rect rect) {
    final region = rect.intersection(source.area).intersection(area);
    if (region.isEmpty) return;

    for (var y = region.top; y < region.bottom; y++) {
      _healOrphanedHead(region, y);

      for (var x = region.left; x < region.right; x++) {
        final srcIdx = source.indexOf(x, y);
        final srcCell = source.buf[srcIdx];
        final srcWidth = source._widths[srcIdx];

        this[(x: x, y: y)] = (srcWidth > 1 && x + srcWidth > region.right)
            ? srcCell.copyWith(char: ' ', skip: false)
            : srcCell;
      }
    }

    assert(_widthsInSync(), 'sidecar out of sync after blitFrom');
  }

  // Heals a destination wide glyph whose head sits to the left of the blit
  // region but whose trailing cell sits inside it. Runs before the row is
  // copied, so the heal's own trailing-skip clearing never touches cells the
  // blit is about to write.
  void _healOrphanedHead(Rect region, int y) {
    if (!this[(x: region.left, y: y)].skip) return;

    var headX = region.left - 1;
    while (headX >= area.left && this[(x: headX, y: y)].skip) {
      headX--;
    }
    if (headX < area.left) return;

    this[(x: headX, y: y)] = this[(x: headX, y: y)].copyWith(char: ' ', skip: false);
  }

  /// Builds a minimal sequence of coordinates and Cells necessary to update
  /// the UI from self to other.
  ///
  /// Assumes both buffers are well-formed: no wide cell is ever followed by a
  /// non-blank, non-skipped cell. Every write goes through
  /// `Buffer.operator []=`, which guarantees this for the cell it writes, so
  /// a buffer built entirely through it always satisfies the assumption.
  Iterable<CellPos> diff(Buffer other) sync* {
    final previousBuffer = buf;
    final nextBuffer = other.buf;

    // Cells from the current buffer to skip due to preceding multi-width characters taking
    // their place (the skipped cells should be blank anyway), or due to per-cell-skipping
    var i = 0;
    for (final (current, previous) in nextBuffer.zip(previousBuffer)) {
      if (!current.skip && (current != previous)) {
        final (:x, :y) = posOf(i);
        yield (x: x, y: y, cell: nextBuffer[i]);
      }
      i++;
    }
  }

  /// Returns a reference to the [Cell] at the given position.
  Cell index(Position pos) {
    final idx = indexOf(pos.x, pos.y);
    return buf[idx];
  }

  /// Returns a debug representation of the buffer.
  String debug() {
    final sb = StringBuffer()..write('Buffer {\n    area: $area');

    if (area.isEmpty) {
      sb.write('\n}');
    }
    sb.write(',\n    content: [\n');
    var lastStyle = (
      const Color.rgb(123456),
      Color.reset,
      Color.reset,
      Modifier.empty,
    );
    final styles = <(int, int, Color, Color, Color, Modifier)>[];

    var y = 0;
    for (final line in buf.chunks(area.width)) {
      final overwritten = <(int, String)>[];
      var skip = 0;

      sb.write('        "');
      var x = 0;
      for (final cell in line) {
        if (skip == 0) {
          sb.write(cell.symbol);
        } else {
          overwritten.add((x, cell.symbol));
        }
        skip = math.max(0, math.max(skip, measurer.widthOf(cell.symbol)) - 1);
        final style = (cell.fg, cell.bg, cell.underline, cell.modifier);
        if (lastStyle != style) {
          lastStyle = style;
          styles.add((x, y, cell.fg, cell.bg, cell.underline, cell.modifier));
        }
        x++;
      }
      sb.write('",');
      if (overwritten.isNotEmpty) {
        sb.write(' // overwritten: $overwritten');
      }
      sb.write('\n');
      y++;
    }
    sb.write('    ],\n    styles: [\n');
    for (final s in styles) {
      sb.write(
        '        x: ${s.$1}, y: ${s.$2}, fg: ${s.$3}, bg: ${s.$4}, underline: ${s.$5}, modifier: ${s.$6}\n',
      );
    }
    sb.write('    ]\n}');

    return sb.toString();
  }

  @override
  bool equals(Buffer e1, Buffer e2) {
    if (identical(e1, e2)) return true;
    if (e1.buf.length != e2.buf.length) return false;
    if (e1.area != e2.area) return false;

    for (var i = 0; i < buf.length; i++) {
      if (e1.buf[i].skip) continue;
      if (e1.buf[i] != e2.buf[i]) return false;
    }

    return true;
  }

  /// Helper function to compare this buffer to another
  bool eq(Buffer other) => equals(this, other);

  // coverage:ignore-start
  @override
  String toString() {
    return debug();
  }

  // coverage:ignore-line to ignore one line.
  @override
  int hash(Buffer e) => Object.hash(Buffer, area, Object.hashAll(buf));

  // coverage:ignore-line to ignore one line.
  @override
  bool isValidKey(Object? o) => o is Buffer;
  // coverage:ignore-end

  /// Returns a copy of the per-cell width sidecar (see [_widths]).
  ///
  /// Exists so consistency tests can check, from the outside, that
  /// `debugWidths[i] == measurer.widthOf(buf[i].symbol)` holds for every
  /// index after any sequence of mutations.
  @visibleForTesting
  Uint8List get debugWidths => Uint8List.fromList(_widths);

  /// Helper function to set the cell at a given position.
  /// Intended to be used as a helper for testing
  @visibleForTesting
  void setCellAtPos({
    required int x,
    required int y,
    required String char,
    Style? style,
  }) {
    this[(x: x, y: y)] = this[(x: x, y: y)].setCell(
      char: char,
      style: style ?? const Style(),
    );
  }

  /// Build a Buffer from a list of string lines
  @visibleForTesting
  factory Buffer.fromStringLines(List<String> stringLines, {TextMeasurer measurer = const TermUnicodeMeasurer()}) {
    final lines = stringLines.map(Line.new).toList();
    return Buffer.fromLines(lines, measurer: measurer);
  }

  /// Build a Buffer from a list of Line objects
  @visibleForTesting
  factory Buffer.fromLines(List<Line> lines, {TextMeasurer measurer = const TermUnicodeMeasurer()}) {
    final height = lines.length;
    final width = lines.fold(0, (acc, line) => math.max(acc, line.width(measurer)));
    final area = Rect.create(x: 0, y: 0, width: width, height: height);

    final b = Buffer._(area, null, measurer);
    for (var y = 0; y < lines.length; y++) {
      var offset = 0;
      var xx = 0;
      for (final text in lines[y].texts) {
        for (final (i, char) in text.content.characters.indexed) {
          b.setCellAtPos(
            x: xx + i + offset,
            y: y,
            char: char,
            style: lines[y].style.patch(text.style),
          );
          if (measurer.widthOf(char) > 1) {
            offset++;
          }
        }
        xx += text.width(measurer);
      }
    }
    return b;
  }

  /// Helper function to set the buffer cells at a given position.
  /// Intended to be used as a helper for testing
  @visibleForTesting
  factory Buffer.setCells(Rect area, List<CharAtPos> cells) {
    final buf = Buffer._(area);

    for (final cell in cells) {
      for (final (i, char) in cell.char.characters.indexed) {
        buf.setCellAtPos(
          x: cell.x + i,
          y: cell.y,
          char: char,
          style: cell.style,
        );
      }
    }
    return buf;
  }

  /// Helper method to get the cell at a given [TPoint]
  @visibleForTesting
  Cell? cellAtPoint(TPoint point) => cellAtPos(point.toPos());

  /// Helper method to get the cell at a given [Position]
  @visibleForTesting
  Cell? cellAtPos(Position pos) {
    final idx = _indexOfOpt(pos);
    return (idx == null) ? null : buf[idx];
  }
}
