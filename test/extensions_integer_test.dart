import 'package:kiko/iterators.dart';
import 'package:test/test.dart';

void main() {
  group('SaturatingU16', () {
    test('saturatingSubU16', () {
      expect(10.saturatingSubU16(5), equals(5));
      expect(5.saturatingSubU16(10), equals(0));
      expect(0.saturatingSubU16(0), equals(0));
      expect(100.saturatingSubU16(100), equals(0));
      expect(u16Max.saturatingSubU16(1), equals(u16Max - 1));
      expect(u16Max.saturatingSubU16(u16Max), equals(0));
    });

    // Subtraction only clamps underflow (to 0), not overflow at u16Max.
    // Unlike Rust's u16 which can't hold values > 65535, Dart's int can.
    // Clamping output at u16Max would break calculations like skip-width
    // for text lines wider than u16Max (e.g., 65659 - 32 should be 65627,
    // not clamped to 65535).
    test('saturatingSubU16 with inputs > u16Max', () {
      expect(65659.saturatingSubU16(32), equals(65627));
      expect((u16Max + 100).saturatingSubU16(50), equals(u16Max + 50));
      // still clamps underflow to 0
      expect(100.saturatingSubU16(u16Max + 1000), equals(0));
    });

    test('saturatingAddU16', () {
      expect(10.saturatingAddU16(5), equals(15));
      expect(0.saturatingAddU16(0), equals(0));
      expect(100.saturatingAddU16(50), equals(150));
      // overflow clamps to u16Max
      expect(u16Max.saturatingAddU16(1), equals(u16Max));
      expect(u16Max.saturatingAddU16(100), equals(u16Max));
      expect((u16Max - 5).saturatingAddU16(10), equals(u16Max));
    });

    test('saturatingMulU16', () {
      expect(10.saturatingMulU16(5), equals(50));
      expect(0.saturatingMulU16(10), equals(0));
      expect(10.saturatingMulU16(0), equals(0));
      expect(10.saturatingMulU16(12), equals(120));
      // overflow clamps to u16Max
      expect(u16Max.saturatingMulU16(2), equals(u16Max));
      expect(1000.saturatingMulU16(1000), equals(u16Max));
    });

    test('saturatingDivU16', () {
      expect(10.saturatingDivU16(2), equals(5));
      expect(100.saturatingDivU16(10), equals(10));
      expect(u16Max.saturatingDivU16(1), equals(u16Max));
      expect(0.saturatingDivU16(10), equals(0));
      // division by zero throws
      expect(() => 10.saturatingDivU16(0), throwsA(isA<UnsupportedError>()));
    });
  });

  group('WrappingU16', () {
    test('wrappingAddU16', () {
      expect(10.wrappingAddU16(5), equals(15));
      expect(0.wrappingAddU16(0), equals(0));
      expect(200.wrappingAddU16(100), equals(300));
      // overflow wraps
      expect(u16Max.wrappingAddU16(1), equals(0));
      expect(u16Max.wrappingAddU16(10), equals(9));
      expect((u16Max - 5).wrappingAddU16(10), equals(4));
    });

    test('wrappingSubU16', () {
      expect(10.wrappingSubU16(5), equals(5));
      expect(100.wrappingSubU16(50), equals(50));
      expect(0.wrappingSubU16(0), equals(0));
      // underflow wraps
      expect(0.wrappingSubU16(1), equals(u16Max));
      expect(5.wrappingSubU16(10), equals(u16Max - 4));
      expect(0.wrappingSubU16(u16Max), equals(1));
    });

    test('wrappingMulU16', () {
      expect(10.wrappingMulU16(5), equals(50));
      expect(10.wrappingMulU16(12), equals(120));
      expect(0.wrappingMulU16(10), equals(0));
      // overflow wraps (1000 * 1000 = 1000000, 1000000 % 65536 = 16960)
      expect(1000.wrappingMulU16(1000), equals(16960));
      // 65535 * 2 = 131070 % 65536 = 65534
      expect(u16Max.wrappingMulU16(2), equals(u16Max - 1));
    });
  });

  group('WrappingU32', () {
    test('wrappingAddU32', () {
      expect(10.wrappingAddU32(5), equals(15));
      expect(0.wrappingAddU32(0), equals(0));
      expect(100.wrappingAddU32(50), equals(150));
      // overflow wraps
      expect(u32Max.wrappingAddU32(1), equals(0));
      expect(u32Max.wrappingAddU32(10), equals(9));
    });

    test('wrappingSubU32', () {
      expect(10.wrappingSubU32(5), equals(5));
      expect(100.wrappingSubU32(50), equals(50));
      expect(0.wrappingSubU32(0), equals(0));
      // underflow wraps
      expect(0.wrappingSubU32(1), equals(u32Max));
      expect(5.wrappingSubU32(10), equals(u32Max - 4));
    });
  });
}
