import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('KeyMsg.char', () {
    test('a plain letter is its own char', () {
      expect(const KeyMsg('a').char, equals('a'));
    });

    test('an emoji grapheme is its own char', () {
      expect(const KeyMsg('👋').char, equals('👋'));
    });

    test('space/plus/minus resolve to their literal characters', () {
      expect(const KeyMsg('space').char, equals(' '));
      expect(const KeyMsg('plus').char, equals('+'));
      expect(const KeyMsg('minus').char, equals('-'));
    });

    test('a named key with no text form is null', () {
      expect(const KeyMsg('enter').char, isNull);
      expect(const KeyMsg('tab').char, isNull);
      expect(const KeyMsg('backSpace').char, isNull);
      expect(const KeyMsg('f1').char, isNull);
    });

    test('a modified char key is null, even space/plus/minus', () {
      expect(const KeyMsg('ctrl+a').char, isNull);
      expect(const KeyMsg('ctrl+space').char, isNull);
      expect(const KeyMsg('alt+plus').char, isNull);
    });
  });
}
