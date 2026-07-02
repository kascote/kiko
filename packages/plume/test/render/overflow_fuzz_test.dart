import 'dart:math';

import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/adversarial_measurer.dart';
import '../support/fake_wide_measurer.dart';
import '../support/golden.dart';
import '../support/stress.dart';

// The overflow suite's example goldens (clip_test.dart) pin a handful of curated
// trees. This turns the same noOverflow invariant — every draw stays inside the
// frame the root pushed — loose on hundreds of randomly generated trees, across
// every measurer, so a clip escape that no hand-written fixture happens to hit
// still gets caught. Seeds are fixed, so a failure reproduces exactly.

const _measurers = <TextMeasurer>[
  MonospaceMeasurer(),
  FakeWideMeasurer(),
  WideIndicatorMeasurer(),
  ZeroWidthMeasurer(),
  OversizeGlyphMeasurer('#'),
];

void main() {
  group('random tree overflow fuzz', () {
    test('no draw escapes the frame, for any tree or measurer', () {
      final rng = Random(11);
      for (var iter = 0; iter < 800; iter++) {
        final tree = randomTree(rng);
        final measurer = _measurers[rng.nextInt(_measurers.length)];
        final frame = Rect(0, 0, 1 + rng.nextInt(20), 1 + rng.nextInt(12));
        final surface = RecordingSurface<String>();
        renderFrame(tree, frame, surface, measurer: measurer);
        // Throws (naming the offending intent) if any draw paints outside frame.
        noOverflow(surface.intents, frame, measurer: measurer);
      }
    });

    // Nodes carry mutable layout state, so relaying out the same tree must land
    // byte-identical intents — a hidden dependence on stale state would show here.
    test('re-rendering the same tree is deterministic', () {
      final rng = Random(13);
      for (var iter = 0; iter < 300; iter++) {
        final tree = randomTree(rng);
        final measurer = _measurers[rng.nextInt(_measurers.length)];
        final frame = Rect(0, 0, 1 + rng.nextInt(20), 1 + rng.nextInt(12));
        final first = RecordingSurface<String>();
        final second = RecordingSurface<String>();
        renderFrame(tree, frame, first, measurer: measurer);
        renderFrame(tree, frame, second, measurer: measurer);
        expect(
          second.intents.map((intent) => '$intent').toList(),
          first.intents.map((intent) => '$intent').toList(),
          reason: 'iter $iter',
        );
      }
    });
  });
}
