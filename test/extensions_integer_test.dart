import 'package:kiko/iterators.dart';
import 'package:test/test.dart';

void main() {
  group('SaturatingInt', () {
    test('saturatingSub', () {
      expect(10.saturatingSub(5), equals(5));
      expect(5.saturatingSub(10), equals(0));
      expect(0.saturatingSub(0), equals(0));
      expect(() => 10.saturatingSub(-5), throwsArgumentError);
      expect(() => (-10).saturatingSub(5), throwsArgumentError);
    });

    test('saturatingAdd', () {
      expect(10.saturatingAdd(5), equals(15));
      expect(u16Max.saturatingAdd(1), equals(u16Max));
      expect(0.saturatingAdd(0), equals(0));
      expect(10.saturatingAdd(-5), equals(5));
      expect((-10).saturatingAdd(5), equals(-5));
      expect((-10).saturatingAdd(-5), equals(-15));
    });

    test('saturatingMul', () {
      expect(10.saturatingMul(5), equals(50));
      expect(u16Max.saturatingMul(2), equals(u16Max));
      expect(0.saturatingMul(10), equals(0));
      expect(10.saturatingMul(-5), equals(-50));
      expect(-10.saturatingMul(5), equals(-50));
    });

    test('saturatingDiv', () {
      expect(10.saturatingDiv(2), equals(5));
      expect(u16Max.saturatingDiv(1), equals(u16Max));
      expect(() => 10.saturatingDiv(0), throwsA(isA<UnsupportedError>()));
      expect(() => 10.saturatingDiv(-2), throwsArgumentError);
      expect(() => (-10).saturatingDiv(2), throwsArgumentError);
    });

    test('wrappingAdd', () {
      expect(10.wrappingAdd(5), equals(15));
      expect(u32Max.wrappingAdd(1), equals(0));
      expect(0.wrappingAdd(0), equals(0));
      expect(10.wrappingAdd(-5), equals(5));
      expect((-10).wrappingAdd(5), equals(-5));
    });
  });
}
