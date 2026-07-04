import 'dart:math';

import 'package:meta/meta.dart';

import 'position.dart';
import 'rect.dart';

/// A class that represents the dimensions of an object.
///
/// The [TermSize] class provides properties for width and height, and methods
/// to manipulate and compare sizes.
@immutable
class TermSize {
  /// The value that represent the width
  final int width;

  /// The value that represent the height
  final int height;

  /// Creates a TermSize object with the given [width] and [height].
  const TermSize(this.width, this.height);

  /// Creates a TermSize object with zero width and height.
  static const TermSize zero = TermSize(0, 0);

  /// Creates a TermSize object from a [Point] object.
  TermSize.fromPoint(TPoint size) : this(size.x, size.y);

  /// Creates a TermSize object from a [Rect] object.
  TermSize.fromRect(Rect rect) : this(rect.width, rect.height);

  @override
  String toString() {
    return 'TermSize(${width}x$height)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is TermSize) {
      return width == other.width && height == other.height;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(TermSize, width, height);
}
