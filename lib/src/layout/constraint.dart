import 'package:meta/meta.dart';

/// A constraint that defines the size of a layout element.
///
/// Constraints can be used to specify a fixed size, a percentage of the available space, a ratio of
/// the available space, a minimum or maximum size or a fill proportional value for a layout
/// element.
///
/// Relative constraints (percentage, ratio) are calculated relative to the entire space being
/// divided, rather than the space available after applying more fixed constraints (min, max,
/// length).
///
/// Constraints are prioritized in the following order:
///
/// 1. [ConstraintMin]
/// 2. [ConstraintMax]
/// 3. [ConstraintLength]
/// 4. [ConstraintPercentage]
/// 5. [ConstraintRatio]
/// 6. [ConstraintFill]
sealed class Constraint {
  const Constraint();
}

/// Applies a minimum size constraint to the element
///
/// The element size is set to at least the specified amount.
///
/// # Examples
///
/// `[Percentage(100), Min(20)]`
///
/// ```plain
/// ┌────────────────────────────┐┌──────────────────┐
/// │            30 px           ││       20 px      │
/// └────────────────────────────┘└──────────────────┘
/// ```
///
/// `[Percentage(100), Min(10)]`
///
/// ```plain
/// ┌──────────────────────────────────────┐┌────────┐
/// │                 40 px                ││  10 px │
/// └──────────────────────────────────────┘└────────┘
/// ```
@immutable
class ConstraintMin extends Constraint {
  /// The constraint value
  final int value;

  /// Creates a new [ConstraintMin] with the specified value.
  const ConstraintMin(this.value);

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (other is ConstraintMin && value == other.value) return true;
    return false;
  }

  @override
  int get hashCode => Object.hash(ConstraintMin, value);

  @override
  String toString() => 'ConstraintMin($value)';
  // coverage:ignore-end
}

/// Applies a maximum size constraint to the element
///
/// The element size is set to at most the specified amount.
///
/// # Examples
///
/// `[Percentage(0), Max(20)]`
///
/// ```plain
/// ┌────────────────────────────┐┌──────────────────┐
/// │            30 px           ││       20 px      │
/// └────────────────────────────┘└──────────────────┘
/// ```
///
/// `[Percentage(0), Max(10)]`
///
/// ```plain
/// ┌──────────────────────────────────────┐┌────────┐
/// │                 40 px                ││  10 px │
/// └──────────────────────────────────────┘└────────┘
/// ```
@immutable
class ConstraintMax extends Constraint {
  /// The constraint value
  final int value;

  /// Creates a new [ConstraintMax] with the specified value.
  const ConstraintMax(this.value);

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (other is ConstraintMax && value == other.value) return true;
    return false;
  }

  @override
  int get hashCode => Object.hash(ConstraintMax, value);

  @override
  String toString() => 'ConstraintMax($value)';
  // coverage:ignore-end
}

/// Applies a length constraint to the element
///
/// The element size is set to the specified amount.
///
/// # Examples
///
/// `[Length(20), Length(20)]`
///
/// ```plain
/// ┌──────────────────┐┌──────────────────┐
/// │       20 px      ││       20 px      │
/// └──────────────────┘└──────────────────┘
/// ```
///
/// `[Length(20), Length(30)]`
///
/// ```plain
/// ┌──────────────────┐┌────────────────────────────┐
/// │       20 px      ││            30 px           │
/// └──────────────────┘└────────────────────────────┘
/// ```
@immutable
class ConstraintLength extends Constraint {
  /// The constraint value
  final int value;

  /// Creates a new [ConstraintLength] with the specified value.
  const ConstraintLength(this.value);

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (other is ConstraintLength && value == other.value) return true;
    return false;
  }

  @override
  int get hashCode => Object.hash(ConstraintLength, value);

  @override
  String toString() => 'ConstraintLength($value)';
  // coverage:ignore-end
}

/// Applies a percentage of the available space to the element
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
/// `[Percentage(75), Fill(1)]`
///
/// ```plain
/// ┌────────────────────────────────────┐┌──────────┐
/// │                38 px               ││   12 px  │
/// └────────────────────────────────────┘└──────────┘
/// ```
///
/// `[Percentage(50), Fill(1)]`
///
/// ```plain
/// ┌───────────────────────┐┌───────────────────────┐
/// │         25 px         ││         25 px         │
/// └───────────────────────┘└───────────────────────┘
/// ```
@immutable
class ConstraintPercentage extends Constraint {
  /// The constraint value
  final int value;

  /// Creates a new [ConstraintPercentage] with the specified value.
  const ConstraintPercentage(this.value);

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (other is ConstraintPercentage && value == other.value) return true;
    return false;
  }

  @override
  int get hashCode => Object.hash(ConstraintPercentage, value);

  @override
  String toString() => 'ConstraintPercentage($value)';
  // coverage:ignore-end
}

/// Applies a ratio of the available space to the element
///
/// Converts the given ratio to a floating-point value and multiplies that with area.
/// This value is rounded back to a integer as part of the layout split calculation.
///
/// # Examples
///
/// `[Ratio(1, 2) ; 2]`
///
/// ```plain
/// ┌───────────────────────┐┌───────────────────────┐
/// │         25 px         ││         25 px         │
/// └───────────────────────┘└───────────────────────┘
/// ```
///
/// `[Ratio(1, 4) ; 4]`
///
/// ```plain
/// ┌───────────┐┌──────────┐┌───────────┐┌──────────┐
/// │   13 px   ││   12 px  ││   13 px   ││   12 px  │
/// └───────────┘└──────────┘└───────────┘└──────────┘
/// ```
@immutable
class ConstraintRatio extends Constraint {
  /// The numerator of the ratio
  final int numerator;

  /// The denominator of the ratio
  final int denominator;

  /// Creates a new [ConstraintRatio] with the specified values.
  const ConstraintRatio(this.numerator, this.denominator);

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (other is ConstraintRatio && numerator == other.numerator && denominator == other.denominator) return true;
    return false;
  }

  @override
  int get hashCode => Object.hash(ConstraintRatio, numerator, denominator);

  @override
  String toString() => 'ConstraintRatio($numerator, $denominator)';
  // coverage:ignore-end
}

/// Applies the scaling factor proportional to all other [`Constraint::Fill`] elements
/// to fill excess space
///
/// The element will only expand or fill into excess available space, proportionally matching
/// other [`Constraint::Fill`] elements while satisfying all other constraints.
///
/// # Examples
///
///
/// `[Fill(1), Fill(2), Fill(3)]`
///
/// ```plain
/// ┌──────┐┌───────────────┐┌───────────────────────┐
/// │ 8 px ││     17 px     ││         25 px         │
/// └──────┘└───────────────┘└───────────────────────┘
/// ```
///
/// `[Fill(1), Percentage(50), Fill(1)]`
///
/// ```plain
/// ┌───────────┐┌───────────────────────┐┌──────────┐
/// │   13 px   ││         25 px         ││   12 px  │
/// └───────────┘└───────────────────────┘└──────────┘
/// ```
@immutable
class ConstraintFill extends Constraint {
  /// The constraint value
  final int value;

  /// Creates a new [ConstraintFill] with the specified value.
  const ConstraintFill(this.value);

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (other is ConstraintFill && value == other.value) return true;
    return false;
  }

  @override
  int get hashCode => Object.hash(ConstraintFill, value);

  @override
  String toString() => 'ConstraintFill($value)';
  // coverage:ignore-end
}
