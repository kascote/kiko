import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('eventToMsg: press, repeat, release', () {
    test('a press is a KeyMsg with repeat false', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('a')));

      expect(msg, isA<KeyMsg>());
      final keyMsg = msg! as KeyMsg;
      expect(keyMsg.key, equals('a'));
      expect(keyMsg.repeat, isFalse);
    });

    test('a repeat is a KeyMsg with repeat true, same key spec', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('a'), eventType: KeyEventType.keyRepeat));

      expect(msg, isA<KeyMsg>());
      final keyMsg = msg! as KeyMsg;
      expect(keyMsg.key, equals('a'));
      expect(keyMsg.repeat, isTrue);
    });

    test('a release is a KeyReleaseMsg carrying the same key spec', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('a'), eventType: KeyEventType.keyRelease));

      expect(msg, isA<KeyReleaseMsg>());
      expect((msg! as KeyReleaseMsg).key, equals('a'));
    });
  });

  group('eventToMsg: text sourcing', () {
    test("the terminal's kitty text field wins over everything else", () {
      final msg =
          eventToMsg(
                const KeyEvent(KeyCode.char('a'), modifiers: KeyModifiers.ctrl, text: 'ǎ'),
              )!
              as KeyMsg;

      expect(msg.text, equals('ǎ'));
    });

    test('a bare character key with no modifiers types its own char', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('a')))! as KeyMsg;

      expect(msg.text, equals('a'));
    });

    test('a character key with shift only types the produced char', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('A'), modifiers: KeyModifiers.shift))! as KeyMsg;

      expect(msg.text, equals('A'));
    });

    test('a ctrl+char key has no text', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('a'), modifiers: KeyModifiers.ctrl))! as KeyMsg;

      expect(msg.text, isNull);
    });

    test('a named key has no text, even with no modifiers', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.named(KeyCodeName.enter)))! as KeyMsg;

      expect(msg.text, isNull);
    });

    test('the space key (char-kind, spec "space") types a literal space', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char(' ')))! as KeyMsg;

      expect(msg.key, equals('space'));
      expect(msg.text, equals(' '));
    });
  });

  group('eventToMsg: baseKey', () {
    test('threaded from toBaseLayoutSpec when the terminal reports one', () {
      final event = KeyEvent(
        KeyCode.char('z', baseLayoutKey: 'z'.codeUnitAt(0)),
        modifiers: KeyModifiers.ctrl,
      );

      final msg = eventToMsg(event)! as KeyMsg;

      expect(msg.baseKey, equals('ctrl+z'));
    });

    test('null when the terminal reports no base layout key', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('a')))! as KeyMsg;

      expect(msg.baseKey, isNull);
    });
  });

  group('eventToMsg: bare modifier keys', () {
    test('a press is ModifierKeyMsg down, with the right modifier and side', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.named(KeyCodeName.leftShift)));

      expect(msg, isA<ModifierKeyMsg>());
      final m = msg! as ModifierKeyMsg;
      expect(m.modifier, ModifierKey.shift);
      expect(m.side, ModifierSide.left);
      expect(m.down, isTrue);
    });

    test('a release is ModifierKeyMsg up', () {
      final msg = eventToMsg(
        const KeyEvent(KeyCode.named(KeyCodeName.leftCtrl), eventType: KeyEventType.keyRelease),
      );

      expect(msg, isA<ModifierKeyMsg>());
      final m = msg! as ModifierKeyMsg;
      expect(m.modifier, ModifierKey.ctrl);
      expect(m.down, isFalse);
    });

    test('a repeat is dropped entirely — no message reaches update', () {
      final msg = eventToMsg(
        const KeyEvent(KeyCode.named(KeyCodeName.leftShift), eventType: KeyEventType.keyRepeat),
      );

      expect(msg, isNull);
    });

    test('left and right copies of the same modifier are distinct', () {
      final left = eventToMsg(const KeyEvent(KeyCode.named(KeyCodeName.leftShift)))! as ModifierKeyMsg;
      final right = eventToMsg(const KeyEvent(KeyCode.named(KeyCodeName.rightShift)))! as ModifierKeyMsg;

      expect(left.side, ModifierSide.left);
      expect(right.side, ModifierSide.right);
      expect(left, isNot(equals(right)));
    });

    test('ISO Level 3/5 Shift report as shift with no side', () {
      final l3 = eventToMsg(const KeyEvent(KeyCode.named(KeyCodeName.isoLevel3Shift)))! as ModifierKeyMsg;
      final l5 = eventToMsg(const KeyEvent(KeyCode.named(KeyCodeName.isoLevel5Shift)))! as ModifierKeyMsg;

      expect(l3.modifier, ModifierKey.shift);
      expect(l3.side, ModifierSide.unsided);
      expect(l5.modifier, ModifierKey.shift);
      expect(l5.side, ModifierSide.unsided);
    });

    test('every named modifier key maps to the expected modifier and side', () {
      const expected = {
        KeyCodeName.leftShift: (ModifierKey.shift, ModifierSide.left),
        KeyCodeName.rightShift: (ModifierKey.shift, ModifierSide.right),
        KeyCodeName.leftCtrl: (ModifierKey.ctrl, ModifierSide.left),
        KeyCodeName.rightCtrl: (ModifierKey.ctrl, ModifierSide.right),
        KeyCodeName.leftAlt: (ModifierKey.alt, ModifierSide.left),
        KeyCodeName.rightAlt: (ModifierKey.alt, ModifierSide.right),
        KeyCodeName.leftSuper: (ModifierKey.superKey, ModifierSide.left),
        KeyCodeName.rightSuper: (ModifierKey.superKey, ModifierSide.right),
        KeyCodeName.leftHyper: (ModifierKey.hyper, ModifierSide.left),
        KeyCodeName.rightHyper: (ModifierKey.hyper, ModifierSide.right),
        KeyCodeName.leftMeta: (ModifierKey.meta, ModifierSide.left),
        KeyCodeName.rightMeta: (ModifierKey.meta, ModifierSide.right),
      };

      for (final MapEntry(key: name, value: (modifier, side)) in expected.entries) {
        final msg = eventToMsg(KeyEvent(KeyCode.named(name)))! as ModifierKeyMsg;
        expect(msg.modifier, modifier, reason: '$name modifier');
        expect(msg.side, side, reason: '$name side');
      }
    });
  });

  group('KeyMsg is not matched by release or bare-modifier messages', () {
    test('a case KeyMsg() pattern matches presses and repeats only', () {
      bool matchesKeyMsg(Msg msg) => switch (msg) {
        KeyMsg() => true,
        _ => false,
      };

      expect(matchesKeyMsg(const KeyMsg('q')), isTrue);
      expect(matchesKeyMsg(const KeyMsg.repeat('q')), isTrue);
      expect(matchesKeyMsg(const KeyReleaseMsg('q')), isFalse);
      expect(matchesKeyMsg(const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true)), isFalse);
    });
  });

  group('equality', () {
    test('KeyMsg compares all fields', () {
      expect(
        const KeyMsg('a', text: 'a'),
        equals(const KeyMsg('a', text: 'a')),
      );
      expect(const KeyMsg('a'), isNot(equals(const KeyMsg('a', repeat: true))));
      expect(const KeyMsg('a', text: 'a'), isNot(equals(const KeyMsg('a', text: 'b'))));
      expect(const KeyMsg('a', baseKey: 'a'), isNot(equals(const KeyMsg('a'))));
    });

    test('KeyReleaseMsg compares key', () {
      expect(const KeyReleaseMsg('a'), equals(const KeyReleaseMsg('a')));
      expect(const KeyReleaseMsg('a'), isNot(equals(const KeyReleaseMsg('b'))));
    });

    test('ModifierKeyMsg compares modifier, side and edge', () {
      expect(
        const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true),
        equals(const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true)),
      );
      expect(
        const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true),
        isNot(equals(const ModifierKeyMsg(ModifierKey.shift, ModifierSide.right, down: true))),
      );
      expect(
        const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true),
        isNot(equals(const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: false))),
      );
    });
  });
}
