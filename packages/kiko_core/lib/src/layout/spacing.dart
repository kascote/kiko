import 'package:meta/meta.dart';

import '../extensions/integer.dart';

/// Represents the spacing between segments in a layout.
///
/// The [Spacing] class is used to define the spacing between segments in a
/// layout. It can represent either positive spacing (space between segments)
/// or negative spacing (overlap between segments).
@immutable
sealed class Spacing {
  /// The value of the spacing.
  final int value;

  /// Created an [Space] object if the value is positive and an [Overlap]
  /// object if the value is negative.
  factory Spacing(int value) {
    value = value.clamp(i16Min, i16Max);
    return value < 0 ? Overlap(value) : Space(value);
  }

  Spacing._(int value) : value = value.abs();
}

/// Represents the spacing between segments in a layout.
@immutable
class Space extends Spacing {
  /// Creates a new [Space] object with the given value.
  Space(super.value) : super._();

  @override
  String toString() => 'Space($value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Space && other.value == value;
  }

  @override
  int get hashCode => Object.hash(Space, value);
}

/// Represents the overlap between segments in a layout.
@immutable
class Overlap extends Spacing {
  /// Creates a new [Overlap] object with the given value.
  Overlap(super.value) : super._();

  @override
  String toString() => 'Overlap($value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Overlap && other.value == value;
  }

  @override
  int get hashCode => Object.hash(Overlap, value);
}
