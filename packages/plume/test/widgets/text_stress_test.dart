import 'dart:math';

import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/adversarial_measurer.dart';
import '../support/fake_wide_measurer.dart';
import '../support/golden.dart';
import '../support/stress.dart';

// Text stressed with adversarial (but additive) measurers: an ellipsis
// indicator wider than one cell, zero-width clusters, and a glyph wider than the
// box. The targeted cases pin the behaviour at the seams; the fuzz asserts the
// standing invariant — a laid-out Text never paints outside its box — over many
// random inputs and every measurer.

/// Renders [text] as a frame root of [w] by [h] cells and returns the intents,
/// stringified for comparison.
List<String> _paint(Text<String> text, int w, int h, TextMeasurer measurer) {
  final surface = RecordingSurface<String>();
  renderFrame(text, Rect(0, 0, w, h), surface, measurer: measurer);
  return surface.intents.map((intent) => '$intent').toList();
}

/// The natural size [text] reports under a loose [w] by [h] box.
Size _size(Text<String> text, int w, int h, TextMeasurer measurer) =>
    text.layout(BoxConstraints(maxW: w, maxH: h), LayoutContext(measurer: measurer));

void main() {
  group('Text with a multi-cell ellipsis indicator', () {
    const measurer = WideIndicatorMeasurer(); // '…' measures three cells.

    test('reserves the full indicator width, not one cell', () {
      // budget = 4 - 3 leaves room for a single glyph before the width-3 '…'.
      final intents = _paint(
        Text<String>([const TextRun('abcde', 'x')], overflow: TextOverflow.ellipsis),
        4,
        1,
        measurer,
      );
      expect(intents, ['drawText(0, 0, "a…", x)']);
    });

    test('drops the indicator when the box is narrower than it', () {
      // The width-3 indicator cannot fit a width-2 box, so nothing is painted
      // rather than an indicator spilling past the edge.
      final intents = _paint(
        Text<String>([const TextRun('abc', 'x')], overflow: TextOverflow.ellipsis),
        2,
        1,
        measurer,
      );
      expect(intents, isEmpty);
    });
  });

  group('Text with zero-width clusters', () {
    const measurer = ZeroWidthMeasurer();

    test('a zero-width space adds no cells to the run', () {
      final intents = _paint(
        Text<String>([const TextRun('a​​b', 'x')], softWrap: true),
        2,
        1,
        measurer,
      );
      // Both zero-width spaces ride inside the two-cell box alongside 'a' and 'b'.
      expect(intents, ['drawText(0, 0, "a​​b", x)']);
    });

    test('a line of only zero-width clusters measures zero cells wide', () {
      final size = _size(Text<String>([const TextRun('​​', 'x')]), 5, 5, measurer);
      expect(size, const Size(0, 1));
    });
  });

  group('Text with a glyph wider than the box', () {
    const measurer = OversizeGlyphMeasurer('#'); // '#' measures five cells.

    test('clip drops a glyph too wide to ever fit, leaving the box blank', () {
      final intents = _paint(
        Text<String>([const TextRun('##', 'x')], softWrap: true),
        3,
        3,
        measurer,
      );
      expect(intents, isEmpty);
    });

    test('ellipsis still shows the indicator when no glyph fits', () {
      final intents = _paint(
        Text<String>([const TextRun('##', 'x')], overflow: TextOverflow.ellipsis),
        3,
        1,
        measurer,
      );
      expect(intents, ['drawText(0, 0, "…", x)']);
    });
  });

  group('Text trusts the measurer and does not cross-check it', () {
    // plume lays out on the per-cluster widths the measurer reports and never
    // re-measures a whole run to second-guess them. So a self-inconsistent
    // measurer — one whose per-cluster widths do not sum to its whole-string
    // width — is a bug in the measurer, not in plume, and its inconsistency
    // simply surfaces downstream. This test pins that contract: given a measurer
    // that reports 1 per 'a' but 5 for "aaaa", Text faithfully keeps all four
    // (1+1+1+1 = 4 fits the box) and emits them as-is, without trying to defend
    // against the contradiction. (A correct measurer is additive, so this can
    // never happen with one.)
    test('lays out on the reported cluster widths as-is', () {
      const measurer = NonAdditiveMeasurer();
      final surface = RecordingSurface<String>();
      renderFrame(Text<String>([const TextRun('aaaa', 'x')]), const Rect(0, 0, 4, 1), surface, measurer: measurer);
      // All four clusters kept (each reported one cell), emitted verbatim.
      expect(surface.intents.map((intent) => '$intent').toList(), ['drawText(0, 0, "aaaa", x)']);
      // The measurer's own contradiction (whole "aaaa" = 5) is not plume's to
      // catch; measured against its whole-string width the run reads as escaping.
      expect(
        () => noOverflow(surface.intents, const Rect(0, 0, 4, 1), measurer: measurer),
        throwsStateError,
      );
    });
  });

  group('Text paint stays inside its box (invariant fuzz)', () {
    const measurers = <TextMeasurer>[
      MonospaceMeasurer(),
      FakeWideMeasurer(),
      WideIndicatorMeasurer(),
      ZeroWidthMeasurer(),
      OversizeGlyphMeasurer('#'),
    ];

    test('a laid-out Text never paints outside its frame, under any measurer', () {
      final rng = Random(7);
      for (var iter = 0; iter < 800; iter++) {
        final measurer = measurers[rng.nextInt(measurers.length)];
        final text = randomText(rng);
        final w = 1 + rng.nextInt(12);
        final h = 1 + rng.nextInt(6);
        final frame = Rect(0, 0, w, h);
        final surface = RecordingSurface<String>();
        renderFrame(text, frame, surface, measurer: measurer);
        // Never overflows the frame it was laid tight into.
        noOverflow(surface.intents, frame, measurer: measurer);
        // Every painted run fits within the box width on its own row.
        for (final intent in surface.intents) {
          if (intent is TextIntent<String>) {
            expect(measurer.widthOf(intent.run), lessThanOrEqualTo(w), reason: 'iter $iter');
          }
        }
      }
    });
  });
}
