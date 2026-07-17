import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg for a character.
KeyMsg charMsg(String c) => KeyMsg(c);

/// Helper to create a KeyMsg for backspace.
KeyMsg backspaceMsg() => const KeyMsg('backSpace');

/// A routed pointer message at a given local cell.
PointerMsg pointerAt(MouseButton button, {int x = 0, int y = 0}) =>
    PointerMsg(MouseEvent(x, y, button), local: Position(x, y));

void main() {
  group('TextInputModel', () {
    test('default empty state', () {
      final model = TextInputModel();
      expect(model.value, isEmpty);
      expect(model.cursor, equals(0));
      expect(model.length, equals(0));
    });

    test('initializes with initial text', () {
      final model = TextInputModel(initial: 'hello');
      expect(model.value, equals('hello'));
      expect(model.cursor, equals(5)); // cursor at end
      expect(model.length, equals(5));
    });

    test('config fields are set', () {
      final model = TextInputModel(
        initial: 'test',
        placeholder: 'Enter text',
        maxLength: 10,
        obscureText: true,
        obscureChar: '*',
      );
      expect(model.placeholder, equals('Enter text'));
      expect(model.maxLength, equals(10));
      expect(model.obscureText, isTrue);
      expect(model.obscureChar, equals('*'));
    });

    test('fillChar and style fields are set', () {
      final model = TextInputModel(
        fillChar: '_',
        style: const TextInputStyle(fill: Style(fg: Color.red)),
      );
      expect(model.fillChar, equals('_'));
      expect(model.style!.fill, equals(const Style(fg: Color.red)));
    });

    test('clear empties text and resets cursor, focused or not', () {
      final model = TextInputModel(initial: 'hello')..clear();
      expect(model.value, isEmpty);
      expect(model.cursor, equals(0));
      expect(model.length, equals(0));

      model
        ..focused = true
        ..update(charMsg('a'));
      expect(model.value, equals('a'));
      expect(model.cursor, equals(1));
    });
  });

  group('TextInputModel.update character input', () {
    test('character input inserts at cursor', () {
      final model = TextInputModel(focused: true);
      final result = model.update(charMsg('a'));
      expect(model.value, equals('a'));
      expect(model.cursor, equals(1));
      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('character input in middle', () {
      final model = TextInputModel(initial: 'ac', focused: true)
        ..cursor = 1
        ..update(charMsg('b'));
      expect(model.value, equals('abc'));
      expect(model.cursor, equals(2));
    });

    test('emoji input works correctly', () {
      final model = TextInputModel(focused: true)..update(charMsg('👋'));
      expect(model.value, equals('👋'));
      expect(model.cursor, equals(1));
      expect(model.length, equals(1));

      model.update(charMsg('🌍'));
      expect(model.value, equals('👋🌍'));
      expect(model.cursor, equals(2));
      expect(model.length, equals(2));
    });

    test('space key inserts a literal space', () {
      final model = TextInputModel(focused: true)
        ..update(charMsg('a'))
        ..update(const KeyMsg('space'))
        ..update(charMsg('b'));
      expect(model.value, equals('a b'));
    });

    test('plus and minus keys insert their literal characters', () {
      final model = TextInputModel(focused: true)
        ..update(const KeyMsg('plus'))
        ..update(const KeyMsg('minus'));
      expect(model.value, equals('+-'));
    });

    test('respects maxLength', () {
      final model = TextInputModel(initial: 'abc', maxLength: 5, focused: true)
        ..update(charMsg('d'))
        ..update(charMsg('e'));
      expect(model.value, equals('abcde'));

      model.update(charMsg('f')); // should be ignored
      expect(model.value, equals('abcde'));
      expect(model.length, equals(5));
    });

    test('declines a message it does not know', () {
      final model = TextInputModel(initial: 'abc', focused: true);
      final result = model.update(const NoneMsg());
      expect(result, isA<Declined>());
      expect(model.value, equals('abc')); // unchanged
    });

    test('inputFilter rejects non-matching chars', () {
      final model = TextInputModel(
        inputFilter: (c) => Characters(c.where((g) => RegExp('[a-z]').hasMatch(g)).join()),
        focused: true,
      )..update(charMsg('a'));
      expect(model.value, equals('a'));

      model.update(charMsg('1')); // rejected
      expect(model.value, equals('a'));

      model.update(charMsg(' ')); // rejected
      expect(model.value, equals('a'));

      model.update(charMsg('b'));
      expect(model.value, equals('ab'));
    });

    test('inputFilter can transform input', () {
      final model = TextInputModel(
        inputFilter: (c) => Characters(c.string.toUpperCase()),
        focused: true,
      );
      for (final char in 'hello'.split('')) {
        model.update(charMsg(char));
      }
      expect(model.value, equals('HELLO'));
    });

    test('inputFilter strips whitespace', () {
      final model = TextInputModel(
        inputFilter: (c) => Characters(c.where((g) => g.trim().isNotEmpty).join()),
        focused: true,
      );
      for (final char in 'hello'.split('')) {
        model.update(charMsg(char));
      }
      expect(model.value, equals('hello'));

      model.update(const KeyMsg('space'));
      expect(model.value, equals('hello'));
    });
  });

  group('TextInputModel.update backspace', () {
    test('backspace deletes before cursor', () {
      final model = TextInputModel(initial: 'ab', focused: true);
      final result = model.update(backspaceMsg());
      expect(model.value, equals('a'));
      expect(model.cursor, equals(1));
      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('backspace at beginning does nothing', () {
      final model = TextInputModel(initial: 'ab', focused: true)
        ..cursor = 0
        ..update(backspaceMsg());
      expect(model.value, equals('ab'));
      expect(model.cursor, equals(0));
    });

    test('backspace on empty does nothing', () {
      final model = TextInputModel(focused: true)..update(backspaceMsg());
      expect(model.value, isEmpty);
      expect(model.cursor, equals(0));
    });

    test('backspace deletes single emoji', () {
      final model = TextInputModel(initial: '👋🌍', focused: true)..update(backspaceMsg());
      expect(model.value, equals('👋'));
      expect(model.cursor, equals(1));
    });
  });

  group('TextInputModel.update delete key', () {
    KeyMsg deleteMsg() => const KeyMsg('delete');

    test('delete removes char after cursor', () {
      final model = TextInputModel(initial: 'abc', focused: true)
        ..cursor = 1
        ..update(deleteMsg());
      expect(model.value, equals('ac'));
      expect(model.cursor, equals(1));
    });

    test('delete at end does nothing', () {
      final model = TextInputModel(initial: 'abc', focused: true)..update(deleteMsg());
      expect(model.value, equals('abc'));
      expect(model.cursor, equals(3));
    });

    test('delete on empty does nothing', () {
      final model = TextInputModel(focused: true)..update(deleteMsg());
      expect(model.value, isEmpty);
      expect(model.cursor, equals(0));
    });

    test('delete removes single emoji', () {
      final model = TextInputModel(initial: 'a👋b', focused: true)
        ..cursor = 1
        ..update(deleteMsg());
      expect(model.value, equals('ab'));
      expect(model.cursor, equals(1));
    });
  });

  group('TextInputModel.update navigation', () {
    KeyMsg leftMsg() => const KeyMsg('left');
    KeyMsg rightMsg() => const KeyMsg('right');
    KeyMsg homeMsg() => const KeyMsg('home');
    KeyMsg endMsg() => const KeyMsg('end');

    test('left arrow moves cursor left', () {
      final model = TextInputModel(initial: 'abc', focused: true)
        ..cursor = 2
        ..update(leftMsg());
      expect(model.cursor, equals(1));
      expect(model.value, equals('abc'));
    });

    test('left arrow at start stays at start', () {
      final model = TextInputModel(initial: 'abc', focused: true)
        ..cursor = 0
        ..update(leftMsg());
      expect(model.cursor, equals(0));
    });

    test('right arrow moves cursor right', () {
      final model = TextInputModel(initial: 'abc', focused: true)
        ..cursor = 1
        ..update(rightMsg());
      expect(model.cursor, equals(2));
      expect(model.value, equals('abc'));
    });

    test('right arrow at end stays at end', () {
      final model = TextInputModel(initial: 'abc', focused: true)..update(rightMsg());
      expect(model.cursor, equals(3));
    });

    test('home moves cursor to start', () {
      final model = TextInputModel(initial: 'abc', focused: true)
        ..cursor = 2
        ..update(homeMsg());
      expect(model.cursor, equals(0));
    });

    test('end moves cursor to end', () {
      final model = TextInputModel(initial: 'abc', focused: true)
        ..cursor = 1
        ..update(endMsg());
      expect(model.cursor, equals(3));
    });

    test('navigation with emoji preserves grapheme positions', () {
      final model = TextInputModel(initial: 'a👋b', focused: true)
        ..cursor = 2
        ..update(leftMsg());
      expect(model.cursor, equals(1)); // now at 👋

      model.update(rightMsg());
      expect(model.cursor, equals(2)); // back at b
    });
  });

  group('TextInputModel.update Ctrl keybindings', () {
    KeyMsg ctrlKey(String char) => KeyMsg('ctrl+$char');

    KeyMsg ctrlLeft() => const KeyMsg('ctrl+left');

    KeyMsg ctrlRight() => const KeyMsg('ctrl+right');

    KeyMsg ctrlBackspace() => const KeyMsg('ctrl+backSpace');

    KeyMsg ctrlDelete() => const KeyMsg('ctrl+delete');

    test('Ctrl+A moves to start', () {
      final model = TextInputModel(initial: 'hello', focused: true)
        ..cursor = 3
        ..update(ctrlKey('a'));
      expect(model.cursor, equals(0));
    });

    test('Ctrl+E moves to end', () {
      final model = TextInputModel(initial: 'hello', focused: true)
        ..cursor = 2
        ..update(ctrlKey('e'));
      expect(model.cursor, equals(5));
    });

    test('Ctrl+K kills to end of line', () {
      final model = TextInputModel(initial: 'hello world', focused: true)
        ..cursor = 5
        ..update(ctrlKey('k'));
      expect(model.value, equals('hello'));
      expect(model.cursor, equals(5));
    });

    test('Ctrl+U deletes to line start', () {
      final model = TextInputModel(initial: 'hello world', focused: true)
        ..cursor = 6
        ..update(ctrlKey('u'));
      expect(model.value, equals('world'));
      expect(model.cursor, equals(0));
    });

    test('Ctrl+W deletes word left', () {
      final model = TextInputModel(initial: 'hello world', focused: true)..update(ctrlKey('w'));
      expect(model.value, equals('hello '));
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Left jumps word left', () {
      final model = TextInputModel(initial: 'hello world', focused: true)
        ..cursor = 8
        ..update(ctrlLeft());
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Right jumps word right', () {
      final model = TextInputModel(initial: 'hello world', focused: true)
        ..cursor = 0
        ..update(ctrlRight());
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Backspace deletes word left', () {
      final model = TextInputModel(initial: 'hello world', focused: true)..update(ctrlBackspace());
      expect(model.value, equals('hello '));
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Delete deletes word right', () {
      final model = TextInputModel(initial: 'hello world', focused: true)
        ..cursor = 0
        ..update(ctrlDelete());
      expect(model.value, equals('world'));
      expect(model.cursor, equals(0));
    });

    test('Ctrl+char does not insert character', () {
      final model = TextInputModel(initial: 'hello', focused: true)..update(ctrlKey('x'));
      // Unknown Ctrl combo should not modify text
      expect(model.value, equals('hello'));
      expect(model.cursor, equals(5));
    });
  });

  group('mouse click → caret', () {
    test('a click places the caret at the grapheme covering the column', () {
      final model = TextInputModel(initial: 'hello', focused: true);

      expect(model.update(pointerAt(MouseButton.down())), isA<Handled>());
      expect(model.cursor, equals(0));

      model.update(pointerAt(MouseButton.down(), x: 3));
      expect(model.cursor, equals(3));
    });

    test('a click consumes without emitting a command', () {
      final model = TextInputModel(initial: 'hello', focused: true);
      final result = model.update(pointerAt(MouseButton.down(), x: 2));
      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a click on the right cell of a 2-wide grapheme resolves to it', () {
      // Columns: a=0, あ=1-2, b=3.
      final model = TextInputModel(initial: 'aあb', focused: true)..update(pointerAt(MouseButton.down(), x: 1));
      expect(model.cursor, equals(1), reason: 'left cell of あ');

      model.update(pointerAt(MouseButton.down(), x: 2));
      expect(model.cursor, equals(1), reason: 'right cell still lands on あ, not b');

      model.update(pointerAt(MouseButton.down(), x: 3));
      expect(model.cursor, equals(2), reason: 'b');
    });

    test('a click past the end lands at the text length', () {
      final model = TextInputModel(initial: 'abc', focused: true)..update(pointerAt(MouseButton.down(), x: 20));
      expect(model.cursor, equals(3));
    });

    test('a click maps through a non-zero horizontal scroll offset', () {
      final model = TextInputModel(initial: '0123456789', focused: true)
        // Window the view: cursor at end, only 5 cells wide → scrolled by 6.
        ..adjustScroll(5)
        ..update(pointerAt(MouseButton.down()));
      expect(model.cursor, equals(6), reason: 'local column 0 is absolute column 6');
    });

    test('a click on an unfocused input still places the caret', () {
      final model = TextInputModel(initial: 'hello');
      final result = model.update(pointerAt(MouseButton.down(), x: 2));
      expect(result, isA<Handled>());
      expect(model.cursor, equals(2));
    });

    test('a wheel is declined so a scrollable ancestor gets it', () {
      final model = TextInputModel(initial: 'hello', focused: true);
      expect(model.update(pointerAt(MouseButton.wheelDown())), isA<Declined>());
      expect(model.update(pointerAt(MouseButton.wheelUp())), isA<Declined>());
      expect(model.cursor, equals(5), reason: 'the wheel never touches the caret');
    });

    test('non-consuming pointer traffic is declined', () {
      final model = TextInputModel(initial: 'hello', focused: true);
      expect(model.update(pointerAt(MouseButton.moved(), x: 2)), isA<Declined>());
      expect(model.update(pointerAt(MouseButton.up(), x: 2)), isA<Declined>());
      expect(model.update(const PointerLeaveMsg('x')), isA<Declined>());
      expect(model.update(const PointerCancelMsg('x')), isA<Declined>());
    });
  });

  group('TextInputModel.update paste', () {
    test('paste inserts at the cursor', () {
      final model = TextInputModel(initial: 'hell', focused: true)..cursor = 2;

      final result = model.update(const PasteMsg(PasteEvent('LO')));

      expect(result, isA<Handled>());
      expect(model.value, equals('heLOll'));
      expect(model.cursor, equals(4), reason: 'the caret ends after the pasted text');
    });

    test('newlines in the pasted text are stripped — the field stays single-line', () {
      final model = TextInputModel(focused: true)..update(const PasteMsg(PasteEvent('foo\r\nbar\nbaz\r')));

      expect(model.value, equals('foobarbaz'));
    });

    test('paste honors maxLength like typed input', () {
      final model = TextInputModel(initial: 'abc', maxLength: 5, focused: true);

      final result = model.update(const PasteMsg(PasteEvent('defg')));

      expect(result, isA<Handled>());
      expect(model.value, equals('abc'), reason: 'an insert that would overflow maxLength is dropped whole');
    });

    test('paste goes through the input filter like typed input', () {
      final model = TextInputModel(
        focused: true,
        inputFilter: (chars) => Characters(chars.string.replaceAll(RegExp('[^0-9]'), '')),
      )..update(const PasteMsg(PasteEvent('a1b2c3')));

      expect(model.value, equals('123'));
    });

    test('paste to an unfocused input is declined and changes nothing', () {
      final model = TextInputModel(initial: 'hello');

      final result = model.update(const PasteMsg(PasteEvent('x')));

      expect(result, isA<Declined>());
      expect(model.value, equals('hello'));
    });
  });
}
