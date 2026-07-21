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
