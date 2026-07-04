import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('TermSize', () {
    test('new', () {
      const p = TermSize(10, 20);
      expect(p.width, 10);
      expect(p.height, 20);
      expect(p.toString(), 'TermSize(10x20)');
    });

    test('zero', () {
      const p = TermSize.zero;
      expect(p.width, 0);
      expect(p.height, 0);
      expect(p.toString(), 'TermSize(0x0)');
    });

    test('fromRecord', () {
      final p = TermSize.fromPoint((x: 10, y: 20));
      expect(p.width, 10);
      expect(p.height, 20);
      expect(p.toString(), 'TermSize(10x20)');
    });

    test('rec', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      final p = TermSize.fromRect(r);
      expect(p.width, 3);
      expect(p.height, 4);
      expect(p.toString(), 'TermSize(3x4)');
    });

    test('equality', () {
      const size = TermSize(10, 20);
      expect(size, const TermSize(10, 20));
      expect(const TermSize(10, 20), isNot(const TermSize(20, 10)));
      expect(size.hashCode, const TermSize(10, 20).hashCode);
    });
  });
}
