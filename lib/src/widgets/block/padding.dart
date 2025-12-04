import 'package:meta/meta.dart';

/// Defines the edge insets (padding/margin) for widgets.
@immutable
class EdgeInsets {
  /// The left inset.
  final int left;

  /// The right inset.
  final int right;

  /// The top inset.
  final int top;

  /// The bottom inset.
  final int bottom;

  /// Creates a new [EdgeInsets] with the given values.
  const EdgeInsets({
    this.top = 0,
    this.left = 0,
    this.bottom = 0,
    this.right = 0,
  });

  /// Returns an [EdgeInsets] with all values set to 0.
  const EdgeInsets.zero() : top = 0, left = 0, bottom = 0, right = 0;

  /// Returns an [EdgeInsets] with all values set to the given value.
  const EdgeInsets.all(int value) : top = value, left = value, bottom = value, right = value;

  /// Returns an [EdgeInsets] with the horizontal and vertical values set to the
  /// given value for [horizontal] and [vertical] respectively.
  const EdgeInsets.symmetric({int horizontal = 0, int vertical = 0})
    : top = vertical,
      left = horizontal,
      bottom = vertical,
      right = horizontal;

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EdgeInsets &&
        other.left == left &&
        other.right == right &&
        other.top == top &&
        other.bottom == bottom;
  }

  @override
  int get hashCode {
    return Object.hash(EdgeInsets, left, right, top, bottom);
  }

  // coverage:ignore-end
}
