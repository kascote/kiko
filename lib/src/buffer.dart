import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

import './extensions/iterator.dart';
import 'cell.dart';
import 'colors.dart';
import 'layout/position.dart';
import 'layout/rect.dart';
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

  Buffer._(Rect rect, [Cell? cell]) {
    area = rect;
    buf = List<Cell>.generate(
      rect.area,
      (idx) => cell != null ? cell.copyWith() : Cell.empty(),
    );
  }

  /// Returns a Buffer with all cells set to empty
  Buffer.empty(Rect rect) : this._(rect);

  /// Returns a Buffer with all cells initialized with the attributes of the
  /// given Cell
  Buffer.filled(Rect rect, Cell cell) : this._(rect, cell);

  /// Build a Buffer from a list of string lines
  @visibleForTesting
  factory Buffer.fromStringLines(List<String> stringLines) {
    final lines = stringLines.map((line) => Line(content: line)).toList();
    return Buffer.fromLines(lines);
  }

  /// Build a Buffer from a list of Line objects
  @visibleForTesting
  factory Buffer.fromLines(List<Line> lines) {
    final height = lines.length;
    final width = lines.fold(0, (acc, line) => math.max(acc, line.width));
    final area = Rect.create(x: 0, y: 0, width: width, height: height);

    final b = Buffer._(area);
    for (var y = 0; y < lines.length; y++) {
      var offset = 0;
      var xx = 0;
      for (final span in lines[y].spans) {
        for (final (i, char) in span.content.characters.indexed) {
          b.setCellAtPos(
            x: xx + i + offset,
            y: y,
            char: char,
            style: lines[y].style.patch(span.style),
          );
          if (widthString(char) > 1) {
            offset++;
          }
        }
        xx += span.width;
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

  int? _indexOfOpt(Position pos) {
    if (!area.contains(pos)) return null;
    // remove offset
    final x = pos.x - area.x;
    final y = pos.y - area.y;
    return y * area.width + x;
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

  /// Helper method to get the cell at a given [TPoint]
  Cell? cellAtPoint(TPoint point) => cellAtPos(point.toPos());

  /// Helper method to get the cell at a given [Position]
  Cell? cellAtPos(Position pos) {
    final idx = _indexOfOpt(pos);
    return (idx == null) ? null : buf[idx];
  }

  /// Array access operator to get the cell at a given [TPoint]
  Cell operator [](TPoint point) => buf[indexOf(point.x, point.y)];

  /// Array access operator to set the cell at a given [Position]
  //
  // Span.render and Buffer.setStringLength will set Cell.skip = true, when
  // rendering a wide character. This is to prevent the next cell from being
  // rendered. This is why we need to reset the skip flag when setting a new
  // cell. The idea is to pay the cost of resetting the skip flag only when
  // update the Cell and avoid the cost on Buffer.diff
  void operator []=(TPoint point, Cell cell) {
    final oldCellWidth = widthString(buf[indexOf(point.x, point.y)].symbol);
    final newCellWidth = widthString(cell.symbol);

    if (oldCellWidth > 1) {
      // If the old cell is a wide character, we need to remove the skip flag
      // from the next cells
      for (var i = 1; i < oldCellWidth; i++) {
        buf[indexOf(point.x + i, point.y)] = buf[indexOf(point.x + i, point.y)].copyWith(skip: false);
      }
    }

    buf[indexOf(point.x, point.y)] = cell;
    if (newCellWidth > 1) {
      for (var i = 1; i < newCellWidth; i++) {
        buf[indexOf(point.x + i, point.y)] = buf[indexOf(point.x + i, point.y)].copyWith(char: ' ', skip: false);
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
    this.area = area;
  }

  /// Reset all cells in the buffer
  void reset() {
    for (var i = 0; i < buf.length; i++) {
      buf[i] = buf[i].reset();
    }
  }

  /// Merge an other buffer into this on
  void merge(Buffer other) {
    final area = this.area.union(other.area);
    buf.addAll(
      List<Cell>.generate(area.area - buf.length, (_) => Cell.empty()),
    );

    var size = this.area.area;
    for (var i = size - 1; i >= 0; i--) {
      final pos = posOf(i);
      // new index in content
      final k = (pos.y - area.y) * area.width + pos.x - area.x;
      if (i != k) {
        buf[k] = buf[i].copyWith();
        buf[i] = buf[i].reset();
      }
    }

    // Push content of the other buffer into this one (may erase previous
    // data)

    size = other.area.area;
    for (var i = 0; i < size; i++) {
      final pos = other.posOf(i);
      // new index in content
      final k = (pos.y - area.y) * area.width + pos.x - area.x;
      buf[k] = other.buf[i].copyWith();
    }

    this.area = area;
  }

  /// Builds a minimal sequence of coordinates and Cells necessary to update
  /// the UI from self to other.
  ///
  /// We're assuming that buffers are well-formed, that is no double-width cell
  /// is followed by a non-blank cell.
  Iterable<CellPos> diff(Buffer other) sync* {
    final previousBuffer = buf;
    final nextBuffer = other.buf;

    // Cells from the current buffer to skip due to preceding multi-width characters taking
    // their place (the skipped cells should be blank anyway), or due to per-cell-skipping
    var i = 0;
    for (final (current, previous) in nextBuffer.zip(previousBuffer)) {
      if (!current.skip && (current != previous)) {
        final (x: x, y: y) = posOf(i);
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
      Color.fromRGB(123456),
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
        skip = math.max(0, math.max(skip, widthString(cell.symbol)) - 1);
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
    final charWidth = widthString(char);
    if (charWidth > 1) {
      for (var i = 1; i < charWidth; i++) {
        this[(x: x + i, y: y)] = const Cell(skip: true);
      }
    }
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
}
