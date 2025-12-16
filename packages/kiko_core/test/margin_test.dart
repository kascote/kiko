import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Margin >', () {
    test('new', () {
      const m = Margin(2, 3);
      expect(m.horizontal, 2);
      expect(m.vertical, 3);
      expect(m.toString(), 'Margin(2, 3)');
    });

    test('zero', () {
      //
      // ignore: use_named_constants
      expect(Margin.zero, const Margin(0, 0));
    });
  });
}
