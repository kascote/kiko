import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg for a character.
KeyMsg charMsg(String c) => KeyMsg(c);

/// Helper to create a KeyMsg for backspace.
KeyMsg backspaceMsg() => const KeyMsg('backSpace');

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
  });

  group('TextInputModel.update character input', () {
    test('character input inserts at cursor', () {
      final model = TextInputModel(focused: true);
      final cmd = model.update(charMsg('a'));
      expect(model.value, equals('a'));
      expect(model.cursor, equals(1));
      expect(cmd, isNull);
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

    test('respects maxLength', () {
      final model = TextInputModel(initial: 'abc', maxLength: 5, focused: true)
        ..update(charMsg('d'))
        ..update(charMsg('e'));
      expect(model.value, equals('abcde'));

      model.update(charMsg('f')); // should be ignored
      expect(model.value, equals('abcde'));
      expect(model.length, equals(5));
    });

    test('unhandled message returns null cmd', () {
      final model = TextInputModel(initial: 'abc', focused: true);
      final cmd = model.update(const NoneMsg());
      expect(cmd, isNull);
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
      final cmd = model.update(backspaceMsg());
      expect(model.value, equals('a'));
      expect(model.cursor, equals(1));
      expect(cmd, isNull);
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

  group('TextInput widget render', () {
    late Buffer buffer;
    late Frame frame;

    Frame makeFrame(int width, int height) {
      final area = Rect.create(x: 0, y: 0, width: width, height: height);
      buffer = Buffer.empty(area);
      return Frame(area, buffer, 0);
    }

    test('renders text and cursor when fits in area', () {
      frame = makeFrame(20, 1);
      final model = TextInputModel(initial: 'hello', focused: true)..cursor = 3;
      final area = Rect.create(x: 0, y: 0, width: 20, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('h'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('e'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('l'));
      expect(buffer[(x: 3, y: 0)].symbol, equals('l'));
      expect(buffer[(x: 4, y: 0)].symbol, equals('o'));
      expect(frame.cursorPosition, equals(const Position(3, 0)));
    });

    test('renders placeholder when empty', () {
      frame = makeFrame(20, 1);
      final model = TextInputModel(placeholder: 'Type here', focused: true);
      final area = Rect.create(x: 0, y: 0, width: 20, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('T'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('y'));
      expect(frame.cursorPosition, equals(Position.origin));
    });

    test('renders obscured text', () {
      frame = makeFrame(20, 1);
      final model = TextInputModel(initial: 'secret', obscureText: true);
      final area = Rect.create(x: 0, y: 0, width: 20, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('•'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('•'));
      expect(buffer[(x: 5, y: 0)].symbol, equals('•'));
    });

    test('scrolls when cursor at end exceeds visible width', () {
      frame = makeFrame(5, 1);
      // Text "abcdefgh" (8 chars), cursor at end (pos 8)
      // visible width = 5, cursorDisplayPos = 8
      // scrollOffset = 8 - 5 + 1 = 4
      // Shows: "efgh " with cursor at position 4 (col 4)
      final model = TextInputModel(initial: 'abcdefgh', focused: true);
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('e'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('f'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('g'));
      expect(buffer[(x: 3, y: 0)].symbol, equals('h'));
      expect(frame.cursorPosition, equals(const Position(4, 0)));
    });

    test('cursor moves within visible area when scrolled', () {
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);

      // Same model instance to preserve scroll state
      final model = TextInputModel(initial: 'abcdefgh', focused: true);

      // First render at cursor 8 - scrolls to show "efgh"
      frame = makeFrame(5, 1);
      TextInput(model).render(area, frame);
      expect(frame.cursorPosition, equals(const Position(4, 0)));

      // Move cursor left
      model.cursor = 7;
      frame = makeFrame(5, 1);
      TextInput(model).render(area, frame);

      // Still shows "efgh", cursor moved left within visible area
      expect(buffer[(x: 0, y: 0)].symbol, equals('e'));
      expect(frame.cursorPosition, equals(const Position(3, 0)));
    });

    test('scrolls back when cursor moves to beginning', () {
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);

      // Same model to preserve scroll state
      final model = TextInputModel(initial: 'abcdefgh', focused: true);

      // First scroll right
      frame = makeFrame(5, 1);
      TextInput(model).render(area, frame);

      // Then jump to beginning - should scroll back
      model.cursor = 0;
      frame = makeFrame(5, 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(frame.cursorPosition, equals(Position.origin));
    });

    test('handles wide characters (emoji) with scroll', () {
      frame = makeFrame(4, 1);
      // "ab👋c" - 'ab' = 2 cols, '👋' = 2 cols, 'c' = 1 col, total 5 cols
      // cursor at end (pos 4), cursorDisplayPos = 5
      // scrollOffset = 5 - 4 + 1 = 2
      // Shows: "👋c" with cursor at col 4 (after 'c')
      final model = TextInputModel(initial: 'ab👋c', focused: true);
      final area = Rect.create(x: 0, y: 0, width: 4, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('👋'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('c'));
      expect(frame.cursorPosition, equals(const Position(3, 0)));
    });
  });

  group('TextInput fillChar and style', () {
    late Buffer buffer;
    late Frame frame;

    Frame makeFrame(int width, int height) {
      final area = Rect.create(x: 0, y: 0, width: width, height: height);
      buffer = Buffer.empty(area);
      return Frame(area, buffer, 0);
    }

    test('config fields are set', () {
      final model = TextInputModel(
        fillChar: '_',
        style: const TextInputStyle(fill: Style(fg: Color.red)),
      );
      expect(model.fillChar, equals('_'));
      expect(model.style.fill, equals(const Style(fg: Color.red)));
    });

    test('fills remaining space after text', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(initial: 'abc', fillChar: '_');
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      // 'abc' takes 3 chars, fill 7 underscores
      expect(buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('b'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('c'));
      expect(buffer[(x: 3, y: 0)].symbol, equals('_'));
      expect(buffer[(x: 9, y: 0)].symbol, equals('_'));
    });

    test('fills remaining space after placeholder', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(placeholder: 'Hi', fillChar: '.');
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      // 'Hi' takes 2 chars, fill 8 dots
      expect(buffer[(x: 0, y: 0)].symbol, equals('H'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('i'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('.'));
      expect(buffer[(x: 9, y: 0)].symbol, equals('.'));
    });

    test('respects maxLength when set', () {
      frame = makeFrame(20, 1);
      final model = TextInputModel(
        initial: 'abc',
        maxLength: 10,
        fillChar: '_',
      );
      final area = Rect.create(x: 0, y: 0, width: 20, height: 1);
      TextInput(model).render(area, frame);

      // 'abc' takes 3 chars, fill to maxLength (10), so 7 underscores
      expect(buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('c'));
      expect(buffer[(x: 3, y: 0)].symbol, equals('_'));
      expect(buffer[(x: 9, y: 0)].symbol, equals('_'));
      // Position 10+ should be empty (space)
      expect(buffer[(x: 10, y: 0)].symbol, equals(' '));
    });

    test('fills entire widget width when no maxLength', () {
      frame = makeFrame(15, 1);
      final model = TextInputModel(initial: 'ab', fillChar: '-');
      final area = Rect.create(x: 0, y: 0, width: 15, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('b'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('-'));
      expect(buffer[(x: 14, y: 0)].symbol, equals('-'));
    });

    test('applies style.fill to fill characters', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(
        initial: 'ab',
        fillChar: '_',
        style: const TextInputStyle(
          fill: Style(fg: Color.red, bg: Color.blue),
        ),
      );
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      // Text cells should have default style
      expect(buffer[(x: 0, y: 0)].fg, isNot(equals(Color.red)));

      // Fill cells should have the style.fill
      expect(buffer[(x: 2, y: 0)].symbol, equals('_'));
      expect(buffer[(x: 2, y: 0)].fg, equals(Color.red));
      expect(buffer[(x: 2, y: 0)].bg, equals(Color.blue));
    });

    test('no fill when fillChar is null', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(initial: 'abc');
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(buffer[(x: 3, y: 0)].symbol, equals(' ')); // default empty
    });

    test('applies style.text to input text', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(
        initial: 'hello',
        style: const TextInputStyle(text: Style(fg: Color.green)),
      );
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('h'));
      expect(buffer[(x: 0, y: 0)].fg, equals(Color.green));
      expect(buffer[(x: 4, y: 0)].symbol, equals('o'));
      expect(buffer[(x: 4, y: 0)].fg, equals(Color.green));
    });

    test('applies style.placeholder to placeholder text', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(
        placeholder: 'Type here',
        style: const TextInputStyle(placeholder: Style(fg: Color.gray)),
      );
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 0, y: 0)].symbol, equals('T'));
      expect(buffer[(x: 0, y: 0)].fg, equals(Color.gray));
    });

    test('applies style.obscured to obscured text', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(
        initial: 'secret',
        obscureText: true,
        style: const TextInputStyle(
          text: Style(fg: Color.green),
          obscured: Style(fg: Color.yellow),
        ),
      );
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      // Uses obscured style, not text style
      expect(buffer[(x: 0, y: 0)].symbol, equals('•'));
      expect(buffer[(x: 0, y: 0)].fg, equals(Color.yellow));
    });

    test('applies all styles together', () {
      frame = makeFrame(20, 1);
      final model = TextInputModel(
        initial: 'ab',
        fillChar: '_',
        style: const TextInputStyle(
          text: Style(fg: Color.cyan),
          fill: Style(fg: Color.darkGray),
        ),
      );
      final area = Rect.create(x: 0, y: 0, width: 20, height: 1);
      TextInput(model).render(area, frame);

      // Text has text style
      expect(buffer[(x: 0, y: 0)].fg, equals(Color.cyan));
      expect(buffer[(x: 1, y: 0)].fg, equals(Color.cyan));

      // Fill has fill style
      expect(buffer[(x: 2, y: 0)].symbol, equals('_'));
      expect(buffer[(x: 2, y: 0)].fg, equals(Color.darkGray));
    });

    test('no fill when text fills entire maxLength', () {
      frame = makeFrame(10, 1);
      final model = TextInputModel(
        initial: 'abcde',
        maxLength: 5,
        fillChar: '_',
      );
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      expect(buffer[(x: 4, y: 0)].symbol, equals('e'));
      expect(buffer[(x: 5, y: 0)].symbol, equals(' ')); // no fill
    });

    test('handles wide fill characters', () {
      frame = makeFrame(10, 1);
      // Using a wide char like '＿' (fullwidth low line, 2 cols)
      final model = TextInputModel(initial: 'ab', fillChar: '＿');
      final area = Rect.create(x: 0, y: 0, width: 10, height: 1);
      TextInput(model).render(area, frame);

      // 'ab' = 2 cols, remaining 8 cols, wide char = 2 cols each, so 4 chars
      expect(buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('b'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('＿'));
    });

    test('maxLength clamped to visible width', () {
      frame = makeFrame(5, 1);
      // maxLength 20 but only 5 visible
      final model = TextInputModel(
        initial: 'ab',
        maxLength: 20,
        fillChar: '_',
      );
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);
      TextInput(model).render(area, frame);

      // Should only fill up to visible width (5), not maxLength (20)
      expect(buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(buffer[(x: 1, y: 0)].symbol, equals('b'));
      expect(buffer[(x: 2, y: 0)].symbol, equals('_'));
      expect(buffer[(x: 4, y: 0)].symbol, equals('_'));
    });
  });
}
