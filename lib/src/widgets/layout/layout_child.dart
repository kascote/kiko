import 'package:meta/meta.dart';

import '../../layout/constraint.dart';
import '../frame.dart';

/// Contract pairing a [Constraint] with a [Widget] for layout purposes.
///
/// This is a sealed interface - only [Fixed], [MinSize], [Percent], and
/// [Expanded] can implement it.
@immutable
sealed class LayoutChild {
  /// The constraint defining how much space this child requests.
  Constraint get constraint;

  /// The widget to render in the allocated space.
  Widget get child;
}

/// A layout child with a fixed size.
///
/// Uses [ConstraintLength] internally.
@immutable
class Fixed implements LayoutChild {
  @override
  final Constraint constraint;

  @override
  final Widget child;

  /// Creates a fixed-size layout child.
  ///
  /// [value] is the exact size in cells.
  Fixed(int value, {required this.child}) : constraint = ConstraintLength(value);
}

/// A layout child with a minimum size.
///
/// Uses [ConstraintMin] internally.
@immutable
class MinSize implements LayoutChild {
  @override
  final Constraint constraint;

  @override
  final Widget child;

  /// Creates a minimum-size layout child.
  ///
  /// [value] is the minimum size in cells.
  MinSize(int value, {required this.child}) : constraint = ConstraintMin(value);
}

/// A layout child sized as a percentage of available space.
///
/// Uses [ConstraintPercentage] internally.
@immutable
class Percent implements LayoutChild {
  @override
  final Constraint constraint;

  @override
  final Widget child;

  /// Creates a percentage-based layout child.
  ///
  /// [value] is the percentage (0-100) of available space.
  Percent(int value, {required this.child}) : constraint = ConstraintPercentage(value);
}

/// A layout child that expands to fill available space.
///
/// Uses [ConstraintFill] internally. Multiple [Expanded] children share
/// space proportionally based on their weight.
@immutable
class Expanded implements LayoutChild {
  @override
  final Constraint constraint;

  @override
  final Widget child;

  /// Creates an expanded layout child.
  ///
  /// The weight determines the proportion of remaining space (default 1).
  Expanded({required this.child, int weight = 1}) : constraint = ConstraintFill(weight);
}

/// A layout child with an arbitrary constraint.
///
/// Use this when you need a constraint type not covered by [Fixed], [MinSize],
/// [Percent], or [Expanded], or when building higher-order widgets like Grid.
@immutable
class ConstraintChild implements LayoutChild {
  @override
  final Constraint constraint;

  @override
  final Widget child;

  /// Creates a layout child with a custom constraint.
  const ConstraintChild(this.constraint, {required this.child});
}
