import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

void main() {
  group('Text', () {
    test('create', () {
      const span = Text('');
      expect(span.content, '');
      expect(span.style, const Style());
    });

    test('create with content', () {
      const span = Text('hello');
      expect(span.content, 'hello');
      expect(span.style, const Style());
    });

    test('create with Style', () {
      const span = Text('', style: Style(fg: Color.red));
      expect(span.content, '');
      expect(span.style, const Style(fg: Color.red));
    });

    test('copyWith', () {
      final span = const Text('hello').copyWith(content: 'world');
      expect(span.content, 'world');
      expect(span.style, const Style());
    });

    test('patchStyle', () {
      final span = const Text(
        'hello',
      ).patchStyle(const Style(fg: Color.red));
      expect(span.content, 'hello');
      expect(span.style, const Style(fg: Color.red));
    });

    test('width', () {
      expect(const Text('').width, 0);
      expect(const Text('test').width, 4);
      expect(const Text('test content').width, 12);
      expect(const Text('test\ncontent').width, 11);
    });

    test('newline span', () {
      const span = Text('hello\nworld');
      expect(span.width, 10);
      expect(span.toString(), contains('helloworld'));
    });

    test('reset style', () {
      const span = Text(
        'hello',
        style: Style(fg: Color.green),
      );
      final reset = span.resetStyle();
      expect(reset.style, const Style.reset());
    });

    test('styled span', () {
      const span = Text(
        'hello',
        style: Style(fg: Color.green),
      );
      expect(
        span.toString(),
        'Text(hello, Style(fg: Color(2, ansi), bg: null, underline: null, addModifier: Modifier(NONE), subModifier: Modifier(NONE)))',
      );
    });

    test('build inflates to a single-run start-aligned text node', () {
      const span = Text('hi', style: Style(fg: Color.green));
      final node = span.build() as plume.Text<PaintToken>;
      expect(node.align, plume.TextAlign.start);
      expect(node.runs, [const plume.TextRun<PaintToken>('hi', PaintToken(Style(fg: Color.green)))]);
    });
  });
}
