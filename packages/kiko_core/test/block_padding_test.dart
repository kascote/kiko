import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('EdgeInsets', () {
    test('constructors', () {
      expect(
        const EdgeInsets(top: 1, left: 2, bottom: 3, right: 4),
        const EdgeInsets(top: 1, left: 2, bottom: 3, right: 4),
      );
      expect(const EdgeInsets.zero(), const EdgeInsets());
      expect(
        const EdgeInsets.all(1),
        const EdgeInsets(top: 1, left: 1, bottom: 1, right: 1),
      );
      expect(
        const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        const EdgeInsets(top: 2, left: 1, bottom: 2, right: 1),
      );
    });
    test('equal', () {
      expect(
        const EdgeInsets(top: 1, left: 2, bottom: 3, right: 4),
        const EdgeInsets(top: 1, left: 2, bottom: 3, right: 4),
      );
    });
  });
}
