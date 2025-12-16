import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg for a character.
KeyMsg charMsg(String c) => KeyMsg(KeyEvent(KeyCode.char(c)));

/// Helper to create a KeyMsg for backspace.
KeyMsg backspaceMsg() => const KeyMsg(KeyEvent(KeyCode.named(KeyCodeName.backSpace)));

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
      final model = TextInputModel();
      final cmd = model.update(charMsg('a'));
      expect(model.value, equals('a'));
      expect(model.cursor, equals(1));
      expect(cmd, isNull);
    });

    test('character input in middle', () {
      final model = TextInputModel(initial: 'ac')
        ..cursor = 1
        ..update(charMsg('b'));
      expect(model.value, equals('abc'));
      expect(model.cursor, equals(2));
    });

    test('emoji input works correctly', () {
      final model = TextInputModel()..update(charMsg('👋'));
      expect(model.value, equals('👋'));
      expect(model.cursor, equals(1));
      expect(model.length, equals(1));

      model.update(charMsg('🌍'));
      expect(model.value, equals('👋🌍'));
      expect(model.cursor, equals(2));
      expect(model.length, equals(2));
    });

    test('respects maxLength', () {
      final model = TextInputModel(initial: 'abc', maxLength: 5)
        ..update(charMsg('d'))
        ..update(charMsg('e'));
      expect(model.value, equals('abcde'));

      model.update(charMsg('f')); // should be ignored
      expect(model.value, equals('abcde'));
      expect(model.length, equals(5));
    });

    test('unhandled message returns null cmd', () {
      final model = TextInputModel(initial: 'abc');
      final cmd = model.update(const NoneMsg());
      expect(cmd, isNull);
      expect(model.value, equals('abc')); // unchanged
    });
  });

  group('TextInputModel.update backspace', () {
    test('backspace deletes before cursor', () {
      final model = TextInputModel(initial: 'ab');
      final cmd = model.update(backspaceMsg());
      expect(model.value, equals('a'));
      expect(model.cursor, equals(1));
      expect(cmd, isNull);
    });

    test('backspace at beginning does nothing', () {
      final model = TextInputModel(initial: 'ab')
        ..cursor = 0
        ..update(backspaceMsg());
      expect(model.value, equals('ab'));
      expect(model.cursor, equals(0));
    });

    test('backspace on empty does nothing', () {
      final model = TextInputModel()..update(backspaceMsg());
      expect(model.value, isEmpty);
      expect(model.cursor, equals(0));
    });

    test('backspace deletes single emoji', () {
      final model = TextInputModel(initial: '👋🌍')..update(backspaceMsg());
      expect(model.value, equals('👋'));
      expect(model.cursor, equals(1));
    });
  });

  group('TextInputModel.update delete key', () {
    KeyMsg deleteMsg() => const KeyMsg(KeyEvent(KeyCode.named(KeyCodeName.delete)));

    test('delete removes char after cursor', () {
      final model = TextInputModel(initial: 'abc')
        ..cursor = 1
        ..update(deleteMsg());
      expect(model.value, equals('ac'));
      expect(model.cursor, equals(1));
    });

    test('delete at end does nothing', () {
      final model = TextInputModel(initial: 'abc')..update(deleteMsg());
      expect(model.value, equals('abc'));
      expect(model.cursor, equals(3));
    });

    test('delete on empty does nothing', () {
      final model = TextInputModel()..update(deleteMsg());
      expect(model.value, isEmpty);
      expect(model.cursor, equals(0));
    });

    test('delete removes single emoji', () {
      final model = TextInputModel(initial: 'a👋b')
        ..cursor = 1
        ..update(deleteMsg());
      expect(model.value, equals('ab'));
      expect(model.cursor, equals(1));
    });
  });

  group('TextInputModel.update navigation', () {
    KeyMsg leftMsg() => const KeyMsg(KeyEvent(KeyCode.named(KeyCodeName.left)));
    KeyMsg rightMsg() => const KeyMsg(KeyEvent(KeyCode.named(KeyCodeName.right)));
    KeyMsg homeMsg() => const KeyMsg(KeyEvent(KeyCode.named(KeyCodeName.home)));
    KeyMsg endMsg() => const KeyMsg(KeyEvent(KeyCode.named(KeyCodeName.end)));

    test('left arrow moves cursor left', () {
      final model = TextInputModel(initial: 'abc')
        ..cursor = 2
        ..update(leftMsg());
      expect(model.cursor, equals(1));
      expect(model.value, equals('abc'));
    });

    test('left arrow at start stays at start', () {
      final model = TextInputModel(initial: 'abc')
        ..cursor = 0
        ..update(leftMsg());
      expect(model.cursor, equals(0));
    });

    test('right arrow moves cursor right', () {
      final model = TextInputModel(initial: 'abc')
        ..cursor = 1
        ..update(rightMsg());
      expect(model.cursor, equals(2));
      expect(model.value, equals('abc'));
    });

    test('right arrow at end stays at end', () {
      final model = TextInputModel(initial: 'abc')..update(rightMsg());
      expect(model.cursor, equals(3));
    });

    test('home moves cursor to start', () {
      final model = TextInputModel(initial: 'abc')
        ..cursor = 2
        ..update(homeMsg());
      expect(model.cursor, equals(0));
    });

    test('end moves cursor to end', () {
      final model = TextInputModel(initial: 'abc')
        ..cursor = 1
        ..update(endMsg());
      expect(model.cursor, equals(3));
    });

    test('navigation with emoji preserves grapheme positions', () {
      final model = TextInputModel(initial: 'a👋b')
        ..cursor = 2
        ..update(leftMsg());
      expect(model.cursor, equals(1)); // now at 👋

      model.update(rightMsg());
      expect(model.cursor, equals(2)); // back at b
    });
  });

  group('TextInputModel.update Ctrl keybindings', () {
    KeyMsg ctrlKey(String char) => KeyMsg(
      KeyEvent(KeyCode.char(char), modifiers: KeyModifiers.ctrl),
    );

    KeyMsg ctrlLeft() => const KeyMsg(
      KeyEvent(KeyCode.named(KeyCodeName.left), modifiers: KeyModifiers.ctrl),
    );

    KeyMsg ctrlRight() => const KeyMsg(
      KeyEvent(
        KeyCode.named(KeyCodeName.right),
        modifiers: KeyModifiers.ctrl,
      ),
    );

    KeyMsg ctrlBackspace() => const KeyMsg(
      KeyEvent(
        KeyCode.named(KeyCodeName.backSpace),
        modifiers: KeyModifiers.ctrl,
      ),
    );

    KeyMsg ctrlDelete() => const KeyMsg(
      KeyEvent(
        KeyCode.named(KeyCodeName.delete),
        modifiers: KeyModifiers.ctrl,
      ),
    );

    test('Ctrl+A moves to start', () {
      final model = TextInputModel(initial: 'hello')
        ..cursor = 3
        ..update(ctrlKey('a'));
      expect(model.cursor, equals(0));
    });

    test('Ctrl+E moves to end', () {
      final model = TextInputModel(initial: 'hello')
        ..cursor = 2
        ..update(ctrlKey('e'));
      expect(model.cursor, equals(5));
    });

    test('Ctrl+K kills to end of line', () {
      final model = TextInputModel(initial: 'hello world')
        ..cursor = 5
        ..update(ctrlKey('k'));
      expect(model.value, equals('hello'));
      expect(model.cursor, equals(5));
    });

    test('Ctrl+U deletes to line start', () {
      final model = TextInputModel(initial: 'hello world')
        ..cursor = 6
        ..update(ctrlKey('u'));
      expect(model.value, equals('world'));
      expect(model.cursor, equals(0));
    });

    test('Ctrl+W deletes word left', () {
      final model = TextInputModel(initial: 'hello world')..update(ctrlKey('w'));
      expect(model.value, equals('hello '));
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Left jumps word left', () {
      final model = TextInputModel(initial: 'hello world')
        ..cursor = 8
        ..update(ctrlLeft());
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Right jumps word right', () {
      final model = TextInputModel(initial: 'hello world')
        ..cursor = 0
        ..update(ctrlRight());
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Backspace deletes word left', () {
      final model = TextInputModel(initial: 'hello world')..update(ctrlBackspace());
      expect(model.value, equals('hello '));
      expect(model.cursor, equals(6));
    });

    test('Ctrl+Delete deletes word right', () {
      final model = TextInputModel(initial: 'hello world')
        ..cursor = 0
        ..update(ctrlDelete());
      expect(model.value, equals('world'));
      expect(model.cursor, equals(0));
    });

    test('Ctrl+char does not insert character', () {
      final model = TextInputModel(initial: 'hello')..update(ctrlKey('x'));
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
}
