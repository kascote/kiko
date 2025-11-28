import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Block', () {
    test('inner takes into account borders', () {
      final cases = [
        (borders: Borders.none, area: Rect.zero, expected: Rect.zero),
        (
          borders: Borders.none,
          area: Rect.create(x: 0, y: 0, width: 1, height: 1),
          expected: Rect.create(x: 0, y: 0, width: 1, height: 1),
        ),
        (borders: Borders.left, area: Rect.zero, expected: Rect.zero),
        (
          borders: Borders.left,
          area: Rect.create(x: 0, y: 0, width: 0, height: 1),
          expected: Rect.create(x: 0, y: 0, width: 0, height: 1),
        ),
        (
          borders: Borders.left,
          area: Rect.create(x: 0, y: 0, width: 1, height: 1),
          expected: Rect.create(x: 1, y: 0, width: 0, height: 1),
        ),
        (
          borders: Borders.left,
          area: Rect.create(x: 0, y: 0, width: 2, height: 1),
          expected: Rect.create(x: 1, y: 0, width: 1, height: 1),
        ),
        (borders: Borders.top, area: Rect.zero, expected: Rect.zero),
        (
          borders: Borders.top,
          area: Rect.create(x: 0, y: 0, width: 1, height: 0),
          expected: Rect.create(x: 0, y: 0, width: 1, height: 0),
        ),
        (
          borders: Borders.top,
          area: Rect.create(x: 0, y: 0, width: 1, height: 1),
          expected: Rect.create(x: 0, y: 1, width: 1, height: 0),
        ),
        (
          borders: Borders.top,
          area: Rect.create(x: 0, y: 0, width: 1, height: 2),
          expected: Rect.create(x: 0, y: 1, width: 1, height: 1),
        ),
        (borders: Borders.right, area: Rect.zero, expected: Rect.zero),
        (
          borders: Borders.right,
          area: Rect.create(x: 0, y: 0, width: 0, height: 1),
          expected: Rect.create(x: 0, y: 0, width: 0, height: 1),
        ),
        (
          borders: Borders.right,
          area: Rect.create(x: 0, y: 0, width: 1, height: 1),
          expected: Rect.create(x: 0, y: 0, width: 0, height: 1),
        ),
        (
          borders: Borders.right,
          area: Rect.create(x: 0, y: 0, width: 2, height: 1),
          expected: Rect.create(x: 0, y: 0, width: 1, height: 1),
        ),
        (borders: Borders.bottom, area: Rect.zero, expected: Rect.zero),
        (
          borders: Borders.bottom,
          area: Rect.create(x: 0, y: 0, width: 1, height: 0),
          expected: Rect.create(x: 0, y: 0, width: 1, height: 0),
        ),
        (
          borders: Borders.bottom,
          area: Rect.create(x: 0, y: 0, width: 1, height: 1),
          expected: Rect.create(x: 0, y: 0, width: 1, height: 0),
        ),
        (
          borders: Borders.bottom,
          area: Rect.create(x: 0, y: 0, width: 1, height: 2),
          expected: Rect.create(x: 0, y: 0, width: 1, height: 1),
        ),
        (borders: Borders.all, area: Rect.zero, expected: Rect.zero),
        (
          borders: Borders.all,
          area: Rect.create(x: 0, y: 0, width: 1, height: 1),
          expected: Rect.create(x: 1, y: 1, width: 0, height: 0),
        ),
        (
          borders: Borders.all,
          area: Rect.create(x: 0, y: 0, width: 2, height: 2),
          expected: Rect.create(x: 1, y: 1, width: 0, height: 0),
        ),
        (
          borders: Borders.all,
          area: Rect.create(x: 0, y: 0, width: 3, height: 3),
          expected: Rect.create(x: 1, y: 1, width: 1, height: 1),
        ),
      ];

      for (final kase in cases) {
        final block = Block(borders: kase.borders);
        expect(block.inner(kase.area), kase.expected);
      }
    });

    test('inner takes into account title', () {
      for (final align in Alignment.values) {
        final area = Rect.create(x: 0, y: 0, width: 0, height: 1);
        final expected = Rect.create(x: 0, y: 1, width: 0, height: 0);

        final block = const Block().titleTop(Line(content: 'Test', alignment: align));
        expect(block.inner(area), expected);
      }
    });

    test('takes into account border an title', () {
      final cases = [
        (
          block: const Block(borders: Borders.top).titleTop(Line(content: 'Test')),
          expected: Rect.create(x: 0, y: 1, width: 0, height: 1),
        ),
        (
          block: const Block(borders: Borders.bottom).titleTop(Line(content: 'Test')),
          expected: Rect.create(x: 0, y: 1, width: 0, height: 0),
        ),
        (
          block: const Block(borders: Borders.top).titleBottom(Line(content: 'Test')),
          expected: Rect.create(x: 0, y: 1, width: 0, height: 0),
        ),
        (
          block: const Block(borders: Borders.bottom).titleBottom(Line(content: 'Test')),
          expected: Rect.create(x: 0, y: 0, width: 0, height: 1),
        ),
      ];

      final area = Rect.create(x: 0, y: 0, width: 0, height: 2);
      for (final kase in cases) {
        expect(kase.block.inner(area), kase.expected);
      }
    });

    test(
      'has title at position takes into account all positioning declarations',
      () {
        var block = const Block();
        expect(block.hasTitleAtTop, false);
        expect(block.hasTitleAtBottom, false);

        block = const Block().titleTop(Line(content: 'Test'));
        expect(block.hasTitleAtTop, true);
        expect(block.hasTitleAtBottom, false);

        block = const Block().titleBottom(Line(content: 'Test'));
        expect(block.hasTitleAtTop, false);
        expect(block.hasTitleAtBottom, true);

        block = const Block().titleTop(Line(content: 'Test')).titleBottom(Line(content: 'Test'));
        expect(block.hasTitleAtTop, true);
        expect(block.hasTitleAtBottom, true);
      },
    );

    test('vertical space takes into account borders', () {
      final cases = [
        (borders: Borders.none, expected: (0, 0)),
        (borders: Borders.top, expected: (1, 0)),
        (borders: Borders.right, expected: (0, 0)),
        (borders: Borders.bottom, expected: (0, 1)),
        (borders: Borders.left, expected: (0, 0)),
        (borders: Borders.top | Borders.right, expected: (1, 0)),
        (borders: Borders.top | Borders.bottom, expected: (1, 1)),
        (borders: Borders.top | Borders.left, expected: (1, 0)),
        (borders: Borders.bottom | Borders.right, expected: (0, 1)),
        (borders: Borders.bottom | Borders.left, expected: (0, 1)),
        (borders: Borders.left | Borders.right, expected: (0, 0)),
      ];

      for (final kase in cases) {
        final block = Block(borders: kase.borders);
        expect(block.verticalSpace(), kase.expected);
      }
    });

    test('vertical space takes into account padding', () {
      final cases = [
        (border: Borders.top, pad: const Padding(top: 1), expected: (2, 0)),
        (border: Borders.right, pad: const Padding(top: 1), expected: (1, 0)),
        (border: Borders.bottom, pad: const Padding(top: 1), expected: (1, 1)),
        (border: Borders.left, pad: const Padding(top: 1), expected: (1, 0)),
        (
          border: Borders.top | Borders.bottom,
          pad: const Padding(top: 4, left: 100, bottom: 5, right: 100),
          expected: (5, 6),
        ),
        (
          border: Borders.none,
          pad: const Padding(top: 10, left: 100, bottom: 13, right: 100),
          expected: (10, 13),
        ),
        (
          border: Borders.all,
          pad: const Padding(top: 1, left: 100, bottom: 3, right: 100),
          expected: (2, 4),
        ),
      ];

      for (final kase in cases) {
        final block = Block(borders: kase.border, padding: kase.pad);
        expect(block.verticalSpace(), kase.expected);
      }
    });

    test('vertical space takes into account titles', () {
      final block = const Block().titleTop(Line(content: 'Test'));
      expect(block.verticalSpace(), (1, 0));

      final block2 = const Block().titleBottom(Line(content: 'Test'));
      expect(block2.verticalSpace(), (0, 1));
    });

    test('vertical space takes into account borders and title', () {
      final cases = [
        (borders: Borders.top, pos: TitlePosition.top, vs: (1, 0)),
        (borders: Borders.right, pos: TitlePosition.top, vs: (1, 0)),
        (borders: Borders.bottom, pos: TitlePosition.top, vs: (1, 1)),
        (borders: Borders.left, pos: TitlePosition.top, vs: (1, 0)),
        (borders: Borders.top, pos: TitlePosition.bottom, vs: (1, 1)),
        (borders: Borders.right, pos: TitlePosition.bottom, vs: (0, 1)),
        (borders: Borders.bottom, pos: TitlePosition.bottom, vs: (0, 1)),
        (borders: Borders.left, pos: TitlePosition.bottom, vs: (0, 1)),
      ];

      for (final kase in cases) {
        final block = Block(borders: kase.borders).title(Line(content: 'Test'), kase.pos);
        expect(block.verticalSpace(), kase.vs);
      }
    });

    test('horizontal space takes into account border', () {
      var block = const Block(borders: Borders.all);
      expect(block.horizontalSpace(), (1, 1));

      block = const Block(borders: Borders.left);
      expect(block.horizontalSpace(), (1, 0));

      block = const Block(borders: Borders.right);
      expect(block.horizontalSpace(), (0, 1));
    });

    test('horizontal space takes into_account padding', () {
      var block = const Block(
        padding: Padding(top: 100, left: 1, bottom: 100, right: 1),
      );
      expect(block.horizontalSpace(), (1, 1));

      block = const Block(padding: Padding(left: 3, right: 5));
      expect(block.horizontalSpace(), (3, 5));

      block = const Block(padding: Padding(top: 100, bottom: 100, right: 1));
      expect(block.horizontalSpace(), (0, 1));

      block = const Block(padding: Padding(top: 100, left: 1, bottom: 100));
      expect(block.horizontalSpace(), (1, 0));
    });
  });

  test('horizontal space takes into account borders and padding', () {
    final cases = [
      (
        borders: Borders.all,
        pad: const Padding(top: 1, left: 1, bottom: 1, right: 1),
        hs: (2, 2),
      ),
      (borders: Borders.all, pad: const Padding(left: 1), hs: (2, 1)),
      (borders: Borders.all, pad: const Padding(right: 1), hs: (1, 2)),
      (borders: Borders.all, pad: const Padding(top: 1), hs: (1, 1)),
      (borders: Borders.all, pad: const Padding(bottom: 1), hs: (1, 1)),
      (borders: Borders.left, pad: const Padding(left: 1), hs: (2, 0)),
      (borders: Borders.left, pad: const Padding(right: 1), hs: (1, 1)),
      (borders: Borders.right, pad: const Padding(right: 1), hs: (0, 2)),
      (borders: Borders.right, pad: const Padding(left: 1), hs: (1, 1)),
    ];

    for (final kase in cases) {
      final block = Block(borders: kase.borders, padding: kase.pad);
      expect(block.horizontalSpace(), kase.hs);
    }
  });

  test('title', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 11, height: 3));
    const Block(borders: Borders.all)
        .title(Line(content: 'A', alignment: Alignment.left), TitlePosition.top)
        .title(Line(content: 'B', alignment: Alignment.center), TitlePosition.top)
        .title(Line(content: 'C', alignment: Alignment.right), TitlePosition.top)
        .title(Line(content: 'D', alignment: Alignment.left), TitlePosition.bottom)
        .title(Line(content: 'E', alignment: Alignment.center), TitlePosition.bottom)
        .title(Line(content: 'F', alignment: Alignment.right), TitlePosition.bottom)
        .render(buffer.area, buffer);

    expect(
      buffer.eq(
        Buffer.fromStringLines([
          '┌A───B───C┐',
          '│         │',
          '└D───E───F┘',
        ]),
      ),
      isTrue,
    );
  });

  test('title top bottom', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 11, height: 3));
    const Block(borders: Borders.all)
        .titleTop(Line(content: 'A'))
        .titleTop(Line(content: 'B', alignment: Alignment.center))
        .titleTop(Line(content: 'C', alignment: Alignment.right))
        .titleBottom(Line(content: 'D', alignment: Alignment.left))
        .titleBottom(Line(content: 'E', alignment: Alignment.center))
        .titleBottom(Line(content: 'F', alignment: Alignment.right))
        .render(buffer.area, buffer);

    expect(
      buffer.eq(
        Buffer.fromStringLines([
          '┌A───B───C┐',
          '│         │',
          '└D───E───F┘',
        ]),
      ),
      isTrue,
    );
  });

  test('title alignment', () {
    final cases = [
      (alg: Alignment.left, test: 'test    '),
      (alg: Alignment.center, test: '  test  '),
      (alg: Alignment.right, test: '    test'),
    ];

    for (final kase in cases) {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 1));
      const Block().titleTop(Line(content: 'test', alignment: kase.alg)).render(buffer.area, buffer);
      expect(buffer.eq(Buffer.fromStringLines([kase.test])), isTrue);
    }
  });

  test('title content style', () {
    for (final align in Alignment.values) {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1));
      const Block()
          .title(
            Line(
              content: 'test',
              style: const Style(fg: Color.yellow),
              alignment: align,
            ),
            TitlePosition.top,
          )
          .render(buffer.area, buffer);
      expect(
        buffer.eq(
          Buffer.fromLines([
            Line(
              content: 'test',
              style: const Style(fg: Color.yellow),
            ),
          ]),
        ),
        isTrue,
      );
    }
  });

  test('border style', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    const Block(
      borders: Borders.all,
      borderStyle: Style(fg: Color.yellow),
    ).titleTop(Line(content: 'test')).render(buffer.area, buffer);

    final expected =
        Buffer.fromStringLines([
            '┌test────┐',
            '│        │',
            '└────────┘',
          ])
          ..setStyle(
            Rect.create(x: 0, y: 0, width: 10, height: 3),
            const Style(fg: Color.yellow),
          )
          ..setStyle(
            Rect.create(x: 1, y: 1, width: 8, height: 1),
            const Style(fg: Color.reset),
          );
    expect(buffer.eq(expected), isTrue);
  });

  test('render plain border', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    const Block(borders: Borders.all).render(buffer.area, buffer);

    final expected = Buffer.fromStringLines([
      '┌────────┐',
      '│        │',
      '└────────┘',
    ]);
    expect(buffer.eq(expected), isTrue);
  });

  test('render rounded border', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    const Block(
      borders: Borders.all,
      borderType: BorderType.rounded,
    ).render(buffer.area, buffer);

    final expected = Buffer.fromStringLines([
      '╭────────╮',
      '│        │',
      '╰────────╯',
    ]);
    expect(buffer.eq(expected), isTrue);
  });

  test('render double border', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    const Block(
      borders: Borders.all,
      borderType: BorderType.double,
    ).render(buffer.area, buffer);

    final expected = Buffer.fromStringLines([
      '╔════════╗',
      '║        ║',
      '╚════════╝',
    ]);
    expect(buffer.eq(expected), isTrue);
  });

  test('render quadrant inside ', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    const Block(
      borders: Borders.all,
      borderType: BorderType.quadrantInside,
    ).render(buffer.area, buffer);

    final expected = Buffer.fromStringLines([
      '▗▄▄▄▄▄▄▄▄▖',
      '▐        ▌',
      '▝▀▀▀▀▀▀▀▀▘',
    ]);
    expect(buffer.eq(expected), isTrue);
  });

  test('render quadrant outside ', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    const Block(
      borders: Borders.all,
      borderType: BorderType.quadrantOutside,
    ).render(buffer.area, buffer);

    final expected = Buffer.fromStringLines([
      '▛▀▀▀▀▀▀▀▀▜',
      '▌        ▐',
      '▙▄▄▄▄▄▄▄▄▟',
    ]);
    expect(buffer.eq(expected), isTrue);
  });

  test('render solid border', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    const Block(
      borders: Borders.all,
      borderType: BorderType.thick,
    ).render(buffer.area, buffer);

    final expected = Buffer.fromStringLines([
      '┏━━━━━━━━┓',
      '┃        ┃',
      '┗━━━━━━━━┛',
    ]);
    expect(buffer.eq(expected), isTrue);
  });

  test('throw error if set type custom but provide no definition', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
    expect(
      () => const Block(
        borders: Borders.all,
        borderType: BorderType.custom,
      ).render(buffer.area, buffer),
      throwsArgumentError,
    );
  });

  test('throw error if try to access a BorderType no defined', () {
    expect(
      () => BorderType.custom.symbols(BorderType.custom),
      throwsArgumentError,
    );
  });
}
