import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('BorderType.symbols', () {
    test('reads off the receiver', () {
      expect(BorderType.plain.symbols.topLeft, '┌');
      expect(BorderType.rounded.symbols.topLeft, '╭');
      expect(BorderType.double.symbols.topLeft, '╔');
      expect(BorderType.thick.symbols.topLeft, '┏');
    });

    test('every border type has a glyph set', () {
      for (final type in BorderType.values) {
        expect(() => type.symbols, returnsNormally, reason: '$type');
      }
    });

    test('none draws blanks rather than throwing', () {
      expect(BorderType.none.symbols.topLeft, ' ');
      expect(BorderType.none.symbols.top, ' ');
    });
  });
}
