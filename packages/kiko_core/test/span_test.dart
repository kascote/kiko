import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Span', () {
    test('create', () {
      const span = Span('');
      expect(span.content, '');
      expect(span.style, const Style());
    });

    test('create with content', () {
      const span = Span('hello');
      expect(span.content, 'hello');
      expect(span.style, const Style());
    });

    test('create with Style', () {
      const span = Span('', style: Style(fg: Color.red));
      expect(span.content, '');
      expect(span.style, const Style(fg: Color.red));
    });

    test('copyWith', () {
      final span = const Span('hello').copyWith(content: 'world');
      expect(span.content, 'world');
      expect(span.style, const Style());
    });

    test('patchStyle', () {
      final span = const Span(
        'hello',
      ).patchStyle(const Style(fg: Color.red));
      expect(span.content, 'hello');
      expect(span.style, const Style(fg: Color.red));
    });

    test('width', () {
      expect(const Span('').width, 0);
      expect(const Span('test').width, 4);
      expect(const Span('test content').width, 12);
      expect(const Span('test\ncontent').width, 11);
    });

    test('newline span', () {
      const span = Span('hello\nworld');
      expect(span.width, 10);
      expect(span.toString(), contains('helloworld'));
    });

    test('reset style', () {
      const span = Span(
        'hello',
        style: Style(fg: Color.green),
      );
      final reset = span.resetStyle();
      expect(reset.style, const Style.reset());
    });

    test('styled span', () {
      const span = Span(
        'hello',
        style: Style(fg: Color.green),
      );
      expect(
        span.toString(),
        'Span(hello, Style(fg: Color(2, ansi), bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)))',
      );
    });

    test('left alined', () {
      const span = Span(
        'hello',
        style: Style(fg: Color.green),
      );
      final line = span.leftAlignedLine();
      expect(line.alignment, Alignment.left);
    });

    test('center alined', () {
      const span = Span(
        'hello',
        style: Style(fg: Color.green),
      );
      final line = span.centerAlignedLine();
      expect(line.alignment, Alignment.center);
    });

    test('right alined', () {
      const span = Span(
        'hello',
        style: Style(fg: Color.green),
      );
      final line = span.rightAlignedLine();
      expect(line.alignment, Alignment.right);
    });

    test('render', () {
      const style = Style(fg: Color.green, bg: Color.yellow);
      const span = Span('test content', style: style);
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 15, height: 1));

      span.render(buf.area, Frame(buf.area, buf, 0));
      final expected = Buffer.fromLines([
        Line.fromSpans(const [
          Span('test content', style: style),
          Span('   '),
        ]),
      ]);
      expect(buf.eq(expected), isTrue);
    });

    test('patch existing style', () {
      const style = Style(fg: Color.green, bg: Color.yellow);
      const span = Span('test content', style: style);
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 15, height: 1));
      buf.setStyle(buf.area, const Style(addModifier: Modifier.italic));
      span.render(buf.area, Frame(buf.area, buf, 0));

      final expected = Buffer.fromLines([
        Line.fromSpans(const [
          Span(
            'test content',
            style: Style(
              fg: Color.green,
              bg: Color.yellow,
              addModifier: Modifier.italic,
            ),
          ),
          Span(
            '   ',
            style: Style(addModifier: Modifier.italic),
          ),
        ]),
      ]);
      expect(buf.eq(expected), isTrue);
    });

    test('render multi width symbol', () {
      const style = Style(fg: Color.green, bg: Color.yellow);
      const span = Span('test 😀 content', style: style);
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 15, height: 1));
      span.render(buf.area, Frame(buf.area, buf, 0));

      final expected = Buffer.fromLines([
        Line.fromSpans(const [Span('test 😀 content', style: style)]),
      ]);
      expect(buf.eq(expected), isTrue);
    });

    test('multi with symbol truncates entire symbol', () {
      const style = Style(fg: Color.green, bg: Color.yellow);
      const span = Span('test 😀 content', style: style);
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1));
      span.render(buf.area, Frame(buf.area, buf, 0));

      final expected = Buffer.fromLines([
        Line.fromSpans(const [
          Span('test ', style: style),
          Span(' '),
        ]),
      ]);
      expect(buf.eq(expected), isTrue);
    });

    test('overflowing area truncates', () {
      const style = Style(fg: Color.green, bg: Color.yellow);
      const span = Span('test content', style: style);
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 15, height: 1));
      span.render(Rect.create(x: 10, y: 0, width: 20, height: 1), Frame(buf.area, buf, 0));

      final expected = Buffer.fromLines([
        Line.fromSpans(const [
          Span('          '),
          Span('test ', style: style),
        ]),
      ]);
      expect(buf.eq(expected), isTrue);
    });

    test('render first zero-width', () {
      const span = Span('\u{200B}abc');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 3, height: 1));

      span.render(buf.area, Frame(buf.area, buf, 0));
      expect(buf.buf, const [
        Cell(char: '\u{200B}a'),
        Cell(char: 'b'),
        Cell(char: 'c'),
      ]);
    });

    test('render second zero-width', () {
      const span = Span('a\u{200B}bc');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 3, height: 1));

      span.render(buf.area, Frame(buf.area, buf, 0));
      expect(buf.buf, const [
        Cell(char: 'a\u{200B}'),
        Cell(char: 'b'),
        Cell(char: 'c'),
      ]);
    });

    test('render middle zero-width', () {
      const span = Span('ab\u{200B}c');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 3, height: 1));

      span.render(buf.area, Frame(buf.area, buf, 0));
      expect(buf.buf, const [
        Cell(char: 'a'),
        Cell(char: 'b\u{200B}'),
        Cell(char: 'c'),
      ]);
    });

    test('render last zero-width', () {
      const span = Span('abc\u{200B}');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 3, height: 1));

      span.render(buf.area, Frame(buf.area, buf, 0));
      expect(buf.buf, const [
        Cell(char: 'a'),
        Cell(char: 'b'),
        Cell(char: 'c\u{200B}'),
      ]);
    });

    test('render with new line', () {
      const span = Span('a\nb');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 2, height: 1));

      span.render(buf.area, Frame(buf.area, buf, 0));
      expect(buf.buf, const [Cell(char: 'a'), Cell(char: 'b')]);
    });

    test('render last with unicode', () {
      const span = Span('Hello\u{200E}');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 1));

      span.render(buf.area, Frame(buf.area, buf, 0));
      expect(buf.buf, const [
        Cell(char: 'H'),
        Cell(char: 'e'),
        Cell(char: 'l'),
        Cell(char: 'l'),
        Cell(char: 'o\u{200E}'),
      ]);
      // expect(buf, Buffer.fromStringLines(['Hello\u{200E}']));
    });
  });
}
