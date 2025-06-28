/// Max value for a 16-bit unsigned integer.
const u16Max = 65535;

/// Max value for a 32-bit unsigned integer.
const u32Max = 4294967295;

/// Max value for a 16-bit signed integer.
const i16Max = 32767;

/// Min value for a 16-bit signed integer.
const i16Min = -32768;

/// Extension methods for integers.
extension IntegerUtils on int {
  /// Subtracts the given integer [other] from this integer, but ensures that
  /// the result does not go below zero. If the subtraction would result in a
  /// negative value, the result is clamped to zero.
  ///
  /// Example:
  /// ```dart
  /// int result = 5.saturatingSub(10); // result will be 0
  /// int result = 10.saturatingSub(3); // result will be 7
  /// ```
  ///
  /// Returns the result of the subtraction, clamped to zero if necessary.
  int saturatingSub(int other) {
    if (this < 0 || other < 0) throw ArgumentError('Values must be positive');
    final result = this - other;
    return result < 0 ? 0 : result;
  }

  /// Adds the given integer to the current integer, but if the result exceeds
  /// the maximum value an integer can hold, it will return the maximum value.
  /// If the result is less than the minimum value an integer can hold, it will
  /// return the minimum value.
  ///
  /// This is useful to prevent overflow and underflow when performing arithmetic
  /// operations.
  ///
  /// Example:
  /// ```dart
  /// int a = 2147483647; // Max value for a 32-bit signed integer
  /// int b = 1;
  /// int result = a.saturatingAdd(b); // result will be 2147483647
  /// ```
  int saturatingAdd(int other) {
    final result = this + other;
    return result > u16Max ? u16Max : result;
  }

  /// Multiplies this integer by [other] and returns the result. If the result
  /// overflows, it will saturate at the maximum or minimum value of an integer.
  ///
  /// Example:
  /// ```dart
  /// int result = 1000000000.saturatingMul(1000000000);
  /// print(result); // Prints the maximum value of an integer.
  /// ```
  int saturatingMul(int other) {
    final result = this * other;
    return result > u16Max ? u16Max : result;
  }

  /// Performs a saturating division of this integer by [other].
  ///
  /// If [other] is zero, returns the maximum value of an integer to avoid
  /// division by zero errors.
  int saturatingDiv(int other) {
    if (this < 0 || other < 0) throw ArgumentError('Values must be positive');
    final result = this ~/ other;
    return result > u16Max ? u16Max : result;
  }

  /// Adds the given integer to this integer, wrapping around at the maximum
  /// value of an integer if necessary.
  ///
  /// This method performs an addition that wraps around at the maximum value
  /// of an integer, which means that if the result exceeds the maximum value
  /// of an integer, it will wrap around to the minimum value and continue
  /// from there.
  int wrappingAdd(int other) {
    final result = this + other;
    return (result > u32Max) ? 0 : result;
  }
}
