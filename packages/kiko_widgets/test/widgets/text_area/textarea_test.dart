import 'package:characters/characters.dart';
import 'package:kiko_widgets/src/widgets/text_area/textarea.dart';
import 'package:test/test.dart';

void main() {
  test('Check initialization values', () {
    final buffer = TextAreaComponent();
    expect(buffer.content, ''.characters);
    expect(buffer.row, 0);
    expect(buffer.column, 0);
    expect(buffer.maxLines, 10);
    expect(buffer.maxColumns, 80);
    expect(buffer.maxCharacters, 1000);
  });

  test('Check initialize string', () {
    final buffer = TextAreaComponent()..initBuffer('foo 1\nbar 22\nbaz 333');
    expect(buffer.row, 2);
    expect(buffer.column, 7);
    expect(buffer.content, 'foo 1\nbar 22\nbaz 333'.characters);

    buffer.initBuffer('test');
    expect(buffer.content, 'test'.characters);
    expect(buffer.row, 0);
    expect(buffer.column, 4);
  });

  group('Insert string', () {
    test('insert chars in the middle', () {
      final buffer = TextAreaComponent()
        ..initBuffer('foo baz')
        ..column = 4
        ..insert('bar ');

      expect(buffer.content, 'foo bar baz'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 8);
    });

    test('insert chars at max capacity', () {
      final buffer = TextAreaComponent(maxCharacters: 10)
        ..initBuffer('foo baz')
        ..column = 4
        ..insert('zZzZzZz');

      expect(buffer.content, 'foo zZzbaz'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 7);
    });

    test('insert individual characters', () {
      final buffer = TextAreaComponent()..initBuffer('foo baz');
      void insertChars(String chars) => buffer.insertChars(chars.characters);

      ['b', 'a', 'r', '\n', 's', 'o', 'l'].forEach(insertChars);

      expect(buffer.content, 'foo bazbar\nsol'.characters);
      expect(buffer.row, 1);
      expect(buffer.column, 3);

      final li = buffer.lineInfo();
      expect(li.width, 4);
      expect(li.visualWidth, 4);
      expect(li.height, 1);
      expect(li.startColumn, 0);
      expect(li.columnOffset, 3);
      expect(li.rowOffset, 0);
      expect(li.visualOffset, 3);
    });

    test('inser lines at max lines capacity', () {
      final buffer = TextAreaComponent(maxLines: 2)
        ..initBuffer('foo baz\nbar toc')
        ..column = 4
        ..row = 0
        ..insert('zZzZzZz\nabc');

      expect(buffer.content, 'foo zZzZzZzbaz\nbar toc'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 11);
    });

    test('Insert multiple carriage returns', () {
      final buffer = TextAreaComponent()..initBuffer('\n\n\n');

      expect(buffer.content, '\n\n\n'.characters);
      expect(buffer.row, 3);
      expect(buffer.column, 0);
    });

    test('Insert emojis', () {
      final buffer = TextAreaComponent()
        ..initBuffer('Hello bar')
        ..column = 6
        ..insertChars('🌍 👋🏻 '.characters);

      expect(buffer.content, 'Hello 🌍 👋🏻 bar'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 10);

      final li = buffer.lineInfo();
      expect(li.visualOffset, 12);
      expect(li.columnOffset, 10);
      expect(li.visualWidth, 16);
      expect(li.width, 14);
    });
  });

  group('Move Cursor Down', () {
    test('Line with chars with different visual width', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好\nHello')
        ..row = 0
        ..column = 2;

      var li = buffer.lineInfo();

      expect(li.visualOffset, 4);
      expect(li.columnOffset, 2);

      expect(buffer.row, 0);
      expect(buffer.column, 2);

      buffer.moveCursorDown();

      li = buffer.lineInfo();
      expect(li.visualOffset, 4);
      expect(li.columnOffset, 4);

      expect(buffer.row, 1);
      expect(buffer.column, 4);
    });

    test('Line wrapped base', () {
      final buffer = TextAreaComponent(visualWidth: 10)
        ..initBuffer('foo bar baz argos line')
        ..row = 0
        ..column = 6
        ..moveCursorDown();

      final li = buffer.lineInfo();
      expect(li.width, 10);
      expect(li.visualWidth, 10);
      expect(li.height, 3);
      expect(li.startColumn, 8);
      expect(li.columnOffset, 6);
      expect(li.rowOffset, 1);
      expect(li.visualOffset, 6);

      buffer.moveCursorDown();
      final li2 = buffer.lineInfo();
      expect(li2.width, 5);
      expect(li2.visualWidth, 5);
      expect(li2.height, 3);
      expect(li2.startColumn, 18);
      expect(li2.columnOffset, 4);
      expect(li2.rowOffset, 2);
      expect(li2.visualOffset, 4);
    });

    test('Line wrapped long word to new line', () {
      final buffer = TextAreaComponent(visualWidth: 10)
        ..initBuffer('foo bar baz argoss line')
        ..row = 0
        ..column = 6
        ..moveCursorDown();

      final li = buffer.lineInfo();
      expect(li.width, 4);
      expect(li.visualWidth, 4);
      expect(li.height, 4);
      expect(li.startColumn, 8);
      expect(li.columnOffset, 3);
      expect(li.rowOffset, 1);
      expect(li.visualOffset, 3);

      buffer.moveCursorDown();
      final li2 = buffer.lineInfo();
      expect(li2.width, 7);
      expect(li2.visualWidth, 7);
      expect(li2.height, 4);
      expect(li2.startColumn, 12);
      expect(li2.columnOffset, 6);
      expect(li2.rowOffset, 2);
      expect(li2.visualOffset, 6);
    });

    test('Line wrapped with last word', () {
      final buffer = TextAreaComponent(visualWidth: 10)
        ..initBuffer('foo bar baz argos line')
        ..row = 0
        ..column = 6
        ..moveCursorDown();

      final li = buffer.lineInfo();
      expect(li.width, 10);
      expect(li.visualWidth, 10);
      expect(li.height, 3);
      expect(li.startColumn, 8);
      expect(li.columnOffset, 6);
      expect(li.rowOffset, 1);
      expect(li.visualOffset, 6);

      buffer.moveCursorDown();
      final li2 = buffer.lineInfo();
      expect(li2.width, 5);
      expect(li2.visualWidth, 5);
      expect(li2.height, 3);
      expect(li2.startColumn, 18);
      expect(li2.columnOffset, 4);
      expect(li2.rowOffset, 2);
      expect(li2.visualOffset, 4);
    });

    test('Line wrapped with emoji', () {
      final buffer = TextAreaComponent(visualWidth: 10)
        ..initBuffer('foo bar baz arg🌎 line')
        ..row = 0
        ..column = 6
        ..moveCursorDown();

      final li = buffer.lineInfo();
      expect(li.width, 9);
      expect(li.visualWidth, 10);
      expect(li.height, 3);
      expect(li.startColumn, 8);
      expect(li.columnOffset, 6);
      expect(li.rowOffset, 1);
      expect(li.visualOffset, 6);

      buffer.moveCursorDown();
      final li2 = buffer.lineInfo();
      expect(li2.width, 5);
      expect(li2.visualWidth, 5);
      expect(li2.height, 3);
      expect(li2.startColumn, 17);
      expect(li2.columnOffset, 4);
      expect(li2.rowOffset, 2);
      expect(li2.visualOffset, 4);
    });

    test('Line wrapped long word', () {
      final buffer = TextAreaComponent(visualWidth: 10)
        ..initBuffer('foo bar bazargossss line')
        ..row = 0
        ..column = 6
        ..moveCursorDown();

      final li = buffer.lineInfo();
      expect(li.width, 10);
      expect(li.visualWidth, 10);
      expect(li.height, 3);
      expect(li.startColumn, 8);
      expect(li.columnOffset, 6);
      expect(li.rowOffset, 1);
      expect(li.visualOffset, 6);

      buffer.moveCursorDown();
      final li2 = buffer.lineInfo();
      expect(li2.width, 7);
      expect(li2.visualWidth, 7);
      expect(li2.height, 3);
      expect(li2.startColumn, 18);
      expect(li2.columnOffset, 6);
      expect(li2.rowOffset, 2);
      expect(li2.visualOffset, 6);
    });
  });

  group('Move Cursor Up', () {
    test('lines with different lenghts', () {
      final buffer = TextAreaComponent()..initBuffer('Hi where\nWorld\nThis is a long line');

      expect(buffer.row, 2);
      expect(buffer.column, 19);

      buffer.moveCursorUp();
      expect(buffer.row, 1);
      expect(buffer.column, 5);

      final li = buffer.lineInfo();
      expect(li.width, 6);
      expect(li.visualWidth, 6);
      expect(li.height, 1);
      expect(li.startColumn, 0);
      expect(li.columnOffset, 5);
      expect(li.rowOffset, 0);
      expect(li.visualOffset, 5);

      buffer.moveCursorUp();
      expect(buffer.row, 0);
      expect(buffer.column, 8);

      final li2 = buffer.lineInfo();
      expect(li2.width, 9);
      expect(li2.visualWidth, 9);
      expect(li2.height, 1);
      expect(li2.startColumn, 0);
      expect(li2.columnOffset, 8);
      expect(li2.rowOffset, 0);
      expect(li2.visualOffset, 8);

      buffer
        ..moveCursorDown()
        ..moveCursorDown();
      expect(buffer.row, 2);
      expect(buffer.column, 19);

      final l3 = buffer.lineInfo();
      expect(l3.width, 20);
      expect(l3.visualWidth, 20);
      expect(l3.height, 1);
      expect(l3.startColumn, 0);
      expect(l3.columnOffset, 19);
      expect(l3.rowOffset, 0);
      expect(l3.visualOffset, 19);

      // Now, for correct behavior, if we move right or left, we should forget
      // (reset) the saved horizontal position. Since we assume the user wants to
      // keep the cursor where it is horizontally. This is how most text areas
      // work.

      buffer
        ..moveCursorUp()
        ..moveCursorLeft();

      expect(buffer.row, 1);
      expect(buffer.column, 4);

      final l4 = buffer.lineInfo();
      expect(l4.width, 6);
      expect(l4.visualWidth, 6);
      expect(l4.height, 1);
      expect(l4.startColumn, 0);
      expect(l4.columnOffset, 4);
      expect(l4.rowOffset, 0);
      expect(l4.visualOffset, 4);

      buffer.moveCursorDown();
      expect(buffer.row, 2);
      expect(buffer.column, 4);

      final l5 = buffer.lineInfo();
      expect(l5.width, 20);
      expect(l5.visualWidth, 20);
      expect(l5.height, 1);
      expect(l5.startColumn, 0);
      expect(l5.columnOffset, 4);
      expect(l5.rowOffset, 0);
      expect(l5.visualOffset, 4);
    });
  });

  group('Move Cursor Right', () {
    test('move between multiple wide characters', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好 Hello')
        ..column = 3
        ..moveCursorRight();

      expect(buffer.row, 0);
      expect(buffer.column, 4);
      final li = buffer.lineInfo();
      expect(li.width, 11);
      expect(li.visualWidth, 15);
      expect(li.height, 1);
      expect(li.startColumn, 0);
      expect(li.columnOffset, 4);
      expect(li.rowOffset, 0);
      expect(li.visualOffset, 8);

      buffer.moveCursorRight();
      expect(buffer.row, 0);
      expect(buffer.column, 5);

      final li2 = buffer.lineInfo();
      expect(li2.width, 11);
      expect(li2.visualWidth, 15);
      expect(li2.height, 1);
      expect(li2.startColumn, 0);
      expect(li2.columnOffset, 5);
      expect(li2.rowOffset, 0);
      expect(li2.visualOffset, 9);
    });

    test('move between wrapped lines', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好\nHello')
        ..row = 0
        ..column = 3
        ..moveCursorRight();

      expect(buffer.column, 4);
      expect(buffer.row, 0);

      final li = buffer.lineInfo();
      expect(li.width, 5);
      expect(li.visualWidth, 9);
      expect(li.height, 1);
      expect(li.startColumn, 0);
      expect(li.columnOffset, 4);
      expect(li.rowOffset, 0);
      expect(li.visualOffset, 8);

      buffer.moveCursorRight();
      expect(buffer.column, 0);
      expect(buffer.row, 1);

      final li2 = buffer.lineInfo();
      expect(li2.width, 6);
      expect(li2.visualWidth, 6);
      expect(li2.height, 1);
      expect(li2.startColumn, 0);
      expect(li2.columnOffset, 0);
      expect(li2.rowOffset, 0);
      expect(li2.visualOffset, 0);
    });
  });

  group('Move Cursor Left', () {
    test('move between multiple wide characters', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好 Hello')
        ..column = 6
        ..moveCursorLeft();

      expect(buffer.row, 0);
      expect(buffer.column, 5);

      buffer
        ..moveCursorLeft()
        ..moveCursorLeft();

      expect(buffer.row, 0);
      expect(buffer.column, 3);

      final li = buffer.lineInfo();
      expect(li.width, 11);
      expect(li.visualWidth, 15);
      expect(li.height, 1);
      expect(li.startColumn, 0);
      expect(li.columnOffset, 3);
      expect(li.rowOffset, 0);
      expect(li.visualOffset, 6);
    });

    test('move between wrapped lines', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好\nHello')
        ..row = 1
        ..column = 2
        ..moveCursorLeft();

      expect(buffer.column, 1);
      expect(buffer.row, 1);

      final li = buffer.lineInfo();
      expect(li.width, 6);
      expect(li.visualWidth, 6);
      expect(li.height, 1);
      expect(li.startColumn, 0);
      expect(li.columnOffset, 1);
      expect(li.rowOffset, 0);
      expect(li.visualOffset, 1);

      buffer.moveCursorLeft();
      expect(buffer.column, 0);
      expect(buffer.row, 1);

      final li2 = buffer.lineInfo();
      expect(li2.width, 6);
      expect(li2.visualWidth, 6);
      expect(li2.height, 1);
      expect(li2.startColumn, 0);
      expect(li2.columnOffset, 0);
      expect(li2.rowOffset, 0);
      expect(li2.visualOffset, 0);

      buffer.moveCursorLeft();
      expect(buffer.column, 4); // ? why 3 the first row is 4 chars 8 visual
      expect(buffer.row, 0);

      final li3 = buffer.lineInfo();
      expect(li3.width, 5);
      expect(li3.visualWidth, 9);
      expect(li3.height, 1);
      expect(li3.startColumn, 0);
      expect(li3.columnOffset, 4); // ? why 3 the first row is 4 chars 8 visual
      expect(li3.rowOffset, 0);
      expect(li3.visualOffset, 8); // this match with 3.. is moving one more with wrap around
    });
  });

  test('deleteBeforeCursor', () {
    final buffer = TextAreaComponent()
      ..initBuffer('你好你好 Hello')
      ..column = 2
      ..deleteBeforeCursor();

    expect(buffer.content, '你好 Hello'.characters);
    expect(buffer.row, 0);
    expect(buffer.column, 0);

    buffer
      ..column = 5
      ..deleteBeforeCursor();
    expect(buffer.content, 'llo'.characters);
    expect(buffer.row, 0);
    expect(buffer.column, 0);
  });

  test('deleterAfterCursor', () {
    final buffer = TextAreaComponent()
      ..initBuffer('你好你好 Hello')
      ..column = 7
      ..deleteAfterCursor();

    expect(buffer.content, '你好你好 He'.characters);
    expect(buffer.row, 0);
    expect(buffer.column, 7);

    buffer
      ..column = 3
      ..deleteAfterCursor();
    expect(buffer.content, '你好你'.characters);
    expect(buffer.row, 0);
    expect(buffer.column, 3);
  });

  group('deleteWordLeft', () {
    test('delete single and multi byte', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好 Hello')
        ..column = 6
        ..deleteWordLeft();
      expect(buffer.content, '你好你好 ello'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 5);

      buffer
        ..column = 3
        ..deleteWordLeft();
      expect(buffer.content, '好 ello'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 0);
    });

    test('delete word at the beginning', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好 Hello')
        ..column = 0
        ..deleteWordLeft();
      expect(buffer.content, '你好你好 Hello'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 0);
    });
  });

  group('deleteWordRight', () {
    test('delete single and multi byte', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好 Hello')
        ..column = 2
        ..deleteWordRight();
      expect(buffer.content, '你好 Hello'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 2);

      buffer
        ..column = 5
        ..deleteWordRight();
      expect(buffer.content, '你好 He'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 5);
    });

    test('delete at the end of the line', () {
      final buffer = TextAreaComponent()
        ..initBuffer('你好你好 Hello')
        ..column = 10
        ..deleteWordRight();
      expect(buffer.content, '你好你好 Hello'.characters);
      expect(buffer.row, 0);
      expect(buffer.column, 10);
    });
  });

  test('mergeLineBelow', () {
    final buffer = TextAreaComponent()
      ..initBuffer('你好你好\nHello\nWorld')
      ..mergeLineBelow(1);

    expect(buffer.content, '你好你好\nHelloWorld'.characters);
    expect(buffer.row, 2);
    expect(buffer.column, 5);
  });

  test('mergeLineAbove', () {
    final buffer = TextAreaComponent()
      ..initBuffer('你好你好\nHello\nWorld')
      ..mergeLineAbove(1);

    expect(buffer.content, '你好你好Hello\nWorld'.characters);
    expect(buffer.row, 0);
    expect(buffer.column, 4);
  });

  test('splitLine', () {
    final buffer = TextAreaComponent()
      ..initBuffer('你好你好\nHello\nWorld')
      ..splitLine(1, 2);

    expect(buffer.content, '你好你好\nHe\nllo\nWorld'.characters);
    expect(buffer.row, 2);
    expect(buffer.column, 0);
  });

  test('lineInfo', () {
    final buffer = TextAreaComponent();

    final li = buffer.lineInfo();
    expect(li.width, 1);
    expect(li.visualWidth, 1);
    expect(li.height, 1);
    expect(li.startColumn, 0);
    expect(li.columnOffset, 0);
    expect(li.rowOffset, 0);
    expect(li.visualOffset, 0);

    expect(
      li.toString(),
      'LineInfo{width: 1, visualWidth: 1, height: 1, startColumn: 0, columnOffset: 0, rowOffset: 0, visualOffset: 0}',
    );
  });
}
