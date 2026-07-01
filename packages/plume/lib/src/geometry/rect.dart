import 'package:meta/meta.dart';

import 'offset.dart';
import 'size.dart';

/// A rectangular region of the grid: an origin ([x], [y]) plus a [width] and
/// [height], all in whole cells.
///
/// Every laid-out node stores its absolute rect, which both paint and hit
/// testing read. Coordinates are half-open on the right and bottom: a rect at
/// `x = 0` with `width = 3` covers columns `0`, `1`, `2` — column `3` is
/// outside.
@immutable
class Rect {
  /// Creates a rect at ([x], [y]) spanning [width] × [height] cells.
  const Rect(this.x, this.y, this.width, this.height);

  /// Creates a rect from a top-left [origin] and a [size].
  Rect.fromOriginSize(Offset origin, Size size) : x = origin.dx, y = origin.dy, width = size.w, height = size.h;

  /// The empty rect at the origin.
  static const Rect zero = Rect(0, 0, 0, 0);

  /// Left edge (x origin) in cells.
  final int x;

  /// Top edge (y origin) in cells.
  final int y;

  /// Width in cells.
  final int width;

  /// Height in cells.
  final int height;

  /// The left edge; equal to [x].
  int get left => x;

  /// The top edge; equal to [y].
  int get top => y;

  /// The first column *past* the right edge (`x + width`).
  int get right => x + width;

  /// The first row *past* the bottom edge (`y + height`).
  int get bottom => y + height;

  /// The top-left corner as an [Offset].
  Offset get topLeft => Offset(x, y);

  /// The [Size] of this rect.
  Size get size => Size(width, height);

  /// A copy moved by [by], keeping the same size.
  Rect shift(Offset by) => Rect(x + by.dx, y + by.dy, width, height);

  /// Whether [point] lies inside this rect, with the right and bottom edges
  /// exclusive.
  bool contains(Offset point) => point.dx >= x && point.dx < right && point.dy >= y && point.dy < bottom;

  @override
  bool operator ==(Object other) =>
      other is Rect && other.x == x && other.y == y && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'Rect($x, $y, $width, $height)';
}
