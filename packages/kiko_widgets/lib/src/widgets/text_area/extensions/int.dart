/// Max value for a 32-bit signed integer.
const i32Max = 0x7FFFFFFF;

/// Extension methods for signed 32-bit saturating arithmetic.
///
/// Operations clamp results to [0, i32Max] range.
extension SaturatingI32 on int {
  /// Saturating i32 subtraction. Computes `this - other`, clamping at 0 if
  /// underflow would occur.
  ///
  /// Example:
  /// ```dart
  /// 10.saturatingSubI32(3);  // 7
  /// 5.saturatingSubI32(10);  // 0 (clamped)
  /// ```
  int saturatingSubI32(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    final result = this - other;
    return result < 0 ? 0 : result;
  }

  /// Saturating i32 addition. Computes `this + other`, clamping at [i32Max] if
  /// overflow would occur.
  ///
  /// Example:
  /// ```dart
  /// 100.saturatingAddI32(50);     // 150
  /// i32Max.saturatingAddI32(100); // 2147483647 (clamped)
  /// ```
  int saturatingAddI32(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this + other).clamp(0, i32Max);
  }

  /// Saturating i32 multiplication. Computes `this * other`, clamping at
  /// [i32Max] if overflow would occur.
  ///
  /// Example:
  /// ```dart
  /// 10.saturatingMulI32(12);    // 120
  /// i32Max.saturatingMulI32(2); // 2147483647 (clamped)
  /// ```
  int saturatingMulI32(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this * other).clamp(0, i32Max);
  }
}
