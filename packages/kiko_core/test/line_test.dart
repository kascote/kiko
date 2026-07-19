import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Line >', () {
    test('raw str', () {
      final line = Line('test content');
      expect(line.texts, [const Text('test content')]);

      final line2 = Line('a\nb');
      expect(line2.texts, [const Text('a'), const Text('b')]);
    });

    test('styled str', () {
      const style = Style(fg: Color.yellow);
      const content = 'hello world';
      final line = Line(content, style: style);
      expect(line.texts, [const Text(content)]);
      expect(line.style, style);
    });

    test('span iter', () {
      const content = [Text('1'), Text('2'), Text('3')];
      final line = Line.fromTexts(content);
      expect(line.texts, content);
    });

    test('style', () {
      final line = Line('', style: const Style(fg: Color.red));
      expect(line.style, const Style(fg: Color.red));
    });

    test('width', () {
      final line = Line.fromTexts(const [
        Text('My', style: Style(fg: Color.red)),
        Text(' text'),
      ]);
      expect(line.width(const TermUnicodeMeasurer()), 7);

      final empty = Line('');
      expect(empty.width(const TermUnicodeMeasurer()), 0);
    });

    test('patch style', () {
      final line = Line(
        'foobar',
        style: const Style(fg: Color.yellow),
      );
      final line2 = Line(
        'foobar',
        style: const Style(
          fg: Color.yellow,
          addModifier: Modifier.italic,
        ),
      );

      expect(line, isNot(equals(line2)));

      final line3 = line.patchStyle(const Style(addModifier: Modifier.italic));
      expect(line3, line2);
    });

    test('reset style', () {
      final line = Line(
        'foobar',
        style: const Style(
          fg: Color.yellow,
          bg: Color.red,
          addModifier: Modifier.italic,
        ),
      ).resetStyle();

      expect(line.style, const Style.reset());
    });

    test('from String', () {
      const s = 'Hello World!';
      final line = Line(s);
      expect(line.texts, [const Text(s)]);

      const s2 = 'Hello\nWorld!';
      final line2 = Line(s2);
      expect(line2.texts, [
        const Text('Hello'),
        const Text('World!'),
      ]);
    });

    test('add span', () {
      final line =
          Line(
            'Hello',
            style: const Style(fg: Color.red),
          ).add(
            const Text(
              ' World!',
              style: Style(fg: Color.blue),
            ),
          );
      expect(line.texts, [
        const Text('Hello'),
        const Text(
          ' World!',
          style: Style(fg: Color.blue),
        ),
      ]);
      expect(line.style, const Style(fg: Color.red));
    });

    test('styled graphemes', () {
      const red = Style(fg: Color.red);
      const green = Style(fg: Color.green);
      const blue = Style(fg: Color.blue);
      const redOnWhite = Style(fg: Color.red, bg: Color.white);
      const greenOnWhite = Style(fg: Color.green, bg: Color.white);
      const blueOnWhite = Style(fg: Color.blue, bg: Color.white);

      final line = Line.fromTexts(const [
        Text('He', style: red),
        Text('ll', style: green),
        Text('o1', style: blue),
      ]);

      final styled = line.styledChars(const Style(bg: Color.white)).toList();
      expect(styled, [
        StyledChar('H', redOnWhite),
        StyledChar('e', redOnWhite),
        StyledChar('l', greenOnWhite),
        StyledChar('l', greenOnWhite),
        StyledChar('o', blueOnWhite),
        StyledChar('1', blueOnWhite),
      ]);
    });

    test('push span', () {
      final line = Line(
        'A',
      ).add(const Text('B')).add(const Text('C'));

      expect(line.texts, [const Text('A'), const Text('B'), const Text('C')]);
    });

    test('copyWith', () {
      final line = Line('foo', style: const Style(fg: Color.red));
      final copy = line.copyWith(texts: [const Text('bar')]);
      expect(copy, Line('bar', style: const Style(fg: Color.red)));
      final copy2 = line.copyWith(style: const Style(fg: Color.blue));
      expect(
        copy2,
        Line(
          'foo',
          style: const Style(fg: Color.blue),
        ),
      );
    });

    test('toString', () {
      final line = Line('foo');
      expect(line.toString(), '''
Line(
  texts: [Text(foo, Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)))],
  style: Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE))
)
''');
    });

    test('equality', () {
      expect(Line('foo'), Line('foo'));
      expect(Line('foo').hashCode, Line('foo').hashCode);
      expect(Line('foo'), isNot(Line('bar')));
    });
  });
}
