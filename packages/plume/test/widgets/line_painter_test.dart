import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/fake_wide_measurer.dart';

// paintRuns is the standalone line-painting entry point extracted from Text —
// what a caller with only a flat run list (no layout pass) uses to paint one
// row, kiko's viewports chief among them. These tests exercise it directly,
// without ever constructing a Text node.

const _mono = MonospaceMeasurer();
const _wide = FakeWideMeasurer();

List<String> _paint(
  List<TextRun<String>> runs, {
  required int width,
  TextMeasurer measurer = _mono,
  int x = 0,
  int y = 0,
  TextAlign align = TextAlign.start,
  TextOverflow overflow = TextOverflow.clip,
  int skipColumns = 0,
}) {
  final surface = RecordingSurface<String>();
  paintRuns(surface, runs, measurer, x: x, y: y, width: width, align: align, overflow: overflow, skipColumns: skipColumns);
  return surface.intents.map((intent) => '$intent').toList();
}

void main() {
  group('paintRuns without skip', () {
    test('paints a single run at the given origin', () {
      final intents = _paint([const TextRun('hello', 'x')], width: 10, x: 2, y: 3);
      expect(intents, ['drawText(2, 3, "hello", x)']);
    });

    test('splits adjacent runs by token', () {
      final intents = _paint([const TextRun('ab', 'red'), const TextRun('cd', 'blue')], width: 4);
      expect(intents, ['drawText(0, 0, "ab", red)', 'drawText(2, 0, "cd", blue)']);
    });

    test('aligns to center within the box width', () {
      final intents = _paint([const TextRun('hi', 'x')], width: 10, align: TextAlign.center);
      expect(intents, ['drawText(4, 0, "hi", x)']);
    });

    test('clips an overflowing line at the box edge', () {
      final intents = _paint([const TextRun('hello', 'x')], width: 3);
      expect(intents, ['drawText(0, 0, "hel", x)']);
    });
  });

  group('paintRuns with skipColumns', () {
    test('zero skip is a no-op', () {
      final intents = _paint([const TextRun('hello', 'x')], width: 10);
      expect(intents, ['drawText(0, 0, "hello", x)']);
    });

    test('drops whole leading clusters up to the skip width', () {
      final intents = _paint([const TextRun('hello', 'x')], width: 10, skipColumns: 2);
      expect(intents, ['drawText(0, 0, "llo", x)']);
    });

    test('skip spanning exactly one run boundary lands cleanly on the next run', () {
      final intents = _paint(
        [const TextRun('ab', 'red'), const TextRun('cd', 'blue')],
        width: 10,
        skipColumns: 2,
      );
      expect(intents, ['drawText(0, 0, "cd", blue)']);
    });

    test("skip into the middle of a run keeps that run's token for the tail", () {
      final intents = _paint(
        [const TextRun('ab', 'red'), const TextRun('cd', 'blue')],
        width: 10,
        skipColumns: 3,
      );
      expect(intents, ['drawText(0, 0, "d", blue)']);
    });

    test('skipping everything paints nothing', () {
      final intents = _paint([const TextRun('hi', 'x')], width: 10, skipColumns: 5);
      expect(intents, isEmpty);
    });

    test('skip composes with a right-edge clip (horizontal scroll window)', () {
      final intents = _paint([const TextRun('0123456789', 'x')], width: 3, skipColumns: 4);
      expect(intents, ['drawText(0, 0, "456", x)']);
    });

    test('a wide grapheme straddling the skip edge is dropped whole, leaving a blank gap', () {
      // '字' (width 2) sits at columns 0-1; skipColumns=1 straddles it, so it
      // is dropped entirely and the surviving 'a' starts one column in (the
      // gap left by the half-consumed glyph), not at column 0.
      final intents = _paint([const TextRun('字a', 'x')], width: 10, measurer: _wide, skipColumns: 1);
      expect(intents, ['drawText(1, 0, "a", x)']);
    });

    test('a wide grapheme exactly at the skip boundary survives whole', () {
      final intents = _paint([const TextRun('字a', 'x')], width: 10, measurer: _wide, skipColumns: 2);
      expect(intents, ['drawText(0, 0, "a", x)']);
    });

    test('skip then clip both straddle wide graphemes, leaving blank gaps on both edges', () {
      // '字字字字' is four width-2 glyphs at content columns 0-1, 2-3, 4-5,
      // 6-7. skipColumns=3 opens a window at content column 3: the second
      // glyph (2-3) straddles that edge and is dropped whole, leaving a
      // 1-column blank gap at window-local column 0. The third glyph (4-5)
      // lands fully in the window at window-local column 1. The window is
      // only 3 wide (width: 3), so the fourth glyph (6-7, window-local
      // column 3) falls outside it and is clipped away entirely.
      final intents = _paint([const TextRun('字字字字', 'x')], width: 3, measurer: _wide, skipColumns: 3);
      expect(intents, ['drawText(1, 0, "字", x)']);
    });
  });

  group('paintRuns respects the surface clip', () {
    test('trims to an active clip pushed before painting', () {
      final surface = RecordingSurface<String>()..pushClip(const Rect(0, 0, 3, 1));
      paintRuns(surface, [const TextRun('hello', 'x')], _mono, x: 0, y: 0, width: 10);
      surface.popClip();
      expect(surface.intents.map((intent) => '$intent').toList(), ['drawText(0, 0, "hel", x)']);
    });
  });
}
