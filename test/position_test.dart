import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Position', () {
    test('new', () {
      const p = Position(1, 2);
      expect(p.x, 1);
      expect(p.y, 2);
      expect(p.toString(), 'Position(1, 2)');
    });

    test('record', () {
      final p = Position.fromPoint((x: 1, y: 2));
      expect(p.x, 1);
      expect(p.y, 2);
      expect(p.toString(), 'Position(1, 2)');
    });

    test('toRecord', () {
      const p = Position(1, 2);
      expect(p.toPoint(), (x: 1, y: 2));
    });

    test('rec', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      final p = Position.fromRect(r);
      expect(p.x, 1);
      expect(p.y, 2);
      expect(p.toString(), 'Position(1, 2)');
    });

    test('fromPosition', () {
      expect(Position.fromPosition(const Position(10, 10)), const Position(10, 10));
    });

    test('hashcode', () {
      expect(const Position(2, 3).hashCode, const Position(2, 3).hashCode);
    });
  });
}
