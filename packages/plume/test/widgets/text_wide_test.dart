import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/fake_wide_measurer.dart';

// The narrow half of Text's coverage lives in text_test.dart with a
// MonospaceMeasurer. This is the wide half: the same wrap, hard-break, clip,
// ellipsis and alignment paths driven through a measurer that reports width 2
// for CJK glyphs, so anything that assumes one cell per cluster shows up. The
// glyph used throughout is 字 (width 2).
const _context = LayoutContext(measurer: FakeWideMeasurer());

List<String> _paint(Text<String> text, BoxConstraints constraints) {
  final surface = RecordingSurface<String>();
  text
    ..layout(constraints, _context)
    ..place(Offset.zero)
    ..paint(surface);
  return surface.intents.map((intent) => '$intent').toList();
}

Size _size(Text<String> text, BoxConstraints constraints) => text.layout(constraints, _context);

void main() {
  group('Text wide layout', () {
    test('a wide run measures two cells per glyph', () {
      final size = _size(Text<String>([const TextRun('字字', 'x')]), const BoxConstraints(maxW: 100, maxH: 10));
      expect(size, const Size(4, 1));
    });

    test('a width-2 glyph too big for the box is still emitted as one line', () {
      // Hard-break can't split a single glyph, so a width-2 字 in a width-1 box
      // becomes a one-glyph line that overflows rather than vanishing or looping.
      final size = _size(
        Text<String>([const TextRun('字', 'x')], softWrap: true),
        const BoxConstraints(maxW: 1, maxH: 100),
      );
      expect(size, const Size(1, 1));
    });
  });

  group('Text wide soft-wrap', () {
    test('wraps when a wide word will not fit the trailing space', () {
      final intents = _paint(
        Text<String>([const TextRun('字a 字a', 'x')], softWrap: true),
        const BoxConstraints(maxW: 4, maxH: 100),
      );
      expect(intents, [
        'drawText(0, 0, "字a", x)',
        'drawText(0, 1, "字a", x)',
      ]);
    });

    test('a wide glyph will not squeeze into a single free trailing cell', () {
      // 'a' fills one of two cells; the width-2 字 needs both, so it wraps
      // rather than half-occupying the last cell.
      final intents = _paint(
        Text<String>([const TextRun('a 字', 'x')], softWrap: true),
        const BoxConstraints(maxW: 2, maxH: 100),
      );
      expect(intents, [
        'drawText(0, 0, "a", x)',
        'drawText(0, 1, "字", x)',
      ]);
    });
  });

  group('Text wide hard-break', () {
    test('breaks a wide word one glyph per line when two will not fit', () {
      // Two glyphs are width 4 but the box is 3, so each line carries one 字 and
      // leaves its last cell blank.
      final intents = _paint(
        Text<String>([const TextRun('字字字', 'x')], softWrap: true),
        const BoxConstraints(maxW: 3, maxH: 100),
      );
      expect(intents, [
        'drawText(0, 0, "字", x)',
        'drawText(0, 1, "字", x)',
        'drawText(0, 2, "字", x)',
      ]);
    });

    test('packs whole wide glyphs into each line up to the width', () {
      // A width-4 box holds two glyphs on the first line; the odd one wraps.
      final intents = _paint(
        Text<String>([const TextRun('字字字', 'x')], softWrap: true),
        const BoxConstraints(maxW: 4, maxH: 100),
      );
      expect(intents, [
        'drawText(0, 0, "字字", x)',
        'drawText(0, 1, "字", x)',
      ]);
    });

    test('drops a width-2 glyph that overflows a width-1 box under clip', () {
      final intents = _paint(
        Text<String>([const TextRun('字', 'x')], softWrap: true),
        const BoxConstraints(maxW: 1, maxH: 100),
      );
      expect(intents, isEmpty);
    });
  });

  group('Text wide overflow', () {
    test('clip drops a wide glyph straddling the edge, leaving a blank cell', () {
      // The second 字 would sit in columns 2-3 but column 3 is outside the
      // width-3 box, so it is dropped and column 2 stays blank.
      final intents = _paint(
        Text<String>([const TextRun('字字', 'x')]),
        BoxConstraints.tight(const Size(3, 1)),
      );
      expect(intents, ['drawText(0, 0, "字", x)']);
    });

    test('ellipsis stops before a straddling wide glyph, leaving a blank cell', () {
      // One 字 (width 2) plus the ellipsis (width 1) fills 3 of the 4 cells; a
      // second 字 would not fit, so column 3 stays blank.
      final intents = _paint(
        Text<String>([const TextRun('字字字', 'x')], overflow: TextOverflow.ellipsis),
        BoxConstraints.tight(const Size(4, 1)),
      );
      expect(intents, ['drawText(0, 0, "字…", x)']);
    });
  });

  group('Text wide alignment', () {
    test('centers a wide line with an even remainder', () {
      final intents = _paint(
        Text<String>([const TextRun('字', 'x')], align: TextAlign.center),
        BoxConstraints.tight(const Size(6, 1)),
      );
      expect(intents, ['drawText(2, 0, "字", x)']);
    });

    test('centers a wide line with an odd remainder, flooring the shift', () {
      // 7 cells, a width-4 line: the 3-cell remainder floors to a 1-cell shift.
      final intents = _paint(
        Text<String>([const TextRun('字字', 'x')], align: TextAlign.center),
        BoxConstraints.tight(const Size(7, 1)),
      );
      expect(intents, ['drawText(1, 0, "字字", x)']);
    });

    test('end-aligns a wide line against the right edge', () {
      final intents = _paint(
        Text<String>([const TextRun('字字', 'x')], align: TextAlign.end),
        BoxConstraints.tight(const Size(7, 1)),
      );
      expect(intents, ['drawText(3, 0, "字字", x)']);
    });
  });
}
