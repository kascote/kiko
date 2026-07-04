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
  });
}
