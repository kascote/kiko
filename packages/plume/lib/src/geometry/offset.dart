import 'package:meta/meta.dart';

/// A displacement in whole cells from an origin, used to place a child within
/// its parent.
///
/// Parents assign each child an [Offset]; summing offsets down the tree yields a
/// node's absolute position on the grid.
@immutable
class Offset {
  /// Creates an offset of [dx] cells right and [dy] cells down.
  const Offset(this.dx, this.dy);

  /// The zero displacement (the origin).
  static const Offset zero = Offset(0, 0);

  /// Horizontal displacement in cells; positive is rightward.
  final int dx;

  /// Vertical displacement in cells; positive is downward.
  final int dy;

  /// The component-wise sum with [other].
  Offset operator +(Offset other) => Offset(dx + other.dx, dy + other.dy);

  /// The component-wise difference from [other].
  Offset operator -(Offset other) => Offset(dx - other.dx, dy - other.dy);

  @override
  bool operator ==(Object other) => other is Offset && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset($dx, $dy)';
}
