import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  group('Size', () {
    test('stores width and height', () {
      const s = Size(3, 4);
      expect(s.w, 3);
      expect(s.h, 4);
    });

    test('zero is 0 x 0', () {
      expect(Size.zero.w, 0);
      expect(Size.zero.h, 0);
    });

    test('addition is component-wise', () {
      expect(const Size(2, 3) + const Size(4, 5), const Size(6, 8));
    });

    test('equal sizes are equal and share a hashCode', () {
      expect(const Size(1, 2), const Size(1, 2));
      expect(const Size(1, 2).hashCode, const Size(1, 2).hashCode);
      expect(const Size(1, 2), isNot(const Size(2, 1)));
    });

    test('toString is readable', () {
      expect(const Size(5, 6).toString(), 'Size(5, 6)');
    });
  });
}
