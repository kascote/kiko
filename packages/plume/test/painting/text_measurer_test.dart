import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  const m = MonospaceMeasurer();

  group('MonospaceMeasurer', () {
    test('width is one cell per grapheme', () {
      expect(m.widthOf('hello'), 5);
      expect(m.widthOf(''), 0);
    });
  });
}
