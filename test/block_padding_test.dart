import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Padding', () {
    test('constructors', () {
      expect(const Padding(top: 1, left: 2, bottom: 3, right: 4), const Padding(top: 1, left: 2, bottom: 3, right: 4));
      expect(const Padding.zero(), const Padding());
      expect(const Padding.all(1), const Padding(top: 1, left: 1, bottom: 1, right: 1));
      expect(const Padding.symmetric(horizontal: 1, vertical: 2), const Padding(top: 1, left: 2, bottom: 1, right: 2));
    });
    test('equal', () {
      expect(
        const Padding(top: 1, left: 2, bottom: 3, right: 4),
        const Padding(top: 1, left: 2, bottom: 3, right: 4),
      );
    });
  });
}
