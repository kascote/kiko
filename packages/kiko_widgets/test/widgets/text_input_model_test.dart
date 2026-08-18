import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg for a character — the key spec and the typed
/// text are the same single character, as they are for any plain,
/// unmodified character key.
KeyMsg charMsg(String c) => KeyMsg(c, text: c);

/// Helper to create a KeyMsg for backspace.
KeyMsg backspaceMsg() => const KeyMsg('backSpace');

/// A routed pointer message at a given local cell, over the field's own rect.
PointerMsg pointerAt(PointerAction action, {int x = 0, int y = 0}) => PointerMsg(
  global: Position(x, y),
  action: action,
  local: Position(x, y),
  targetRect: Rect.create(x: 0, y: 0, width: 20, height: 1),
);

/// A routed pointer message with no target rect — a press on the field's own
/// chrome, which resolves to a bare scope path.
PointerMsg scopePress(PointerAction action, {int x = 0, int y = 0}) =>
    PointerMsg(global: Position(x, y), action: action, local: Position(x, y));

/// A frame over an empty buffer, measured by [measurer].
Frame _frame(int width, int height, {TextMeasurer measurer = const TermUnicodeMeasurer()}) {
  final buffer = Buffer.empty(
    Rect.create(x: 0, y: 0, width: width, height: height),
    measurer: measurer,
  );
  return Frame(buffer.area, buffer, 0);
}

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

    group('the value setter', () {
      test('replaces the text and moves the cursor to the end', () {
        final model = TextInputModel(initial: 'hi')..value = 'hello';
        expect(model.value, equals('hello'));
        expect(model.cursor, equals(5));
      });

      test('works while unfocused — a direct call, not a message', () {
        final model = TextInputModel();
        expect(model.focused, isFalse);

        model.value = 'hello';
        expect(model.value, equals('hello'));
        expect(model.focused, isFalse, reason: 'the write itself never touches focus');
      });

      test('strips carriage returns and newlines, the way a paste is stripped', () {
        final model = TextInputModel()..value = 'a\r\nb\nc';
        expect(model.value, equals('abc'));
        expect(model.cursor, equals(3));
      });

      test('setting the empty string clears the field back to its placeholder path', () {
        final model = TextInputModel(initial: 'hello')..value = '';
        expect(model.value, isEmpty);
        expect(model.cursor, equals(0));
      });
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

    test('a dead-key composition (multi-codepoint, single grapheme) inserts as one grapheme', () {
      // 'e' + combining acute accent — a decomposed é, the shape a dead-key
      // sequence (or option+e then e on macOS) can produce as one kitty text
      // field, two UTF-16 code units, one grapheme cluster.
      const composed = 'é';
      final model = TextInputModel(focused: true)..update(const KeyMsg('e', text: composed));
      expect(model.value, equals(composed));
      expect(model.length, equals(1), reason: 'the combining sequence is a single grapheme cluster');
      expect(model.cursor, equals(1));
    });

    test('a keystroke whose text is multiple graphemes inserts the whole string at once', () {
      // The kitty text field is not contractually one grapheme — a compose
      // sequence can hand back more than one character in a single keystroke.
      // _insertAt treats the whole string as Characters, so both graphemes
      // land and the cursor advances by two, not one.
      final model = TextInputModel(focused: true)..update(const KeyMsg('a', text: 'ab'));
      expect(model.value, equals('ab'));
      expect(model.length, equals(2));
      expect(model.cursor, equals(2));
    });

    test('space key inserts a literal space', () {
      final model = TextInputModel(focused: true)
        ..update(charMsg('a'))
        ..update(const KeyMsg('space', text: ' '))
        ..update(charMsg('b'));
      expect(model.value, equals('a b'));
    });

    test('plus and minus keys insert their literal characters', () {
      final model = TextInputModel(focused: true)
        ..update(const KeyMsg('plus', text: '+'))
        ..update(const KeyMsg('minus', text: '-'));
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

      model.update(const KeyMsg('space', text: ' '));
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

      expect(model.update(pointerAt(PointerAction.down)), isA<Handled>());
      expect(model.cursor, equals(0));

      model.update(pointerAt(PointerAction.down, x: 3));
      expect(model.cursor, equals(3));
    });

    test('a click consumes without emitting a command', () {
      final model = TextInputModel(initial: 'hello', focused: true);
      final result = model.update(pointerAt(PointerAction.down, x: 2));
      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a click on the right cell of a 2-wide grapheme resolves to it', () {
      // Columns: a=0, あ=1-2, b=3.
      final model = TextInputModel(initial: 'aあb', focused: true)..update(pointerAt(PointerAction.down, x: 1));
      expect(model.cursor, equals(1), reason: 'left cell of あ');

      model.update(pointerAt(PointerAction.down, x: 2));
      expect(model.cursor, equals(1), reason: 'right cell still lands on あ, not b');

      model.update(pointerAt(PointerAction.down, x: 3));
      expect(model.cursor, equals(2), reason: 'b');
    });

    test('a click past the end lands at the text length', () {
      final model = TextInputModel(initial: 'abc', focused: true)..update(pointerAt(PointerAction.down, x: 20));
      expect(model.cursor, equals(3));
    });

    test('a click maps through a non-zero horizontal scroll offset', () {
      final model = TextInputModel(initial: '0123456789', focused: true)
        // Window the view: cursor at end, only 5 cells wide → scrolled by 6.
        ..adjustScroll(5)
        ..update(pointerAt(PointerAction.down));
      expect(model.cursor, equals(6), reason: 'local column 0 is absolute column 6');
    });

    test('a click resolves through the measurer the view assigned at layout', () {
      // ° is ambiguous width: one cell by default, two under a cjk locale.
      // Rendering first is what gives the model its measurer — the pointer
      // press below runs update() directly, exactly as the router does,
      // relying on that assignment to already have happened.
      final defaultModel = TextInputModel(id: 'in', initial: 'a°bc', focused: true);
      _frame(10, 1).render(TextInput(model: defaultModel, theme: Theme.dark));
      defaultModel.update(pointerAt(PointerAction.down, x: 2));
      expect(defaultModel.cursor, equals(2), reason: 'a=1, °=1, b=1: column 2 is "b"');

      final cjkModel = TextInputModel(id: 'in', initial: 'a°bc', focused: true);
      _frame(
        10,
        1,
        measurer: const TermUnicodeMeasurer(cjk: true),
      ).render(TextInput(model: cjkModel, theme: Theme.dark));
      cjkModel.update(pointerAt(PointerAction.down, x: 2));
      expect(cjkModel.cursor, equals(1), reason: 'a=1, °=2: column 2 is the right-hand cell of °, not "b"');
    });

    test('a click on an unfocused input still places the caret', () {
      final model = TextInputModel(initial: 'hello');
      final result = model.update(pointerAt(PointerAction.down, x: 2));
      expect(result, isA<Handled>());
      expect(model.cursor, equals(2));
    });

    test('a press with no target rect is consumed but leaves the caret', () {
      final model = TextInputModel(initial: 'hello', focused: true)..cursor = 3;

      final result = model.update(scopePress(PointerAction.down, x: 1));

      expect(result, isA<Handled>());
      expect(model.cursor, equals(3), reason: 'no rect means local.x names no character cell');
    });

    test('a wheel is declined so a scrollable ancestor gets it', () {
      final model = TextInputModel(initial: 'hello', focused: true);
      expect(model.update(pointerAt(PointerAction.wheelDown)), isA<Declined>());
      expect(model.update(pointerAt(PointerAction.wheelUp)), isA<Declined>());
      expect(model.cursor, equals(5), reason: 'the wheel never touches the caret');
    });

    test('non-consuming pointer traffic is declined', () {
      final model = TextInputModel(initial: 'hello', focused: true);
      expect(model.update(pointerAt(PointerAction.move, x: 2)), isA<Declined>());
      expect(model.update(pointerAt(PointerAction.up, x: 2)), isA<Declined>());
      expect(model.update(const PointerLeaveMsg('x')), isA<Declined>());
      expect(model.update(const PointerCancelMsg('x')), isA<Declined>());
    });
  });

  group('TextInputModel.update paste', () {
    test('paste inserts at the cursor', () {
      final model = TextInputModel(initial: 'hell', focused: true)..cursor = 2;

      final result = model.update(const PasteMsg('LO'));

      expect(result, isA<Handled>());
      expect(model.value, equals('heLOll'));
      expect(model.cursor, equals(4), reason: 'the caret ends after the pasted text');
    });

    test('newlines in the pasted text are stripped — the field stays single-line', () {
      final model = TextInputModel(focused: true)..update(const PasteMsg('foo\r\nbar\nbaz\r'));

      expect(model.value, equals('foobarbaz'));
    });

    test('paste honors maxLength like typed input', () {
      final model = TextInputModel(initial: 'abc', maxLength: 5, focused: true);

      final result = model.update(const PasteMsg('defg'));

      expect(result, isA<Handled>());
      expect(model.value, equals('abc'), reason: 'an insert that would overflow maxLength is dropped whole');
    });

    test('paste goes through the input filter like typed input', () {
      final model = TextInputModel(
        focused: true,
        inputFilter: (chars) => Characters(chars.string.replaceAll(RegExp('[^0-9]'), '')),
      )..update(const PasteMsg('a1b2c3'));

      expect(model.value, equals('123'));
    });

    test('paste to an unfocused input is declined and changes nothing', () {
      final model = TextInputModel(initial: 'hello');

      final result = model.update(const PasteMsg('x'));

      expect(result, isA<Declined>());
      expect(model.value, equals('hello'));
    });
  });

  group('TextInputModel.update key release / bare modifier', () {
    test('a release of the just-pressed key is declined and never doubles the character', () {
      // The regression this whole delivery kills: KeyMsg and KeyReleaseMsg
      // are siblings, not variants of one class, so a release can never
      // pattern-match as a keystroke and reach the insert path.
      final model = TextInputModel(focused: true)..update(charMsg('a'));
      expect(model.value, equals('a'));

      final result = model.update(const KeyReleaseMsg('a'));

      expect(result, isA<Declined>());
      expect(model.value, equals('a'), reason: 'a release must never insert a second character');
    });

    test('a bare modifier key edge is declined and inserts nothing', () {
      final model = TextInputModel(focused: true);

      final result = model.update(const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true));

      expect(result, isA<Declined>());
      expect(model.value, isEmpty);
    });
  });

  group('TextInputModel.update repeat', () {
    test('a held key keeps typing and a held backspace keeps deleting', () {
      final model = TextInputModel(focused: true)
        ..update(const KeyMsg.repeat('a', text: 'a'))
        ..update(const KeyMsg.repeat('a', text: 'a'));
      expect(model.value, equals('aa'), reason: 'a repeat resolves through the insert path exactly like a press');

      model.update(const KeyMsg.repeat('backSpace'));
      expect(
        model.value,
        equals('a'),
        reason: 'a repeat resolves through KeyBinding exactly like a press, so a held backspace keeps deleting',
      );
    });
  });
}
