import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Text >', () {
    test('raw', () {
      final text = Text.raw('The first line\nThe second line');
      expect(text.lines, [
        Line.fromSpan(const Span('The first line')),
        Line.fromSpan(const Span('The second line')),
      ]);
    });

    test('styled', () {
      const style = Style(fg: Color.yellow, addModifier: Modifier.italic);
      final styledText = Text.raw(
        'The first line\nThe second line',
        style: style,
      );

      final text = Text.raw('The first line\nThe second line', style: style);

      expect(styledText, text);
    });

    test('width', () {
      final text = Text.raw('The first line\nThe second line');
      expect(text.width, 15);
    });

    test('height', () {
      final text = Text.raw('The first line\nThe second line');
      expect(text.height, 2);
    });

    test('patchStyle', () {
      const style = Style(fg: Color.yellow, addModifier: Modifier.italic);
      const style2 = Style(fg: Color.red, addModifier: Modifier.underlined);
      final text = Text.raw(
        'The first line\nThe second line',
        style: style,
      ).patchStyle(style2);

      final expectedStyle = Style(
        fg: Color.red,
        addModifier: Modifier.italic | Modifier.underlined,
      );
      final expectedText = Text.raw(
        'The first line\nThe second line',
        style: expectedStyle,
      );

      expect(text, expectedText);
    });

    test('reset style', () {
      const style = Style(fg: Color.yellow, addModifier: Modifier.italic);
      final text = Text.raw(
        'The first line\nThe second line',
        style: style,
      ).resetStyle();

      expect(text.style, const Style.reset());
    });

    test('add', () {
      final text1 = Text.raw('The first line\nThe second line');
      final text2 = Text.raw('The third line\nThe fourth line');
      final text3 = text1.add(text2);
      final expectedText = Text.raw(
        'The first line\nThe second line\nThe third line\nThe fourth line',
      );
      expect(text3, expectedText);
    });

    test('addLine', () {
      final text = Text.raw(
        'The first line\nThe second line',
      ).addLine(Line.fromSpan(const Span('The third line')));
      final expectedText = Text.raw(
        'The first line\nThe second line\nThe third line',
      );
      expect(text, expectedText);
    });

    test('addSpan', () {
      final text = Text.raw(
        'The first line\nThe second line',
      ).addSpan(const Span('The third line'));
      final expectedText = Text.raw('The first line\nThe second line')..lines.last.add(const Span('The third line'));
      expect(text, expectedText);
    });

    test('addSpan empty', () {
      final text = Text(
        const [],
      ).addSpan(const Span('foo bar'));
      final expectedText = Text([Line('foo bar')]);
      expect(text, expectedText);
    });

    test('toString', () {
      final text = Text.raw('The first line\nThe second line');
      expect(text.toString(), '''
Line(
  spans: [Span(The first line, Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)))],
  style: Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)),
  alignment: null
)
Line(
  spans: [Span(The second line, Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)))],
  style: Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)),
  alignment: null
)

Style(fg: null, bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE))
null
''');
    });

    test('equality', () {
      final t = Text.raw('foo bar');
      expect(t, Text.raw('foo bar'));
      expect(t, isNot(Text.raw('bar')));
      expect(t.hashCode, Text.raw('foo bar').hashCode);
    });

    test('render', () {
      final text = Text.raw('foo');
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);
      final buf = Buffer.empty(area);
      text.render(area, Frame(buf.area, buf, 0));

      expect(buf.eq(Buffer.fromStringLines(['foo  '])), isTrue);
    });

    test('render out ouf bounds', () {
      final oob = Rect.create(x: 20, y: 20, width: 10, height: 1);
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 1));
      Text.raw('Hello, World!').render(oob, Frame(buf.area, buf, 0));

      expect(
        buf.eq(Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 1))),
        isTrue,
      );
    });

    test('render with alignment', () {
      final text = Text.raw('foo', alignment: Alignment.right);
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);
      final buf = Buffer.empty(area);
      text.render(area, Frame(buf.area, buf, 0));
      expect(buf.eq(Buffer.fromStringLines(['  foo'])), isTrue);
    });

    test('render center odd', () {
      final text = Text.raw('foo', alignment: Alignment.center);
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);
      final buf = Buffer.empty(area);
      text.render(area, Frame(buf.area, buf, 0));
      expect(buf.eq(Buffer.fromStringLines([' foo '])), isTrue);
    });

    test('render center even', () {
      final text = Text.raw('foo', alignment: Alignment.center);
      final area = Rect.create(x: 0, y: 0, width: 6, height: 1);
      final buf = Buffer.empty(area);
      text.render(area, Frame(buf.area, buf, 0));
      expect(buf.eq(Buffer.fromStringLines([' foo  '])), isTrue);
    });

    test('render one line right', () {
      final text = Text.fromLines(
        [
          Line('foo'),
          Line('bar', alignment: Alignment.center),
        ],
        alignment: Alignment.right,
      );

      final area = Rect.create(x: 0, y: 0, width: 5, height: 2);
      final buf = Buffer.empty(area);
      text.render(area, Frame(buf.area, buf, 0));
      expect(buf.eq(Buffer.fromStringLines(['  foo', ' bar '])), isTrue);
    });

    test('render only styles line area', () {
      final area = Rect.create(x: 0, y: 0, width: 5, height: 1);
      final buf = Buffer.empty(area);
      final line = Line.fromSpan(
        const Span(
          'foo',
          style: Style(bg: Color.blue),
        ),
      );
      Text.fromLines([line]).render(area, Frame(buf.area, buf, 0));

      final expected = Buffer.fromStringLines(['foo  '])
        ..setStyle(
          Rect.create(x: 0, y: 0, width: 3, height: 1),
          const Style(bg: Color.blue),
        );

      expect(buf.eq(expected), isTrue);
    });

    test('render truncates', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1));
      final line = Line.fromSpan(
        const Span(
          'foobar',
          style: Style(bg: Color.blue),
        ),
      );
      Text.fromLines([
        line,
      ]).render(Rect.create(x: 0, y: 0, width: 3, height: 1), Frame(buf.area, buf, 0));

      final expected = Buffer.fromStringLines(['foo   '])
        ..setStyle(
          Rect.create(x: 0, y: 0, width: 3, height: 1),
          const Style(bg: Color.blue),
        );

      expect(buf.eq(expected), isTrue);
    });
  });
}
