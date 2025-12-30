import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Buffer', () {
    test('emptyBuffer', () {
      final buf = Buffer.empty(Rect.zero);
      expect(
        buf.debug(),
        'Buffer {\n    area: Rect(0x0+0+0)\n},\n    content: [\n    ],\n    styles: [\n    ]\n}',
      );
    });

    test('overrides', () {
      final buf = Buffer.fromStringLines(['a🦀b']);
      expect(buf.debug(), '''
Buffer {
    area: Rect(0x0+4+1),
    content: [
        "a🦀b", // overwritten: [(2,  )]
    ],
    styles: [
        x: 0, y: 0, fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE)
    ]
}''');
    });

    test('style', () {
      final buf = Buffer.fromLines([
        Line.fromSpan(const Span('Hello World!', style: Style())),
        Line.fromSpan(
          Span(
            "G'day World!",
            style: const Style(
              fg: Color.green,
              bg: Color.yellow,
            ).incModifier(Modifier.bold),
          ),
        ),
      ]);
      expect(buf.debug(), '''
Buffer {
    area: Rect(0x0+12+2),
    content: [
        "Hello World!",
        "G'day World!",
    ],
    styles: [
        x: 0, y: 0, fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE)
        x: 0, y: 1, fg: Color(2, ansi), bg: Color(3, ansi), underline: Color(Reset), modifier: Modifier(bold)
    ]
}''');
    });

    test('translate from/to coordinates', () {
      final rect = Rect.create(x: 200, y: 100, width: 50, height: 80);
      final buf = Buffer.empty(rect);

      expect(buf.posOf(0), (x: 200, y: 100));
      expect(buf.indexOf(200, 100), 0);

      expect(buf.posOf(buf.buf.length - 1), (x: 249, y: 179));
      expect(buf.indexOf(249, 179), buf.buf.length - 1);
    });

    test('out of bounds', () {
      final rect = Rect.create(x: 0, y: 0, width: 10, height: 10);
      final buf = Buffer.empty(rect);

      expect(() => buf.posOf(100), throwsA(isA<RangeError>()));
    });

    test('index error on out of bounds', () {
      final buf = Buffer.empty(
        Rect.create(x: 10, y: 10, width: 10, height: 10),
      );
      // left
      expect(() => buf.indexOf(9, 10), throwsA(isA<RangeError>()));
      // top
      expect(() => buf.indexOf(10, 9), throwsA(isA<RangeError>()));
      // right
      expect(() => buf.indexOf(20, 10), throwsA(isA<RangeError>()));
      // bottom
      expect(() => buf.indexOf(10, 20), throwsA(isA<RangeError>()));
    });

    test('cell', () {
      final buf = Buffer.fromStringLines(['Hello', 'World']);
      const expected = Cell(char: 'H');

      expect(buf.cellAtPoint((x: 0, y: 0)), expected);
      expect(buf.cellAtPoint((x: 10, y: 10)), null);

      expect(buf.cellAtPos(Position.origin), expected);
      expect(buf.cellAtPos(const Position(10, 10)), null);
    });

    test('index', () {
      final buf = Buffer.fromStringLines(['Hello', 'World']);
      const expected = Cell(char: 'H');

      expect(buf[(x: 0, y: 0)], expected);
    });

    test('index error', () {
      final buf = Buffer.empty(
        Rect.create(x: 10, y: 10, width: 10, height: 10),
      );
      // left
      expect(() => buf[(x: 9, y: 10)], throwsA(isA<RangeError>()));
      // top
      expect(() => buf[(x: 10, y: 9)], throwsA(isA<RangeError>()));
      // right
      expect(() => buf[(x: 20, y: 10)], throwsA(isA<RangeError>()));
      // bottom
      expect(() => buf[(x: 10, y: 20)], throwsA(isA<RangeError>()));
    });

    test('index update', () {
      final buf = Buffer.fromStringLines(['Cat', 'Dog']);
      buf[(x: 0, y: 0)] = buf[(x: 0, y: 0)].copyWith(char: 'B');
      buf[(x: 0, y: 1)] = buf[(x: 0, y: 1)].copyWith(char: 'L');
      expect(buf.eq(Buffer.fromStringLines(['Bat', 'Log'])), isTrue);
    });

    test('set style', () {
      final buf = Buffer.fromStringLines(['aaaaa', 'bbbbb', 'ccccc'])
        ..setStyle(
          Rect.create(x: 0, y: 1, width: 5, height: 1),
          const Style(fg: Color.red),
        );
      final expected = Buffer.fromLines([
        Line('aaaaa'),
        Line('bbbbb', style: const Style(fg: Color.red)),
        Line('ccccc'),
      ]);
      expect(buf.eq(expected), isTrue);
    });

    test('with lines', () {
      final buf = Buffer.fromStringLines([
        '┌────────┐',
        '│コンピュ│',
        '│ーa 上で│',
        '└────────┘',
      ]);

      expect(buf.area.x, 0);
      expect(buf.area.y, 0);
      expect(buf.area.width, 10);
      expect(buf.area.height, 4);
    });

    test('diff empty empty', () {
      final area = Rect.create(x: 0, y: 0, width: 40, height: 40);
      final prev = Buffer.empty(area);
      final next = Buffer.empty(area);

      final diff = prev.diff(next);
      expect(diff, isEmpty);
    });

    test('empty filled', () {
      final area = Rect.create(x: 0, y: 0, width: 40, height: 40);
      final prev = Buffer.empty(area);
      final next = Buffer.filled(area, const Cell(char: 'a'));

      final diff = prev.diff(next);
      expect(diff.length, 40 * 40);
    });

    test('filled filled', () {
      final area = Rect.create(x: 0, y: 0, width: 40, height: 40);
      final prev = Buffer.filled(area, const Cell(char: 'a'));
      final next = Buffer.filled(area, const Cell(char: 'a'));

      final diff = prev.diff(next);
      expect(diff, isEmpty);
    });

    test('diff single width', () {
      final prev = Buffer.fromStringLines([
        '          ',
        '┌Title─┐  ',
        '│      │  ',
        '│      │  ',
        '└──────┘  ',
      ]);
      final next = Buffer.fromStringLines([
        '          ',
        '┌TITLE─┐  ',
        '│      │  ',
        '│      │  ',
        '└──────┘  ',
      ]);
      final diff = prev.diff(next);

      expect(diff, [
        (x: 2, y: 1, cell: const Cell(char: 'I')),
        (x: 3, y: 1, cell: const Cell(char: 'T')),
        (x: 4, y: 1, cell: const Cell(char: 'L')),
        (x: 5, y: 1, cell: const Cell(char: 'E')),
      ]);
    });

    test('diff multi width', () {
      final prev = Buffer.fromStringLines([
        '┌Title─┐  ',
        '└──────┘  ',
      ]);
      final next = Buffer.fromStringLines([
        '┌称号──┐  ',
        '└──────┘  ',
      ]);
      final diff = prev.diff(next);

      expect(diff, [
        (x: 1, y: 0, cell: const Cell(char: '称')),
        (x: 3, y: 0, cell: const Cell(char: '号')),
        (x: 5, y: 0, cell: const Cell(char: '─')),
      ]);
    });

    test('multi with offset', () {
      final prev = Buffer.fromStringLines(['┌称号──┐  ']);
      final next = Buffer.fromStringLines(['┌─称号─┐  ']);

      final diff = prev.diff(next);

      expect(diff, [
        (x: 1, y: 0, cell: const Cell(char: '─')),
        (x: 2, y: 0, cell: const Cell(char: '称')),
        (x: 4, y: 0, cell: const Cell(char: '号')),
      ]);
    });

    test('diff skip', () {
      final prev = Buffer.fromStringLines(['123']);
      final next = Buffer.fromStringLines(['456']);

      next.buf[1] = next.buf[1].copyWith(skip: true);
      next.buf[2] = next.buf[2].copyWith(skip: true);

      final diff = prev.diff(next);
      expect(diff, [(x: 0, y: 0, cell: const Cell(char: '4'))]);
    });

    test('merge', () {
      final a1 = Buffer.filled(
        Rect.create(x: 0, y: 0, width: 2, height: 2),
        const Cell(char: '1'),
      );
      final a2 = Buffer.filled(
        Rect.create(x: 0, y: 2, width: 2, height: 2),
        const Cell(char: '2'),
      );
      a1.merge(a2);

      expect(a1.eq(Buffer.fromStringLines(['11', '11', '22', '22'])), isTrue);

      final a3 = Buffer.filled(
        Rect.create(x: 2, y: 2, width: 2, height: 2),
        const Cell(char: '1'),
      );
      final a4 = Buffer.filled(
        Rect.create(x: 0, y: 0, width: 2, height: 2),
        const Cell(char: '2'),
      );
      a3.merge(a4);

      expect(
        a3.eq(Buffer.fromStringLines(['22  ', '22  ', '  11', '  11'])),
        isTrue,
      );
    });

    test('merge with offset', () {
      final a1 = Buffer.filled(
        Rect.create(x: 3, y: 3, width: 2, height: 2),
        const Cell(char: '1'),
      );
      final a2 = Buffer.filled(
        Rect.create(x: 1, y: 1, width: 3, height: 4),
        const Cell(char: '2'),
      );
      a1.merge(a2);

      final expected = Buffer.fromStringLines([
        '222 ',
        '222 ',
        '2221',
        '2221',
      ])..area = Rect.create(x: 1, y: 1, width: 4, height: 4);
      expect(a1.eq(expected), isTrue);
    });

    test('merge skip', () {
      final a1 = Buffer.filled(
        Rect.create(x: 0, y: 0, width: 2, height: 2),
        const Cell(char: '1'),
      );
      final a2 = Buffer.filled(
        Rect.create(x: 0, y: 1, width: 2, height: 2),
        const Cell(char: '2', skip: true),
      );
      a1.merge(a2);

      var skipped = a1.buf.map((b) => b.skip).toList();
      expect(skipped, [false, false, true, true, true, true]);

      final a3 = Buffer.filled(
        Rect.create(x: 0, y: 0, width: 2, height: 2),
        const Cell(char: '1', skip: true),
      );
      final a4 = Buffer.filled(
        Rect.create(x: 0, y: 1, width: 2, height: 2),
        const Cell(char: '2'),
      );
      a3.merge(a4);
      skipped = a3.buf.map((b) => b.skip).toList();
      expect(skipped, [true, true, false, false, false, false]);
    });

    // TODO(nelson): review and remove or move to Line or Span
    // test('with lines accept into lines', () {
    //   final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 3, height: 2))
    //     ..setString(0, 0, 'foo', const Style(fg: Color.red))
    //     ..setString(0, 1, 'bar', const Style(fg: Color.blue));

    //   expect(
    //     buf.eq(
    //       Buffer.fromLines([
    //         Line.fromSpan(const Span(content: 'foo', style: Style(fg: Color.red))),
    //         Line.fromSpan(const Span(content: 'bar', style: Style(fg: Color.blue))),
    //       ]),
    //     ),
    //     isTrue,
    //   );
    // });

    // test('control sequence full', () {
    //   const text = 'I \x1b[0;36mwas\x1b[0m here!';
    //   final buffer = Buffer.filled(Rect.create(x: 0, y: 0, width: 25, height: 3), const Cell(char: 'x'))
    //     ..setString(1, 1, text, const Style());

    //   final expected = Buffer.fromStringLines([
    //     'xxxxxxxxxxxxxxxxxxxxxxxxx',
    //     'xI [0;36mwas[0m here!xxxx',
    //     'xxxxxxxxxxxxxxxxxxxxxxxxx',
    //   ]);
    //   expect(buffer.eq(expected), isTrue);
    // });

    // test('control sequence partial', () {
    //   const text = 'I \x1b[0;36mwas\x1b[0m here!';
    //   final buffer = Buffer.filled(Rect.create(x: 0, y: 0, width: 11, height: 3), const Cell(char: 'x'))
    //     ..setString(1, 1, text, const Style());

    //   final expected = Buffer.fromStringLines([
    //     'xxxxxxxxxxx',
    //     'xI [0;36mwa',
    //     'xxxxxxxxxxx',
    //   ]);
    //   expect(buffer.eq(expected), isTrue);
    // });

    // test('render emoji', () {
    //   final buffer = Buffer.filled(Rect.create(x: 0, y: 0, width: 7, height: 1), const Cell(char: 'x'))
    //     // Shrug without gender or skin tone. Has a width of 2 like all emojis ha
    //     ..setString(0, 0, '🤷', const Style());
    //   expect(buffer.eq(Buffer.fromStringLines(['🤷xxxxx'])), isTrue);

    //   // Technically this is a (brown) bear, a zero-width joiner and a snowflake
    //   // As it is joined its a single emoji and should therefore have a width of 2.
    //   buffer.setString(0, 0, '🐻‍❄️', const Style());
    //   expect(buffer.eq(Buffer.fromStringLines(['🐻‍❄️xxxxx'])), isTrue);

    //   // Technically this is an eye, a zero-width joiner and a speech bubble
    //   // Both eye and speech bubble include a 'display as emoji' variation selector
    //   // TODO(nelson): unicode is calculating this emoji as 1 char wide
    //   buffer.setString(0, 0, '👁️‍🗨️', const Style());
    //   expect(buffer.eq(Buffer.fromStringLines(['👁️‍🗨️xxxxx'])), isTrue);

    //   buffer.setString(0, 0, 'a', const Style());
    //   expect(buffer.eq(Buffer.fromStringLines(['a xxxxx'])), isTrue);
    // });
  });

  test('index_pos_of_u16_max', () {
    final buffer = Buffer.empty(
      Rect.create(x: 0, y: 0, width: 256, height: 256 + 1),
    );
    expect(buffer.indexOf(255, 255), 65535);
    expect(buffer.posOf(65535), (x: 255, y: 255));

    expect(buffer.indexOf(0, 256), 65536);
    expect(buffer.posOf(65536), (x: 0, y: 256)); // previously (0, 0)

    expect(buffer.indexOf(1, 256), 65537);
    expect(buffer.posOf(65537), (x: 1, y: 256)); // previously (1, 0)

    expect(buffer.indexOf(255, 256), 65791);
    expect(buffer.posOf(65791), (x: 255, y: 256)); // previously (255, 0)
  });

  test('resize buffer', () {
    final rect = Rect.create(x: 0, y: 0, width: 3, height: 1);
    final buf = Buffer.filled(rect, const Cell(char: 'x'));
    expect(buf.buf.length, rect.area);

    final newRect = Rect.create(x: 0, y: 0, width: 3, height: 1);
    buf.resize(newRect);
    expect(buf.buf.length, newRect.area);
  });

  test('reset', () {
    final rect = Rect.create(x: 0, y: 0, width: 3, height: 1);
    final buffer = Buffer.empty(rect)..setStyle(rect, const Style(fg: Color.red, bg: Color.blue));

    expect(buffer.debug(), '''
Buffer {
    area: Rect(0x0+3+1),
    content: [
        "   ",
    ],
    styles: [
        x: 0, y: 0, fg: Color(1, ansi), bg: Color(4, ansi), underline: Color(Reset), modifier: Modifier(NONE)
    ]
}''');

    buffer.reset();

    expect(buffer.debug(), '''
Buffer {
    area: Rect(0x0+3+1),
    content: [
        "   ",
    ],
    styles: [
        x: 0, y: 0, fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE)
    ]
}''');
  });

  test('cell position', () {
    final buf = Buffer.fromStringLines(['abc', 'def']);

    expect(buf.index(Position.origin), buf.buf[0]);
    expect(buf.index(const Position(2, 1)), buf.buf[5]);
  });

  group('wide char overwrite regression', () {
    // These tests verify fix for bug where wide char overflow cells (skip=true)
    // weren't properly cleared when overwritten, causing ghost artifacts.

    test('overwrite wide char with narrow char clears skip', () {
      // Simulate: render wide char '称' (width 2), then overwrite with 'ab'
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1));

      // Write wide char at position 0 (occupies cells 0 and 1)
      buf[(x: 0, y: 0)] = const Cell(char: '称');
      // Cell 1 should be marked as skip by buffer's []= operator
      expect(buf[(x: 1, y: 0)].skip, false,
          reason: 'Buffer []= should clear skip on overflow cells');

      // Now overwrite with narrow chars using setCell (as Span.render does)
      buf[(x: 0, y: 0)] = buf[(x: 0, y: 0)].setCell(char: 'a');
      buf[(x: 1, y: 0)] = buf[(x: 1, y: 0)].setCell(char: 'b');

      expect(buf[(x: 0, y: 0)].symbol, 'a');
      expect(buf[(x: 0, y: 0)].skip, false);
      expect(buf[(x: 1, y: 0)].symbol, 'b');
      expect(buf[(x: 1, y: 0)].skip, false,
          reason: 'Overwritten skip cell must have skip=false');
    });

    test('diff includes cells after wide char overwrite', () {
      // This is the actual bug scenario: wide char rendered, then cleared,
      // but diff skips the overflow cell because skip flag wasn't cleared.
      final prev = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1));
      final next = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1));

      // Previous frame: wide char at position 0
      prev[(x: 0, y: 0)] = const Cell(char: '称');

      // Next frame: overwrite with narrow chars (simulating clear + redraw)
      // First, simulate what happens when a skip cell is overwritten
      next.buf[0] = const Cell(char: 'a');
      next.buf[1] = const Cell(char: ' ', skip: true).setCell(char: 'b');
      next.buf[2] = const Cell(char: 'c');
      next.buf[3] = const Cell(char: 'd');

      final diff = prev.diff(next).toList();

      // All 4 cells should be in diff (they all changed)
      expect(diff.length, 4,
          reason: 'All cells should appear in diff, including former skip cell');
      expect(diff.map((d) => d.cell.symbol), ['a', 'b', 'c', 'd']);
    });

    test('Span render wide then narrow includes all cells in diff', () {
      // Full integration: use Span to render wide char, then narrow chars
      final area = Rect.create(x: 0, y: 0, width: 6, height: 1);
      final prev = Buffer.empty(area);
      final next = Buffer.empty(area);

      // Render wide char '📁' (width 2) to prev buffer
      final frame1 = Frame(area, prev, 0);
      const Span('📁test').render(area, frame1);

      // Render narrow chars to next buffer (simulating redraw)
      final frame2 = Frame(area, next, 0);
      const Span('abcdef').render(area, frame2);

      final diff = prev.diff(next).toList();

      // All 6 positions should be updated
      expect(diff.length, 6,
          reason: 'All cells must be in diff after wide→narrow transition');

      // Verify no skip flags remain
      for (var i = 0; i < 6; i++) {
        expect(next.buf[i].skip, false,
            reason: 'Cell $i should not have skip flag');
      }
    });

    test('repeated wide/narrow cycles maintain correct state', () {
      final area = Rect.create(x: 0, y: 0, width: 4, height: 1);

      // Cycle 1: narrow
      var buf = Buffer.empty(area);
      var frame = Frame(area, buf, 0);
      const Span('abcd').render(area, frame);
      for (var i = 0; i < 4; i++) {
        expect(buf.buf[i].skip, false, reason: 'Cycle 1: cell $i skip');
      }

      // Cycle 2: wide char
      buf = Buffer.empty(area);
      frame = Frame(area, buf, 0);
      const Span('称号').render(area, frame); // Two width-2 chars
      expect(buf.buf[0].skip, false);
      expect(buf.buf[1].skip, true, reason: 'Wide char overflow');
      expect(buf.buf[2].skip, false);
      expect(buf.buf[3].skip, true, reason: 'Wide char overflow');

      // Cycle 3: back to narrow - this is where bug manifested
      final prevBuf = buf;
      buf = Buffer.empty(area);
      frame = Frame(area, buf, 0);
      const Span('wxyz').render(area, frame);

      // All cells should be in diff
      final diff = prevBuf.diff(buf).toList();
      expect(diff.length, 4,
          reason: 'All 4 cells must appear in diff after wide→narrow');

      // No skip flags
      for (var i = 0; i < 4; i++) {
        expect(buf.buf[i].skip, false,
            reason: 'Cycle 3: cell $i must not have skip flag');
      }
    });

    test('wide char sets correct skip flags', () {
      // When rendering wide char: main cell skip=false, overflow cell skip=true
      final area = Rect.create(x: 0, y: 0, width: 4, height: 1);
      final buf = Buffer.empty(area);
      final frame = Frame(area, buf, 0);

      const Span('称ab').render(area, frame); // wide char + 2 narrow

      // Wide char at 0: skip=false (must appear in diff)
      expect(buf.buf[0].symbol, '称');
      expect(buf.buf[0].skip, false,
          reason: 'Wide char main cell must have skip=false');

      // Overflow at 1: skip=true (placeholder, not in diff)
      expect(buf.buf[1].skip, true,
          reason: 'Wide char overflow cell must have skip=true');

      // Narrow chars: skip=false
      expect(buf.buf[2].symbol, 'a');
      expect(buf.buf[2].skip, false);
      expect(buf.buf[3].symbol, 'b');
      expect(buf.buf[3].skip, false);
    });

    test('overwrite skip cell with wide char sets correct flags', () {
      // Scenario: existing wide char, then overwrite starting at overflow cell
      // with another wide char
      final area = Rect.create(x: 0, y: 0, width: 6, height: 1);
      final buf = Buffer.empty(area);
      final frame = Frame(area, buf, 0);

      // First render: '称号xy' - two wide chars + two narrow
      const Span('称号xy').render(area, frame);
      expect(buf.buf[0].skip, false); // 称
      expect(buf.buf[1].skip, true);  // overflow
      expect(buf.buf[2].skip, false); // 号
      expect(buf.buf[3].skip, true);  // overflow
      expect(buf.buf[4].skip, false); // x
      expect(buf.buf[5].skip, false); // y

      // Now overwrite with narrow→wide→narrow: 'a称bc'
      // This overwrites position 1 (was skip=true) with part of content
      const Span('a称bc').render(area, frame);

      expect(buf.buf[0].symbol, 'a');
      expect(buf.buf[0].skip, false, reason: 'Narrow char must have skip=false');

      expect(buf.buf[1].symbol, '称');
      expect(buf.buf[1].skip, false,
          reason: 'Wide char on former skip cell must have skip=false');

      expect(buf.buf[2].skip, true,
          reason: 'Wide char overflow must have skip=true');

      expect(buf.buf[3].symbol, 'b');
      expect(buf.buf[3].skip, false);

      expect(buf.buf[4].symbol, 'c');
      expect(buf.buf[4].skip, false);
    });

    test('narrow to wide char transition in diff', () {
      // Verify diff correctly includes wide char and excludes its overflow
      final area = Rect.create(x: 0, y: 0, width: 4, height: 1);
      final prev = Buffer.empty(area);
      final next = Buffer.empty(area);

      // Previous: narrow chars
      var frame = Frame(area, prev, 0);
      const Span('abcd').render(area, frame);

      // Next: wide chars
      frame = Frame(area, next, 0);
      const Span('称号').render(area, frame);

      final diff = prev.diff(next).toList();

      // Should have 2 cells in diff (the two wide chars, not their overflows)
      expect(diff.length, 2,
          reason: 'Diff should include wide chars but not overflow cells');
      expect(diff[0].x, 0);
      expect(diff[0].cell.symbol, '称');
      expect(diff[1].x, 2);
      expect(diff[1].cell.symbol, '号');
    });
  });
}
