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
  /// The element size is set to the specified [value].
  ///
  /// # Examples
  ///
  /// `[Fixed(20), Fixed(20)]`
  ///
  /// ```plain
  /// ┌──────────────────┐┌──────────────────┐
  /// │       20 px      ││       20 px      │
  /// └──────────────────┘└──────────────────┘
  /// ```
  ///
  /// `[Fixed(20), Fixed(30)]`
  ///
  /// ```plain
  /// ┌──────────────────┐┌────────────────────────────┐
  /// │       20 px      ││            30 px           │
  /// └──────────────────┘└────────────────────────────┘
  /// ```
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
  /// The element size is set to at least the specified [value] .
  ///
  /// # Examples
  ///
  /// `[Percent(100), MinSize(20)]`
  ///
  /// ```plain
  /// ┌────────────────────────────┐┌──────────────────┐
  /// │            30 px           ││       20 px      │
  /// └────────────────────────────┘└──────────────────┘
  /// ```
  ///
  /// `[Percent(100), MinSize(10)]`
  ///
  /// ```plain
  /// ┌──────────────────────────────────────┐┌────────┐
  /// │                 40 px                ││  10 px │
  /// └──────────────────────────────────────┘└────────┘
  /// ```
  MinSize(int value, {required this.child}) : constraint = ConstraintMin(value);
}

/// A layout child with a maximum size.
///
/// Uses [ConstraintMax] internally.
@immutable
class MaxSize implements LayoutChild {
  @override
  final Constraint constraint;

  @override
  final Widget child;

  /// Creates a minimum-size layout child.
  ///
  /// The element size is set to at most the specified [value] .
  ///
  /// # Examples
  ///
  /// `[Percent(0), Max(20)]`
  ///
  /// ```plain
  /// ┌────────────────────────────┐┌──────────────────┐
  /// │            30 px           ││       20 px      │
  /// └────────────────────────────┘└──────────────────┘
  /// ```
  ///
  /// `[Percent(0), Max(10)]`
  ///
  /// ```plain
  /// ┌──────────────────────────────────────┐┌────────┐
  /// │                 40 px                ││  10 px │
  /// └──────────────────────────────────────┘└────────┘
  /// ```
  MaxSize(int value, {required this.child}) : constraint = ConstraintMax(value);
}

/// A layout child sized as a percentage of available space.
///
/// Uses [ConstraintPercent] internally.
@immutable
class Percent implements LayoutChild {
  @override
  final Constraint constraint;

  @override
  final Widget child;

  /// Creates a percentage-based layout child.
  ///
  /// [value] is the percentage (0-100) of available space.
  ///
  /// Converts the given percentage to a floating-point value and multiplies that with area. This
  /// value is rounded back to a integer as part of the layout split calculation.
  ///
  /// **Note**: As this value only accepts a `int`, certain percentages that cannot be
  /// represented exactly (e.g. 1/3) are not possible. You might want to use
  /// [Constraint::Ratio] or [Constraint::Fill] in such cases.
  ///
  /// # Examples
  ///
  /// `[Percent(75), Fill(1)]`
  ///
  /// ```plain
  /// ┌────────────────────────────────────┐┌──────────┐
  /// │                38 px               ││   12 px  │
  /// └────────────────────────────────────┘└──────────┘
  /// ```
  ///
  /// `[Percent(50), Fill(1)]`
  ///
  /// ```plain
  /// ┌───────────────────────┐┌───────────────────────┐
  /// │         25 px         ││         25 px         │
  /// └───────────────────────┘└───────────────────────┘
  /// ```
  Percent(int value, {required this.child}) : constraint = ConstraintPercent(value);
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
  ///
  /// Applies the scaling factor proportional to all other [`Constraint::Fill`] elements
  /// to fill excess space
  ///
  /// The element will only expand or fill into excess available space, proportionally matching
  /// other [`Fill`] elements while satisfying all other constraints.
  ///
  /// # Examples
  ///
  ///
  /// `[Expanded(1), Expanded(2), Expanded(3)]`
  ///
  /// ```plain
  /// ┌──────┐┌───────────────┐┌───────────────────────┐
  /// │ 8 px ││     17 px     ││         25 px         │
  /// └──────┘└───────────────┘└───────────────────────┘
  /// ```
  ///
  /// `[Expanded(1), Percentage(50), Expanded(1)]`
  ///
  /// ```plain
  /// ┌───────────┐┌───────────────────────┐┌──────────┐
  /// │   13 px   ││         25 px         ││   12 px  │
  /// └───────────┘└───────────────────────┘└──────────┘
  /// ```
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
