import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Paragraph >', () {
    // void testCase(Paragraph paragraph, Buffer expected) {
    //   final buf = Buffer.empty(expected.area);
    //   paragraph.render(expected.area, buf);
    //   expect(buf.eq(expected), isTrue);
    // }

    test('render one line with enough space', () {
      final line = Paragraph(content: 'Hello World');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 20, height: 2));
      line.render(buf.area, Frame(buf.area, buf, 0));

      expect(
        buf.eq(
          Buffer.fromStringLines([
            'Hello World         ',
            '                    ',
          ]),
        ),
        isTrue,
      );
    });

    test('render two line with enough space', () {
      final line = Paragraph(content: 'Hello World\nBuenos Dias!');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 20, height: 2));
      line.render(buf.area, Frame(buf.area, buf, 0));

      expect(
        buf.eq(
          Buffer.fromStringLines([
            'Hello World         ',
            'Buenos Dias!        ',
          ]),
        ),
        isTrue,
      );
    });

    test('render a wrapping line', () {
      final para = Paragraph(content: 'Hello World Buenos Dias!');
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 21, height: 2));
      para.render(buf.area, Frame(buf.area, buf, 0));

      expect(
        buf.eq(
          Buffer.fromStringLines([
            'Hello World Buenos   ',
            'Dias!                ',
          ]),
        ),
        isTrue,
      );
    });

    test('render a wrapping line width spans', () {
      final line1 = Line.fromSpans(const [
        Span('Hello World'),
        Span(' Buenos Dias!'),
      ]);
      final para = Paragraph.withText(Text.fromLines([line1]));
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 21, height: 2));
      para.render(buf.area, Frame(buf.area, buf, 0));

      expect(
        buf.eq(
          Buffer.fromStringLines([
            'Hello World Buenos   ',
            'Dias!                ',
          ]),
        ),
        isTrue,
      );
    });

    test('render a wrapping line width spans spanning multiple lines', () {
      final line1 = Line.fromSpans(const [
        Span(
          'The brow fox ',
          style: Style(fg: Color.red),
        ),
        Span(
          'jumps over the lazy dog ',
          style: Style(fg: Color.green),
        ),
        Span(
          'and the funny snake ',
          style: Style(fg: Color.magenta),
        ),
      ]);
      final line2 = Line.fromSpans(const [
        Span(
          'from down the hill ',
          style: Style(fg: Color.blue),
        ),
        Span(
          'but the dog is too lazy to care',
          style: Style(fg: Color.yellow),
        ),
      ]);
      final para = Paragraph.withText(Text.fromLines([line1, line2]));
      final rect = Rect.create(x: 0, y: 0, width: 21, height: 4);
      final buf = Buffer.empty(rect);
      para.render(buf.area, Frame(buf.area, buf, 0));

      final expected = Buffer.setCells(rect, [
        (x: 0, y: 0, char: 'The brow fox ', style: const Style(fg: Color.red)),
        (x: 13, y: 0, char: 'jumps ', style: const Style(fg: Color.green)),
        (
          x: 0,
          y: 1,
          char: 'over the lazy dog ',
          style: const Style(fg: Color.green),
        ),
        (x: 18, y: 1, char: 'and', style: const Style(fg: Color.magenta)),
        (
          x: 0,
          y: 2,
          char: 'the funny snake ',
          style: const Style(fg: Color.magenta),
        ),
        (
          x: 0,
          y: 3,
          char: 'from down the hill ',
          style: const Style(fg: Color.blue),
        ),
      ]);

      expect(buf.eq(expected), isTrue);
    });

    test('using wide chars', () {}, skip: true);
    test('using wide chars at the end of the wrap', () {}, skip: true);

    // test('zero with at end of the line', () {
    //   const line = 'foo\u200B';
    //   for (final paragraph in [
    //     Paragraph(line),
    //     Paragraph(line, wrap: (trim: true)),
    //   ]) {
    //     testCase(paragraph, Buffer.fromStringLines([line]));
    //   }
    // });
  });
}
