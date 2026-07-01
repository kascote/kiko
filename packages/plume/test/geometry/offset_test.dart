import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  group('Offset', () {
    test('stores dx and dy', () {
      const o = Offset(3, -4);
      expect(o.dx, 3);
      expect(o.dy, -4);
    });

    test('zero is the origin', () {
      expect(Offset.zero.dx, 0);
      expect(Offset.zero.dy, 0);
    });

    test('addition and subtraction are component-wise', () {
      expect(const Offset(2, 3) + const Offset(4, 5), const Offset(6, 8));
      expect(const Offset(6, 8) - const Offset(4, 5), const Offset(2, 3));
    });

    test('equal offsets are equal and share a hashCode', () {
      expect(const Offset(1, 2), const Offset(1, 2));
      expect(const Offset(1, 2).hashCode, const Offset(1, 2).hashCode);
      expect(const Offset(1, 2), isNot(const Offset(2, 1)));
    });

    test('toString is readable', () {
      expect(const Offset(5, 6).toString(), 'Offset(5, 6)');
    });
  });
}
