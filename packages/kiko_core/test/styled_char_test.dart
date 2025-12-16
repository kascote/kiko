import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('StyledChar', () {
    test('new', () {
      const s = Style();
      final sg = StyledChar('a', s);
      expect(sg.char, 'a'.characters);
      expect(sg.style, s);
    });

    test('setStyle', () {
      const s = Style();
      const s2 = Style(bg: Color.red);
      final sg = StyledChar('a', s).setStyle(s2);
      expect(sg.style, s2);
    });

    test('isWhiteSpace', () {
      const s = Style();
      expect(StyledChar(' ', s).isWhitespace(), true);
      expect(StyledChar('\u{200B}', s).isWhitespace(), true);
      expect(StyledChar('x', s).isWhitespace(), false);
    });

    test('toString', () {
      const s = Style();
      expect(
        StyledChar('abc', s).toString(),
        'StyledChar(abc, Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)))',
      );
    });

    test('equality', () {
      const s = Style();
      expect(StyledChar('abc', s), StyledChar('abc', s));
      expect(StyledChar('abc', s), isNot(StyledChar('c', s)));
      expect(StyledChar('abc', s).hashCode, StyledChar('abc', s).hashCode);
    });
  });
}
