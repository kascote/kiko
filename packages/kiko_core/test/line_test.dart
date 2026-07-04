import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Line >', () {
    test('raw str', () {
      final line = Line('test content');
      expect(line.spans, [const Span('test content')]);
      expect(line.alignment, isNull);

      final line2 = Line('a\nb');
      expect(line2.spans, [const Span('a'), const Span('b')]);
      expect(line2.alignment, isNull);
    });

    test('styled str', () {
      const style = Style(fg: Color.yellow);
      const content = 'hello world';
      final line = Line(content, style: style);
      expect(line.spans, [const Span(content)]);
      expect(line.style, style);
    });

    test('span iter', () {
      const content = [Span('1'), Span('2'), Span('3')];
      final line = Line.fromSpans(content);
      expect(line.spans, content);
    });

    test('style', () {
      final line = Line('', style: const Style(fg: Color.red));
      expect(line.style, const Style(fg: Color.red));
    });

    test('alignment', () {
      final line = Line('this is left', alignment: Alignment.right);
      expect(line.alignment, Alignment.right);

      final line2 = Line('this is default');
      expect(line2.alignment, isNull);
    });

    test('width', () {
      final line = Line.fromSpans(const [
        Span('My', style: Style(fg: Color.red)),
        Span(' text'),
      ]);
      expect(line.width, 7);

      final empty = Line('');
      expect(empty.width, 0);
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
      expect(line.spans, [const Span(s)]);

      const s2 = 'Hello\nWorld!';
      final line2 = Line(s2);
      expect(line2.spans, [
        const Span('Hello'),
        const Span('World!'),
      ]);
    });

    test('add span', () {
      final line =
          Line(
            'Hello',
            style: const Style(fg: Color.red),
          ).add(
            const Span(
              ' World!',
              style: Style(fg: Color.blue),
            ),
          );
      expect(line.spans, [
        const Span('Hello'),
        const Span(
          ' World!',
          style: Style(fg: Color.blue),
        ),
      ]);
      expect(line.style, const Style(fg: Color.red));
      expect(line.alignment, isNull);
    });

    test('styled graphemes', () {
      const red = Style(fg: Color.red);
      const green = Style(fg: Color.green);
      const blue = Style(fg: Color.blue);
      const redOnWhite = Style(fg: Color.red, bg: Color.white);
      const greenOnWhite = Style(fg: Color.green, bg: Color.white);
      const blueOnWhite = Style(fg: Color.blue, bg: Color.white);

      final line = Line.fromSpans(const [
        Span('He', style: red),
        Span('ll', style: green),
        Span('o1', style: blue),
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
      ).add(const Span('B')).add(const Span('C'));

      expect(line.spans, [const Span('A'), const Span('B'), const Span('C')]);
    });

    test('copyWith', () {
      final line = Line('foo');
      final copy = line.copyWith(alignment: Alignment.center);
      expect(copy, Line('foo', alignment: Alignment.center));
      final copy2 = line.copyWith(style: const Style(fg: Color.red));
      expect(
        copy2,
        Line(
          'foo',
          style: const Style(fg: Color.red),
        ),
      );
    });

    test('toString', () {
      final line = Line('foo');
      expect(line.toString(), '''
Line(
  spans: (Span(foo, Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)))),
  style: Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)),
  alignment: null
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
