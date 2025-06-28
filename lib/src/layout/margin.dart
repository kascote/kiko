import 'package:meta/meta.dart';

/// A class that represents margin properties for layout purposes.
@immutable
class Margin {
  /// The horizontal margin value.
  final int horizontal;

  /// The vertical margin value.
  final int vertical;

  /// Creates a margin with the given horizontal and vertical values.
  const Margin(this.horizontal, this.vertical);

  /// Creates a margin initialized with zero values
  static const Margin zero = Margin(0, 0);

  @override
  String toString() {
    return 'Margin($horizontal, $vertical)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Margin && other.horizontal == horizontal && other.vertical == vertical;
  }

  @override
  int get hashCode {
    return Object.hash(Margin, horizontal, vertical);
  }
}
