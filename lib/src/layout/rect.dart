import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../extensions/integer.dart';
import 'margin.dart';
import 'position.dart';
import 'size.dart';

/// A Rectangular area.
///
/// A simple rectangle used in the computation of the layout and to give
/// widgets a hint about the area they are supposed to render to
@immutable
class Rect {
  /// The x coordinate of the rectangle
  final int x;

  /// The y coordinate of the rectangle
  final int y;

  /// The width of the rectangle
  final int width;

  /// The height of the rectangle
  final int height;

  /// The area of the rectangle
  final int area;

  /// The right edge of the rectangle
  final int right;

  /// The bottom edge of the rectangle
  final int bottom;

  /// The left edge of the rectangle (alias for [x])
  final int left;

  /// The top edge of the rectangle (alias for [y])
  final int top;

  const Rect._(this.x, this.y, this.width, this.height)
      : assert(width >= 0 && height >= 0, 'Width and height must be positive'),
        area = width * height,
        right = x + width,
        bottom = y + height,
        left = x,
        top = y;

  /// Created a new [Rect] with all values set to zero
  static const Rect zero = Rect._(0, 0, 0, 0);

  /// Creates a new [Rect], with [width] and [height] limited to keep both
  /// bounds within unsigned 16 bit int. (65535)
  factory Rect.create({
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final maxWidth = u16Max - x;
    final maxHeight = u16Max - y;
    final w = width > maxWidth ? maxWidth : width;
    final h = height > maxHeight ? maxHeight : height;

    return Rect._(x, y, w, h);
  }

  /// Creates a new [Rect] given a [Position] and [Size]
  Rect.fromPositionSize(Position pos, Size size) : this._(pos.x, pos.y, size.width, size.height);

  /// Check if the rectangle is empty
  bool get isEmpty => width == 0 || height == 0;

  /// Returns a new [Rect] inside the current one, with the given margin on
  /// each side.
  /// If the margin is larger than the [Rect], the returned [Rect] will have
  /// no area
  Rect inner(Margin margin) {
    final doubleHorizontal = margin.horizontal.saturatingMul(2);
    final doubleVertical = margin.vertical.saturatingMul(2);

    if (width < doubleHorizontal || height < doubleVertical) {
      return Rect.zero;
    }
    return Rect._(
      x.saturatingAdd(margin.horizontal),
      y.saturatingAdd(margin.vertical),
      width.saturatingSub(doubleHorizontal),
      height.saturatingSub(doubleVertical),
    );
  }

  /// Moves the [Rect] without modifying its size.
  ///
  /// Moves the [Rect] according to the given offset without modifying its [width]
  /// or [height]
  Rect offset(Offset offset) {
    return copyWith(
      x: x.saturatingAdd(offset.x).clamp(0, u16Max - width),
      y: y.saturatingAdd(offset.y).clamp(0, u16Max - height),
    );
  }

  /// Returns a new [Rect] that contains both the current one and the given one
  Rect union(Rect other) {
    final x = math.min(this.x, other.x);
    final y = math.min(this.y, other.y);
    final width = math.max(right, other.right);
    final height = math.max(bottom, other.bottom);
    return Rect._(
      x,
      y,
      width.saturatingSub(x),
      height.saturatingSub(y),
    );
  }

  /// Returns a new [Rect] that is the intersection of the current one and the
  /// given one.
  ///
  /// If the two [Rect]s do not intersect, the returned [Rect] will have no area.
  Rect intersection(Rect other) {
    final x = math.max(this.x, other.x);
    final y = math.max(this.y, other.y);
    final width = math.min(right, other.right);
    final height = math.min(bottom, other.bottom);
    return Rect._(
      x,
      y,
      width.saturatingSub(x),
      height.saturatingSub(y),
    );
  }

  /// Returns true if the two [Rect]s intersect
  bool intersects(Rect other) {
    return x < other.right && right > other.x && y < other.bottom && bottom > other.y;
  }

  /// Returns true if the given position is inside the [Rect].
  ///
  /// The position is considered inside the [Rect] if it is on the [Rect]'s
  /// border.
  ///
  /// ```dart
  /// final rect = Rect.create(1, 2, 3, 4);
  /// assert(rect.contains(Position(1, 2));
  /// ````
  bool contains(Position pos) {
    return pos.x >= x && pos.x < right && pos.y >= y && pos.y < bottom;
  }

  /// Clamp this [Rect] to fit inside the other [Rect].
  ///
  /// If the width or height of this [Rect] is larger than the other [Rect], it
  /// will be clamped to the other [Rect]'s width or height.
  ///
  /// If the left or top coordinate of this [Rect] is smaller than the other
  /// [Rect], it will be clamped to the other `Rect`'s left or top coordinate.
  ///
  /// If the right or bottom coordinate of this [Rect] is larger than the other
  /// [Rect], it will be clamped to the other `Rect`'s right or bottom
  /// coordinate.
  ///
  /// This is different from [Rect.intersection] because it will move this
  /// [Rect] to fit inside the other [Rect], while [Rect.intersection] instead
  /// would keep this [Rect]'s position and truncate its size to only that
  /// which is inside the other [Rect].
  Rect clamp(Rect other) {
    final width = math.min(this.width, other.width);
    final height = math.min(this.height, other.height);
    final x = this.x.clamp(other.x, other.right.saturatingSub(width));
    final y = this.y.clamp(other.y, other.bottom.saturatingSub(height));
    return Rect._(x, y, width, height);
  }

  /// An iterator over rows within the [Rect].
  Rows get rows => Rows(this);

  /// An iterator over columns within the [Rect].
  Columns get columns => Columns(this);

  /// An iterator over the positions within the [Rect].
  ///
  /// The positions are returned in a row-major order (left-to-right, top-to-bottom
  Positions get positions => Positions(this);

  /// Returns a [Position] with the same coordinates as this [Rect]
  Position get asPosition => Position(x, y);

  /// Converts the [Rect] into a [Size] object.
  Size get asSize => Size(width, height);

  /// indents the x value of the [Rect] by a given offset
  Rect indentX(int offset) => copyWith(
        x: x.saturatingAdd(offset),
        width: width.saturatingSub(offset),
      );

  /// Creates a new [Rect] with the base values of this [Rect] and the given
  /// values.
  Rect copyWith({int? x, int? y, int? width, int? height}) {
    return Rect._(x ?? this.x, y ?? this.y, width ?? this.width, height ?? this.height);
  }

  @override
  String toString() {
    return 'Rect(${x}x$y+$width+$height)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rect && x == other.x && y == other.y && width == other.width && height == other.height;
  }

  @override
  int get hashCode => Object.hash(Rect, x, y, width, height);
}

/// Amounts by which to move a [Rect]
///
/// Positive numbers move to the right/bottom and negative to the left/top.
@immutable
class Offset {
  /// The horizontal offset
  final int x;

