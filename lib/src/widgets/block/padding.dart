import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// Defines the padding for a [Block].
@immutable
class Padding {
  /// The left padding.
  final int left;

  /// The right padding.
  final int right;

  /// The top padding.
  final int top;

  /// The bottom padding.
  final int bottom;

  /// Creates a new [Padding] with the given values.
  const Padding({
    this.top = 0,
    this.left = 0,
    this.bottom = 0,
    this.right = 0,
  });

  /// Returns a [Padding] with all values set to 0.
  const Padding.zero()
      : top = 0,
        left = 0,
        bottom = 0,
        right = 0;

  /// Returns a [Padding] with all values set to the given value.
  const Padding.all(int value)
      : top = value,
        left = value,
        bottom = value,
        right = value;

  /// Returns a [Padding] with the horizontal and vertical values set to the
  /// given value for [horizontal] and [vertical] respectively.
  const Padding.symmetric({int horizontal = 0, int vertical = 0})
      : top = horizontal,
        left = vertical,
        bottom = horizontal,
        right = vertical;

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Padding && other.left == left && other.right == right && other.top == top && other.bottom == bottom;
  }

  @override
  int get hashCode {
    return Object.hash(Padding, left, right, top, bottom);
  }
  // coverage:ignore-end
}
