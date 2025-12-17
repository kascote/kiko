import 'package:kiko_widgets/src/widgets/text_area/extensions/int.dart';
import 'package:test/test.dart';

void main() {
  group('SaturatingI32', () {
    test('saturatingSubI32', () {
      expect(10.saturatingSubI32(5), equals(5));
      expect(5.saturatingSubI32(10), equals(0));
      expect(0.saturatingSubI32(0), equals(0));
      expect(100.saturatingSubI32(100), equals(0));
      expect(i32Max.saturatingSubI32(1), equals(i32Max - 1));
      expect(i32Max.saturatingSubI32(i32Max), equals(0));
    });

    test('saturatingSubI32 clamps underflow to 0', () {
      expect(100.saturatingSubI32(1000), equals(0));
      expect(0.saturatingSubI32(1), equals(0));
    });

    test('saturatingAddI32', () {
      expect(10.saturatingAddI32(5), equals(15));
      expect(0.saturatingAddI32(0), equals(0));
      expect(100.saturatingAddI32(50), equals(150));
      // overflow clamps to i32Max
      expect(i32Max.saturatingAddI32(1), equals(i32Max));
      expect(i32Max.saturatingAddI32(100), equals(i32Max));
      expect((i32Max - 5).saturatingAddI32(10), equals(i32Max));
    });

    test('saturatingMulI32', () {
      expect(10.saturatingMulI32(5), equals(50));
      expect(0.saturatingMulI32(10), equals(0));
      expect(10.saturatingMulI32(0), equals(0));
      expect(10.saturatingMulI32(12), equals(120));
      // overflow clamps to i32Max
      expect(i32Max.saturatingMulI32(2), equals(i32Max));
      expect(100000.saturatingMulI32(100000), equals(i32Max));
    });
  });
}