  /// The vertical offset
  final int y;

  /// Creates a new [Offset] with the given values
  const Offset(this.x, this.y);
}

/// An iterator over columns within a [Rect]
class Columns extends Iterable<Rect> {
  /// The [Rect] to iterate over
  final Rect rect;

  /// Creates a new [Columns] iterator for the given [Rect]
  Columns(this.rect);

  /// Returns an iterator over the columns within the [Rect]
  @override
  Iterator<Rect> get iterator => _ColumnIterator(rect);
}

class _ColumnIterator implements Iterator<Rect> {
  final Rect rect;
  int index = -1;
  // ignore: use_late_for_private_fields_and_variables
  Rect? _current;

  _ColumnIterator(this.rect);

  @override
  bool moveNext() {
    index++;
    if (index >= rect.right) return false;
    _current = Rect._(rect.x + index, rect.y, 1, rect.height);
    return true;
  }

  @override
  Rect get current => _current!;
}

/// An iterator over rows within a [Rect]
class Rows extends Iterable<Rect> {
  /// The [Rect] to iterate over
  final Rect rect;

  /// Creates a new [Rows] iterator for the given [Rect]
  Rows(this.rect);

  /// Returns an iterator over the rows within the [Rect]
  @override
  Iterator<Rect> get iterator => _RowIterator(rect);
}

class _RowIterator implements Iterator<Rect> {
  final Rect rect;
  int index = -1;
  // ignore: use_late_for_private_fields_and_variables
  Rect? _current;

  _RowIterator(this.rect);

  @override
  bool moveNext() {
    index++;
    if (index >= rect.bottom) return false;
    _current = Rect._(rect.x, rect.y + index, rect.width, 1);
    return true;
  }

  @override
  Rect get current => _current!;
}

/// An iterator over positions within a [Rect]
class Positions extends Iterable<Position> {
  /// The [Rect] to iterate over
  final Rect rect;

  /// Creates a new [Positions] iterator for the given [Rect]
  Positions(this.rect);

  /// Returns an iterator over the positions within the [Rect]
  @override
  Iterator<Position> get iterator => _PositionIterator(rect);
}

class _PositionIterator implements Iterator<Position> {
  final Rect rect;
  int indexX;
  int indexY;
  // ignore: use_late_for_private_fields_and_variables
  Position? _current;

  _PositionIterator(this.rect)
      : indexX = rect.x,
        indexY = rect.y;

  @override
  bool moveNext() {
    if (indexY >= rect.bottom) return false;

    _current = Position(indexX, indexY);
    indexX++;
    if (indexX > rect.right) {
      indexX = rect.x;
      indexY++;
    }

    return true;
  }

  @override
  Position get current => _current!;
}
