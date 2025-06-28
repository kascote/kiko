import 'dart:math';

import 'package:meta/meta.dart';

import 'position.dart';
import 'rect.dart';

/// A class that represents the dimensions of an object.
///
/// The [Size] class provides properties for width and height, and methods
/// to manipulate and compare sizes.
@immutable
class Size {
  /// The value that represent the width
  final int width;

  /// The value that represent the height
  final int height;

  /// Creates a Size object with the given [width] and [height].
  const Size(this.width, this.height);

  /// Creates a Size object with zero width and height.
  static const Size zero = Size(0, 0);

  /// Creates a Size object from a [Point] object.
  Size.fromPoint(TPoint size) : this(size.x, size.y);

  /// Creates a Size object from a [Rect] object.
  Size.fromRect(Rect rect) : this(rect.width, rect.height);

  @override
  String toString() {
    return 'Size(${width}x$height)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Size) {
      return width == other.width && height == other.height;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Size, width, height);
}
