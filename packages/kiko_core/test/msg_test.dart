import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('eventToMsg key round-trip', () {
    // The regression guard: sweeps every printable ASCII character through
    // the real evt.KeyEvent -> eventToMsg -> KeyMsg.char pipeline instead of
    // hardcoding the 3 characters (space/plus/minus) toSpec() currently
    // aliases to word specs. A future 4th alias breaks this without needing
    // the test itself updated.
    test('every printable ASCII character survives eventToMsg unmodified', () {
      for (var code = 0x20; code <= 0x7e; code++) {
        final char = String.fromCharCode(code);
        final msg = eventToMsg(KeyEvent(KeyCode.char(char)));
        expect(msg, isA<KeyMsg>());
        expect((msg as KeyMsg).char, equals(char), reason: 'character $code (${char.codeUnits}) did not round-trip');
      }
    });

    test('a modified character key does not produce a literal char', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char(' '), modifiers: KeyModifiers.ctrl)) as KeyMsg;
      expect(msg.char, isNull);
    });

    test('a named key with no text form has no char', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.named(KeyCodeName.enter))) as KeyMsg;
      expect(msg.char, isNull);
    });
  });

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
