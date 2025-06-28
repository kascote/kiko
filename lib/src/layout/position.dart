import 'package:meta/meta.dart';

import 'rect.dart';

/// A record that represents position in a 2D space.
typedef TPoint = ({int x, int y});

/// Utility methods for [TPoint] records.
extension TPointUtils on TPoint {
  /// Returns a new [Position] instance from the current [TPoint].
  Position toPos() => Position(x, y);
}

/// A class representing a position with specific coordinates.
///
/// This class can be used to define and manipulate positions in a 2D space.
///
/// Example usage:
///
/// ```dart
/// Position position = Position(x: 10, y: 20);
/// print(position.x); // Output: 10
/// print(position.y); // Output: 20
/// ```
@immutable
class Position {
  /// The x-coordinate of this position.
  final int x;

  /// The y-coordinate of this position.
  final int y;

  /// Creates a new [Position] instance with the specified [x] and [y] coordinates.
  const Position(this.x, this.y);

  /// Creates a new [Position] instance with the origin coordinates (0, 0).
  static const Position origin = Position(0, 0);

  /// Creates a new [Position] instance from a [TPoint] record.
  Position.fromPoint(TPoint pos) : this(pos.x, pos.y);

  /// Creates a new [Position] instance from another [Position] instance.
  Position.fromPosition(Position pos) : this(pos.x, pos.y);

  /// Creates a new [Position] instance from a [Rect] instance.
  Position.fromRect(Rect rect) : this(rect.x, rect.y);

  /// Returns a [TPoint] from this position.
  TPoint toPoint() => (x: x, y: y);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Position) {
      return x == other.x && y == other.y;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Position, x, y);

  @override
  String toString() => 'Position($x, $y)';
}
