import 'package:meta/meta.dart';

/// Cell insets on the four sides of a box.
@immutable
class EdgeInsets {
  /// Insets each side independently; unspecified sides default to `0`.
  const EdgeInsets.only({this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  /// The same inset [value] on all four sides.
  const EdgeInsets.all(int value) : left = value, top = value, right = value, bottom = value;

  /// [horizontal] on the left and right, [vertical] on the top and bottom.
  const EdgeInsets.symmetric({int horizontal = 0, int vertical = 0})
    : left = horizontal,
      right = horizontal,
      top = vertical,
      bottom = vertical;

  /// No inset on any side.
  static const EdgeInsets zero = EdgeInsets.all(0);

  /// Left inset in cells.
  final int left;

  /// Top inset in cells.
  final int top;

  /// Right inset in cells.
  final int right;

  /// Bottom inset in cells.
  final int bottom;

  /// Total horizontal inset ([left] + [right]).
  int get horizontal => left + right;

  /// Total vertical inset ([top] + [bottom]).
  int get vertical => top + bottom;

  @override
  bool operator ==(Object other) =>
      other is EdgeInsets && other.left == left && other.top == top && other.right == right && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'EdgeInsets($left, $top, $right, $bottom)';
}
