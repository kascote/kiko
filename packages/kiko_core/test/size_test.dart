import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Size', () {
    test('new', () {
      const p = Size(10, 20);
      expect(p.width, 10);
      expect(p.height, 20);
      expect(p.toString(), 'Size(10x20)');
    });

    test('zero', () {
      const p = Size.zero;
      expect(p.width, 0);
      expect(p.height, 0);
      expect(p.toString(), 'Size(0x0)');
    });

    test('fromRecord', () {
      final p = Size.fromPoint((x: 10, y: 20));
      expect(p.width, 10);
      expect(p.height, 20);
      expect(p.toString(), 'Size(10x20)');
    });

    test('rec', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      final p = Size.fromRect(r);
      expect(p.width, 3);
      expect(p.height, 4);
      expect(p.toString(), 'Size(3x4)');
    });

    test('equality', () {
      const size = Size(10, 20);
      expect(size, const Size(10, 20));
      expect(const Size(10, 20), isNot(const Size(20, 10)));
      expect(size.hashCode, const Size(10, 20).hashCode);
    });
  });
}
