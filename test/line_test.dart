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

    group('render >', () {
      const blue = Style(fg: Color.blue);
      const green = Style(fg: Color.green);
      const italic = Style(addModifier: Modifier.italic);

      final helloWorld = Line.fromSpans(
        const [Span('Hello ', style: blue), Span('World!', style: green)],
        style: italic,
      );

      final smallBuffer = Buffer.empty(
        Rect.create(x: 0, y: 0, width: 10, height: 1),
      );

      test('render', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 15, height: 1));
        helloWorld.render(Rect.create(x: 0, y: 0, width: 15, height: 1), Frame(buf.area, buf, 0));
        final expected =
            Buffer.fromLines([
                Line.fromSpans(const [Span('Hello '), Span('World!   ')]),
              ])
              ..setStyle(Rect.create(x: 0, y: 0, width: 15, height: 1), italic)
              ..setStyle(Rect.create(x: 0, y: 0, width: 6, height: 1), blue)
              ..setStyle(Rect.create(x: 6, y: 0, width: 6, height: 1), green);

        expect(buf.eq(expected), isTrue);
      });

      test('out of bounds', () {
        final oob = Rect.create(x: 20, y: 20, width: 10, height: 1);
        helloWorld.render(oob, Frame(smallBuffer.area, smallBuffer, 0));

        expect(smallBuffer.eq(Buffer.empty(smallBuffer.area)), isTrue);
      });

      test('render only style lines area', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 20, height: 1));
        helloWorld.render(Rect.create(x: 0, y: 0, width: 15, height: 1), Frame(buf.area, buf, 0));

        final expected =
            Buffer.fromLines([
                Line.fromSpans(const [
                  Span('Hello '),
                  Span('World!        '),
                ]),
              ])
              ..setStyle(Rect.create(x: 0, y: 0, width: 15, height: 1), italic)
              ..setStyle(Rect.create(x: 0, y: 0, width: 6, height: 1), blue)
              ..setStyle(Rect.create(x: 6, y: 0, width: 6, height: 1), green);

        expect(buf.eq(expected), isTrue);
      });

      test('render only styles first line', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 20, height: 2));
        helloWorld.render(buf.area, Frame(buf.area, buf, 0));
        final expected =
            Buffer.fromLines(
                [
                  Line('Hello World!        '),
                  Line('                    '),
                ],
              )
              ..setStyle(Rect.create(x: 0, y: 0, width: 20, height: 1), italic)
              ..setStyle(Rect.create(x: 0, y: 0, width: 6, height: 1), blue)
              ..setStyle(Rect.create(x: 6, y: 0, width: 6, height: 1), green);

        expect(buf.eq(expected), isTrue);
      });

      test('render truncate', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 1));
        Line(
          'Hello World',
        ).render(Rect.create(x: 0, y: 0, width: 5, height: 1), Frame(buf.area, buf, 0));
        expect(buf.eq(Buffer.fromLines([Line('Hello     ')])), isTrue);
      });

      test('render centered', () {
        final line = helloWorld.copyWith(alignment: Alignment.center);
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 15, height: 1));
        line.render(Rect.create(x: 0, y: 0, width: 15, height: 1), Frame(buf.area, buf, 0));

        final expected = Buffer.fromLines([Line(' Hello World!  ')])
          ..setStyle(Rect.create(x: 0, y: 0, width: 15, height: 1), italic)
          ..setStyle(Rect.create(x: 1, y: 0, width: 6, height: 1), blue)
          ..setStyle(Rect.create(x: 7, y: 0, width: 6, height: 1), green);

        expect(buf.eq(expected), isTrue);
      });

      test('render right aligned', () {
        final line = helloWorld.copyWith(alignment: Alignment.right);
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 15, height: 1));
        line.render(Rect.create(x: 0, y: 0, width: 15, height: 1), Frame(buf.area, buf, 0));

        final expected = Buffer.fromLines([Line('   Hello World!')])
          ..setStyle(Rect.create(x: 0, y: 0, width: 15, height: 1), italic)
          ..setStyle(Rect.create(x: 3, y: 0, width: 6, height: 1), blue)
          ..setStyle(Rect.create(x: 9, y: 0, width: 6, height: 1), green);

        expect(buf.eq(expected), isTrue);
      });

      test('truncate left', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 1));
        Line(
          'Hello World',
          alignment: Alignment.left,
        ).render(buf.area, Frame(buf.area, buf, 0));

        final expected = Buffer.fromLines([Line('Hello')]);
        expect(buf.eq(expected), isTrue);
      });

      test('truncate right', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 1));
        Line(
          'Hello World',
          alignment: Alignment.right,
        ).render(buf.area, Frame(buf.area, buf, 0));

        final expected = Buffer.fromLines([Line('World')]);
        expect(buf.eq(expected), isTrue);
      });

      test('truncate center', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 1));
        Line(
          'Hello World',
          alignment: Alignment.center,
        ).render(buf.area, Frame(buf.area, buf, 0));

        final expected = Buffer.fromLines([Line('lo Wo')]);
        expect(buf.eq(expected), isTrue);
      });

      test('truncate multibyte', () {
        final line = Line(
          '"🦀 RFC8628 OAuth 2.0 Device Authorization GrantでCLIからGithubのaccess tokenを取得する',
        );
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 83, height: 1));
        line.render(buf.area, Frame(buf.area, buf, 0));
        expect(
          buf.eq(
            Buffer.fromLines(
              [
                Line(
                  '"🦀 RFC8628 OAuth 2.0 Device Authorization GrantでCLIからGithubのaccess tokenを取得',
                ),
              ],
            ),
          ),
          isTrue,
        );
      });

      test('truncate emoji', () {
        final cases = [
          (Alignment.left, 4, '1234'),
          (Alignment.left, 5, '1234 '),
          (Alignment.left, 6, '1234🦀'),
          (Alignment.left, 7, '1234🦀7'),
          (Alignment.right, 4, '7890'),
          (Alignment.right, 5, ' 7890'),
          (Alignment.right, 6, '🦀7890'),
          (Alignment.right, 7, '4🦀7890'),
        ];

        for (final (alignment, width, expected) in cases) {
          final line = Line('1234🦀7890', alignment: alignment);
          final buf = Buffer.empty(
            Rect.create(x: 0, y: 0, width: width, height: 1),
          );
          line.render(buf.area, Frame(buf.area, buf, 0));
          expect(buf.eq(Buffer.fromLines([Line(expected)])), isTrue);
        }
      });

      test('truncate emoji centered', () {
        final cases = [
          (6, 0, ''),
          (6, 1, ' '), // lef side of "🦀"
          (6, 2, '🦀'),
          (6, 3, 'b🦀'),
          (6, 4, 'b🦀c'),
          (7, 0, ''),
          (7, 1, ' '), // right side of "🦀"
          (7, 2, '🦀'),
          (7, 3, '🦀c'),
          (7, 4, 'b🦀c'),
          (8, 0, ''),
          (8, 1, ' '), // right side of "🦀"
          (8, 2, ' c'), // right side of "🦀c"
          (8, 3, '🦀c'),
          (8, 4, '🦀cd'),
          (8, 5, 'b🦀cd'),
          (9, 0, ''),
          (9, 1, 'c'),
          (9, 2, ' c'), // right side of "🦀c"
          (9, 3, ' cd'),
          (9, 4, '🦀cd'),
          (9, 5, '🦀cde'),
          (9, 6, 'b🦀cde'),
        ];

        for (final (lineWidth, bufWidth, expected) in cases) {
          // because the crab emoji is 2 characters wide, it will can cause the centering tests
          // intersect with either the left or right part of the emoji, which causes the emoji to
          // be not rendered. Checking for four different widths of the line is enough to cover
          // all the possible cases.
          final value = switch (lineWidth) {
            6 => 'ab🦀cd',
            7 => 'ab🦀cde',
            8 => 'ab🦀cdef',
            9 => 'ab🦀cdefg',
            _ => throw ArgumentError('Invalid width: $lineWidth'),
          };
          final line = Line(value, alignment: Alignment.center);
          final buf = Buffer.empty(
            Rect.create(x: 0, y: 0, width: bufWidth, height: 1),
          );
          line.render(buf.area, Frame(buf.area, buf, 0));
          expect(buf.eq(Buffer.fromLines([Line(expected)])), isTrue);
        }
      });

      test('truncates away from 0x0', () {
        final cases = [
          (Alignment.left, 'XXa🦀bcXXX'),
          (Alignment.center, 'XX🦀bc🦀XX'),
          (Alignment.right, 'XXXbc🦀dXX'),
        ];

        for (final (alignment, expected) in cases) {
          final line = Line.fromSpans(
            const [
              Span('a🦀b'),
              Span('c🦀d'),
            ],
            alignment: alignment,
          );
          final buf = Buffer.filled(
            Rect.create(x: 0, y: 0, width: 10, height: 1),
            const Cell(char: 'X'),
          );
          final area = Rect.create(x: 2, y: 0, width: 6, height: 1);
          line.render(area, Frame(buf.area, buf, 0));
          expect(buf.eq(Buffer.fromLines([Line(expected)])), isTrue);
        }
      });

      test('right aligned multi span', () {
        final cases = [
          (4, 'c🦀d'),
          (5, 'bc🦀d'),
          (6, 'Xbc🦀d'),
          (7, '🦀bc🦀d'),
          (8, 'a🦀bc🦀d'),
        ];

        for (final (width, expected) in cases) {
          final line = Line.fromSpans(
            const [
              Span('a🦀b'),
              Span('c🦀d'),
            ],
            alignment: Alignment.right,
          );
          final area = Rect.create(x: 0, y: 0, width: width, height: 1);
          final buf = Buffer.filled(area, const Cell(char: 'X'));
          line.render(buf.area, Frame(buf.area, buf, 0));

          expect(
            buf.eq(Buffer.fromLines([Line(expected)])),
            isTrue,
            reason: 'case: $width - $expected',
          );
        }
      });

      test('truncate long line, many spans', () {
        final cases = [
          (Alignment.left, 'This is some content with a some'),
          (Alignment.right, 'horribly long Line over u16::MAX'),
        ];

        const part =
            'This is some content with a somewhat long width to be repeated over and over again to create horribly long Line over u16::MAX';
        const minWidth = 65535;
        final factor = (minWidth / part.length).ceil();
        var line = Line.fromSpans(
          List.filled(factor, const Span(part)),
        );

        for (final (alignment, expected) in cases) {
          line = line.copyWith(alignment: alignment);

          expect(line.width, greaterThanOrEqualTo(minWidth));
          final buf = Buffer.empty(
            Rect.create(x: 0, y: 0, width: 32, height: 1),
          );
          line.render(buf.area, Frame(buf.area, buf, 0));
          expect(buf.eq(Buffer.fromStringLines([expected])), isTrue);
        }
      });

      test('truncate long line, over one span', () {
        final cases = [
          (Alignment.left, 'This is some content with a some'),
          (Alignment.right, 'horribly long Line over u16::MAX'),
        ];

        const part =
            'This is some content with a somewhat long width to be repeated over and over again to create horribly long Line over u16::MAX';
        const minWidth = 65535;
        final factor = (minWidth / part.length).ceil();
        var line = Line.fromSpans([Span(part * factor)]);

        for (final (alignment, expected) in cases) {
          line = line.copyWith(alignment: alignment);

          expect(line.width, greaterThanOrEqualTo(minWidth));
          final buf = Buffer.empty(
            Rect.create(x: 0, y: 0, width: 32, height: 1),
          );
          line.render(buf.area, Frame(buf.area, buf, 0));
          expect(buf.eq(Buffer.fromStringLines([expected])), isTrue);
        }
      });

      test('render with new lines', () {
        final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 11, height: 1));
        Line.fromSpan(
          const Span('Hello\nWorld!'),
        ).render(Rect.create(x: 0, y: 0, width: 11, height: 1), Frame(buf.area, buf, 0));
        expect(buf.eq(Buffer.fromStringLines(['HelloWorld!'])), isTrue);
      });

      test('truncates flag', () {
        final cases = [
          (width: 1, expected: ' '),
          (width: 2, expected: '🇺🇸'),
          (width: 3, expected: '🇺🇸1'),
          (width: 4, expected: '🇺🇸12'),
          (width: 5, expected: '🇺🇸123'),
          (width: 6, expected: '🇺🇸1234'),
          (width: 7, expected: '🇺🇸1234 '),
        ];

        for (final kase in cases) {
          final line = Line('🇺🇸1234');
          final buf = Buffer.empty(
            Rect.create(x: 0, y: 0, width: kase.width, height: 1),
          );
          line.render(buf.area, Frame(buf.area, buf, 0));
          final expected = Buffer.fromStringLines([kase.expected]);
          expect(buf.eq(expected), isTrue, reason: 'fail case $kase');
        }
      });
    });
  });
}
