/// Max value for a 16-bit unsigned integer.
const u16Max = 65535;

/// Max value for a 32-bit unsigned integer.
const u32Max = 4294967295;

/// Max value for a 16-bit signed integer.
const i16Max = 32767;

/// Min value for a 16-bit signed integer.
const i16Min = -32768;

/// Extension methods for unsigned 16-bit saturating arithmetic.
extension SaturatingU16 on int {
  /// Saturating u16 subtraction. Computes `this - other`, clamping at 0 if
  /// underflow would occur.
  ///
  /// Note: Only clamps underflow (to 0), not overflow at u16Max. Unlike Rust's
  /// u16 type which cannot hold values > 65535, Dart's int can. Clamping the
  /// output at u16Max would break calculations for values > u16Max (e.g., text
  /// line skip-width calculations where line width exceeds u16Max).
  ///
  /// Example:
  /// ```dart
  /// 10.saturatingSubU16(3);  // 7
  /// 5.saturatingSubU16(10);  // 0 (clamped)
  /// 65659.saturatingSubU16(32);  // 65627 (not clamped to u16Max)
  /// ```
  int saturatingSubU16(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    final result = this - other;
    return result < 0 ? 0 : result;
  }

  /// Saturating u16 addition. Computes `this + other`, clamping at [u16Max] if
  /// overflow would occur.
  ///
  /// Example:
  /// ```dart
  /// 100.saturatingAddU16(50);      // 150
  /// u16Max.saturatingAddU16(100);  // 65535 (clamped)
  /// ```
  int saturatingAddU16(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this + other).clamp(0, u16Max);
  }

  /// Saturating u16 multiplication. Computes `this * other`, clamping at
  /// [u16Max] if overflow would occur.
  ///
  /// Example:
  /// ```dart
  /// 10.saturatingMulU16(12);      // 120
  /// u16Max.saturatingMulU16(2);   // 65535 (clamped)
  /// ```
  int saturatingMulU16(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this * other).clamp(0, u16Max);
  }

  /// Saturating u16 division. Computes `this ~/ other`.
  ///
  /// For unsigned types overflow is not possible, so this is equivalent to
  /// integer division. Throws on division by zero.
  ///
  /// Example:
  /// ```dart
  /// 100.saturatingDivU16(10);  // 10
  /// ```
  int saturatingDivU16(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this ~/ other).clamp(0, u16Max);
  }
}

/// Extension methods for unsigned 16-bit wrapping arithmetic.
extension WrappingU16 on int {
  /// Wrapping u16 addition. Computes `this + other`, wrapping around at
  /// [u16Max] using modular arithmetic.
  ///
  /// Example:
  /// ```dart
  /// 200.wrappingAddU16(100);    // 300
  /// u16Max.wrappingAddU16(1);   // 0 (wrapped)
  /// u16Max.wrappingAddU16(10);  // 9 (wrapped)
  /// ```
  int wrappingAddU16(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this + other) % (u16Max + 1);
  }

  /// Wrapping u16 subtraction. Computes `this - other`, wrapping around at
  /// 0 using modular arithmetic.
  ///
  /// Example:
  /// ```dart
  /// 100.wrappingSubU16(50);  // 50
  /// 0.wrappingSubU16(1);     // 65535 (wrapped)
  /// 5.wrappingSubU16(10);    // 65531 (wrapped)
  /// ```
  int wrappingSubU16(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    final result = this - other;
    return result < 0 ? (u16Max + 1 + result) % (u16Max + 1) : result;
  }

  /// Wrapping u16 multiplication. Computes `this * other`, wrapping around at
  /// [u16Max] using modular arithmetic.
  ///
  /// Example:
  /// ```dart
  /// 10.wrappingMulU16(12);      // 120
  /// 1000.wrappingMulU16(1000);  // 16960 (wrapped: 1000000 % 65536)
  /// ```
  int wrappingMulU16(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this * other) % (u16Max + 1);
  }
}

/// Extension methods for unsigned 32-bit wrapping arithmetic.
extension WrappingU32 on int {
  /// Wrapping u32 addition. Computes `this + other`, wrapping around at
  /// [u32Max] using modular arithmetic.
  ///
  /// Example:
  /// ```dart
  /// 100.wrappingAddU32(50);   // 150
  /// u32Max.wrappingAddU32(1); // 0 (wrapped)
  /// ```
  int wrappingAddU32(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    return (this + other) % (u32Max + 1);
  }

  /// Wrapping u32 subtraction. Computes `this - other`, wrapping around at
  /// 0 using modular arithmetic.
  ///
  /// Example:
  /// ```dart
  /// 100.wrappingSubU32(50);  // 50
  /// 0.wrappingSubU32(1);     // 4294967295 (wrapped)
  /// ```
  int wrappingSubU32(int other) {
    assert(this >= 0 && other >= 0, 'Values must be non-negative');
    final result = this - other;
    return result < 0 ? (u32Max + 1 + result) % (u32Max + 1) : result;
  }
}
