import 'dart:math';

import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// Asserts that [b]'s width sidecar is a faithful, independently recomputed
/// mirror of its content: same length as [Buffer.buf], and every entry equal
/// to `measurer.widthOf` of the cell symbol at that index.
///
/// This recomputes the invariant from the outside on purpose, rather than
/// calling into any of `Buffer`'s own bookkeeping, so it catches drift that
/// the library's internal checks might share a blind spot with.
void expectWidthsInSync(Buffer b) {
  expect(b.debugWidths.length, b.buf.length);
  for (var i = 0; i < b.buf.length; i++) {
    expect(
      b.debugWidths[i],
      b.measurer.widthOf(b.buf[i].symbol),
      reason: 'sidecar width mismatch at index $i',
    );
  }
}

void main() {
  group('Buffer width sidecar - construction', () {
    test('Buffer.empty starts in sync', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 3));
      expectWidthsInSync(buf);
    });

    test('Buffer.filled with a wide-symbol cell starts in sync', () {
      final buf = Buffer.filled(
        Rect.create(x: 0, y: 0, width: 4, height: 2),
        const Cell(char: '你'),
      );
      expectWidthsInSync(buf);
      expect(buf.debugWidths.every((w) => w == 2), isTrue);
    });

    test('Buffer.copyFrom of mixed-width content stays in sync, and mutating the copy leaves the original alone', () {
      final original = Buffer.fromStringLines(['你a好b', 'cdef']);
      expectWidthsInSync(original);

      final copy = Buffer.copyFrom(original);
      expectWidthsInSync(copy);

      final originalWidthsBefore = List<int>.from(original.debugWidths);

      copy[(x: 0, y: 1)] = const Cell(char: '好');
      expectWidthsInSync(copy);
      expectWidthsInSync(original);

      expect(original.debugWidths, originalWidthsBefore);
      expect(copy.debugWidths[copy.indexOf(0, 1)], 2);
    });
  });

  group('Buffer width sidecar - []= narrow and wide writes', () {
    test('narrow ASCII writes keep the sidecar in sync', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 2));
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 5; x++) {
          buf[(x: x, y: y)] = Cell(char: String.fromCharCode(97 + x));
        }
      }
      expectWidthsInSync(buf);
    });

    test('wide writes (CJK, emoji, flag cluster) keep the sidecar in sync', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 3));
      buf[(x: 0, y: 0)] = const Cell(char: '你');
      buf[(x: 0, y: 1)] = const Cell(char: '😀');
      buf[(x: 0, y: 2)] = const Cell(char: '🇦🇷');
      expectWidthsInSync(buf);

      expect(buf.debugWidths[buf.indexOf(0, 0)], 2);
      expect(buf.debugWidths[buf.indexOf(0, 1)], 2);
      expect(buf.debugWidths[buf.indexOf(0, 2)], 2);
    });

    // These four tests set up their wide glyph through `setCellAtPos`, a thin
    // `[]=` wrapper every real caller reaches the same way (`Buffer.fromLines`,
    // `Buffer.fromStringLines`). `[]=` marks the glyph's trailing cell
    // `skip: true` on its own — a bare `buf[pos] = Cell(char: wideGlyph)` does
    // the same, with no second call needed.
    test('writing a wide glyph sets skip and a sidecar entry of 1 on the trailing cell', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1))..setCellAtPos(x: 0, y: 0, char: '你');

      expect(buf[(x: 1, y: 0)].skip, isTrue);
      expect(buf.debugWidths[buf.indexOf(1, 0)], 1);
      expectWidthsInSync(buf);
    });

    test('overwriting a wide glyph with a narrow one clears the trailing skip flag', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1))..setCellAtPos(x: 0, y: 0, char: '你');
      expect(buf[(x: 1, y: 0)].skip, isTrue); // sanity: the setup really set it
      expectWidthsInSync(buf);

      buf[(x: 0, y: 0)] = const Cell(char: 'a');

      expect(buf[(x: 1, y: 0)].skip, isFalse);
      expect(buf.debugWidths[buf.indexOf(1, 0)], 1);
      expectWidthsInSync(buf);
    });

    test('overwriting the trailing cell of a wide glyph directly keeps the sidecar in sync', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1))..setCellAtPos(x: 0, y: 0, char: '你');
      expect(buf[(x: 1, y: 0)].skip, isTrue);
      expectWidthsInSync(buf);

      buf[(x: 1, y: 0)] = const Cell(char: 'Z');

      expect(buf[(x: 1, y: 0)].symbol, 'Z');
      expect(buf[(x: 1, y: 0)].skip, isFalse);
      expect(buf.debugWidths[buf.indexOf(1, 0)], 1);
      expectWidthsInSync(buf);
    });

    test('writing a wide glyph over another at an overlapping position keeps the sidecar in sync', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1))..setCellAtPos(x: 0, y: 0, char: '你');
      expectWidthsInSync(buf);

      buf.setCellAtPos(x: 1, y: 0, char: '好');
      expectWidthsInSync(buf);

      expect(buf[(x: 1, y: 0)].symbol, '好');
      expect(buf[(x: 2, y: 0)].skip, isTrue);
      expect(buf.debugWidths[buf.indexOf(2, 0)], 1);
    });

    test('the same position rewritten repeatedly narrow/wide/narrow keeps the sidecar in sync', () {
      final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1));
      const sequence = ['a', '你', 'b', '😀', 'c', '你', 'd'];

      for (final symbol in sequence) {
        buf[(x: 0, y: 0)] = Cell(char: symbol);
        expectWidthsInSync(buf);
      }
    });
  });

  test('setStyle over a region with wide glyphs leaves symbols and the sidecar unchanged', () {
    final buf = Buffer.fromStringLines(['你a好b', 'cdef']);
    expectWidthsInSync(buf);
    final before = List<int>.from(buf.debugWidths);

    buf.setStyle(buf.area, const Style(fg: Color.red));

    expectWidthsInSync(buf);
    expect(buf.debugWidths, before);
  });

  group('Buffer width sidecar - resize', () {
    test('resize growing the buffer reflects an emptied sidecar', () {
      final buf = Buffer.fromStringLines(['你好']);
      expectWidthsInSync(buf);

      buf.resize(Rect.create(x: 0, y: 0, width: 5, height: 2));

      expectWidthsInSync(buf);
      expect(buf.buf.every((c) => c.symbol == ' '), isTrue);
      expect(buf.debugWidths.every((w) => w == 1), isTrue);
    });

    test('resize shrinking the buffer reflects an emptied sidecar', () {
      final buf = Buffer.fromStringLines(['你好', 'abcd']);
      expectWidthsInSync(buf);

      buf.resize(Rect.create(x: 0, y: 0, width: 2, height: 1));

      expectWidthsInSync(buf);
      expect(buf.buf.length, 2);
      expect(buf.buf.every((c) => c.symbol == ' '), isTrue);
      expect(buf.debugWidths.every((w) => w == 1), isTrue);
    });
  });

  test('reset clears content and keeps the sidecar in sync', () {
    final buf = Buffer.fromStringLines(['你好', 'abcd'])
      ..setStyle(Rect.create(x: 0, y: 0, width: 4, height: 2), const Style(fg: Color.red));
    expectWidthsInSync(buf);

    buf.reset();

    expectWidthsInSync(buf);
    expect(buf.buf.every((c) => c.symbol == ' '), isTrue);
    expect(buf.debugWidths.every((w) => w == 1), isTrue);
  });

  group('Buffer width sidecar - blitFrom', () {
    test('plain blit replaces styled destination cells over rect, leaves cells outside it untouched', () {
      final dest = Buffer.filled(
        Rect.create(x: 0, y: 0, width: 6, height: 3),
        const Cell(char: 'd', fg: Color.red, bg: Color.blue),
      );
      final source = Buffer.filled(
        Rect.create(x: 1, y: 1, width: 3, height: 2),
        const Cell(char: 's', fg: Color.green, bg: Color.yellow, modifier: Modifier.bold),
      );
      final sourceBefore = List<Cell>.from(source.buf);

      dest.blitFrom(source, source.area);

      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 6; x++) {
          final cell = dest[(x: x, y: y)];
          if (source.area.contains(Position(x, y))) {
            expect(cell.symbol, 's');
            expect(cell.fg, Color.green);
            expect(cell.bg, Color.yellow);
            expect(cell.modifier, Modifier.bold);
          } else {
            expect(cell.symbol, 'd');
            expect(cell.fg, Color.red);
            expect(cell.bg, Color.blue);
          }
        }
      }
      expect(source.buf, sourceBefore, reason: 'blitFrom never mutates the source buffer');
      expectWidthsInSync(dest);
      expectWidthsInSync(source);
    });

    test('a destination wide glyph straddling the region left edge is healed to a styled blank', () {
      final dest = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1));
      dest[(x: 1, y: 0)] = const Cell(char: '你', fg: Color.magenta);
      expect(dest[(x: 2, y: 0)].skip, isTrue, reason: 'sanity: the trailing cell really lands at x=2');

      final source = Buffer.filled(
        Rect.create(x: 2, y: 0, width: 3, height: 1),
        const Cell(char: 's', fg: Color.cyan),
      );

      dest.blitFrom(source, source.area);

      // Orphaned head, healed to a styled blank keeping its own style.
      expect(dest[(x: 1, y: 0)].symbol, ' ');
      expect(dest[(x: 1, y: 0)].skip, isFalse);
      expect(dest[(x: 1, y: 0)].fg, Color.magenta);

      // The blitted region itself.
      for (var x = 2; x < 5; x++) {
        expect(dest[(x: x, y: 0)].symbol, 's');
        expect(dest[(x: x, y: 0)].fg, Color.cyan);
      }

      // Untouched beyond the region.
      expect(dest[(x: 0, y: 0)].symbol, ' ');
      expect(dest[(x: 5, y: 0)].symbol, ' ');

      expectWidthsInSync(dest);
      expectWidthsInSync(source);
    });

    test(
      'a destination wide glyph straddling the region right edge is healed automatically by the underlying []= write',
      () {
        final dest = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1));
        dest[(x: 3, y: 0)] = const Cell(char: 'z', fg: Color.red);
        dest[(x: 2, y: 0)] = const Cell(char: '你', fg: Color.magenta);
        expect(dest[(x: 3, y: 0)].skip, isTrue, reason: 'sanity: the wide write marked its trailing cell skip');
        expect(dest[(x: 3, y: 0)].fg, Color.red, reason: 'sanity: the trailing cell keeps the style it already had');

        final source = Buffer.filled(
          Rect.create(x: 0, y: 0, width: 3, height: 1),
          const Cell(char: 's', fg: Color.cyan),
        );

        dest.blitFrom(source, source.area);

        for (var x = 0; x < 3; x++) {
          expect(dest[(x: x, y: 0)].symbol, 's');
          expect(dest[(x: x, y: 0)].fg, Color.cyan);
        }

        // The old head's trailing cell, orphaned just outside the rect, is left
        // a non-skip styled blank: overwriting the head at x=2 clears the
        // stale skip on x=3, and the cell keeps the style it already had.
        expect(dest[(x: 3, y: 0)].symbol, ' ');
        expect(dest[(x: 3, y: 0)].skip, isFalse);
        expect(dest[(x: 3, y: 0)].fg, Color.red);

        expectWidthsInSync(dest);
        expectWidthsInSync(source);
      },
    );

    test('source wide glyphs fully inside the blit region arrive intact with correct skip marking', () {
      final source = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1))
        ..setCellAtPos(x: 0, y: 0, char: 'a')
        ..setCellAtPos(x: 1, y: 0, char: '你')
        ..setCellAtPos(x: 3, y: 0, char: '好')
        ..setCellAtPos(x: 5, y: 0, char: 'c');
      expectWidthsInSync(source);

      final dest = Buffer.filled(Rect.create(x: 0, y: 0, width: 6, height: 1), const Cell(char: 'x', fg: Color.red))
        ..blitFrom(source, source.area);

      expect(dest[(x: 0, y: 0)].symbol, 'a');
      expect(dest[(x: 1, y: 0)].symbol, '你');
      expect(dest[(x: 1, y: 0)].skip, isFalse);
      expect(dest[(x: 2, y: 0)].skip, isTrue);
      expect(dest[(x: 3, y: 0)].symbol, '好');
      expect(dest[(x: 3, y: 0)].skip, isFalse);
      expect(dest[(x: 4, y: 0)].skip, isTrue);
      expect(dest[(x: 5, y: 0)].symbol, 'c');
      expect(dest.debugWidths[dest.indexOf(1, 0)], 2);
      expect(dest.debugWidths[dest.indexOf(3, 0)], 2);

      expectWidthsInSync(dest);
      expectWidthsInSync(source);
    });

    test('a rect extending past this.area is clipped, no RangeError', () {
      final dest = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1));
      final source = Buffer.filled(
        Rect.create(x: 0, y: 0, width: 10, height: 1),
        const Cell(char: 's', fg: Color.green),
      );

      expect(() => dest.blitFrom(source, source.area), returnsNormally);

      for (var x = 0; x < 4; x++) {
        expect(dest[(x: x, y: 0)].symbol, 's');
        expect(dest[(x: x, y: 0)].fg, Color.green);
      }
      expect(dest.area, Rect.create(x: 0, y: 0, width: 4, height: 1));
      expect(dest.buf.length, 4);

      expectWidthsInSync(dest);
      expectWidthsInSync(source);
    });

    test('a source wide head at the clipped region right edge is written as a blank, no skip spill', () {
      final source = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1));
      source[(x: 4, y: 0)] = const Cell(char: '你', fg: Color.magenta);
      expect(source[(x: 5, y: 0)].skip, isTrue, reason: "sanity: the source's own wide write marked x=5 skip");

      final dest = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1));
      // Narrower than source.area, so the region's right edge falls right on
      // the wide head — clipping is due to rect, not to either buffer's area.
      final rect = Rect.create(x: 0, y: 0, width: 5, height: 1);

      dest.blitFrom(source, rect);

      expect(dest[(x: 4, y: 0)].symbol, ' ');
      expect(dest[(x: 4, y: 0)].skip, isFalse);
      expect(dest[(x: 4, y: 0)].fg, Color.magenta);
      expect(dest.debugWidths[dest.indexOf(4, 0)], 1);

      // Outside the region: untouched, and definitely not skip-marked from a
      // spilled glyph.
      expect(dest[(x: 5, y: 0)].symbol, ' ');
      expect(dest[(x: 5, y: 0)].skip, isFalse);

      expectWidthsInSync(dest);
      expectWidthsInSync(source);
    });

    test('an empty intersection is a no-op', () {
      final dest = Buffer.filled(Rect.create(x: 0, y: 0, width: 4, height: 4), const Cell(char: 'd', fg: Color.red));
      final source = Buffer.filled(
        Rect.create(x: 10, y: 10, width: 3, height: 3),
        const Cell(char: 's', fg: Color.green),
      );
      final before = List<Cell>.from(dest.buf);
      final widthsBefore = List<int>.from(dest.debugWidths);

      dest.blitFrom(source, source.area);

      expect(dest.buf, before);
      expect(dest.debugWidths, widthsBefore);
      expectWidthsInSync(dest);
    });
  });

  test('a seeded randomized mutation sequence keeps the sidecar in sync at every step', () {
    final rng = Random(42);
    const pool = [' ', 'a', 'Z', '你', '好', '😀', '⌚', '☂'];
    final buf = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 6));

    for (var iter = 0; iter < 300; iter++) {
      final op = rng.nextInt(100);

      if (op < 75) {
        // Write a random symbol from the pool at a random in-bounds position.
        // Stay one column shy of the right edge so a width-2 pick never
        // needs a trailing cell that doesn't exist.
        final x = buf.area.x + rng.nextInt(buf.area.width - 1);
        final y = buf.area.y + rng.nextInt(buf.area.height);
        final symbol = pool[rng.nextInt(pool.length)];
        buf[(x: x, y: y)] = Cell(char: symbol);
      } else if (op < 91) {
        // setStyle over a random small rect within the buffer.
        final w = 1 + rng.nextInt(buf.area.width);
        final h = 1 + rng.nextInt(buf.area.height);
        final x = buf.area.x + rng.nextInt(buf.area.width - w + 1);
        final y = buf.area.y + rng.nextInt(buf.area.height - h + 1);
        buf.setStyle(Rect.create(x: x, y: y, width: w, height: h), const Style(fg: Color.blue));
      } else if (op < 94) {
        // Reset (rare).
        buf.reset();
      } else {
        // Resize to a random nearby size (rare).
        final w = 4 + rng.nextInt(6);
        final h = 3 + rng.nextInt(5);
        buf.resize(Rect.create(x: 0, y: 0, width: w, height: h));
      }

      expectWidthsInSync(buf);
    }
  });
}
