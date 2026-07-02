/// A seeded random tree generator plus the [FillBox] leaf the stress and fuzz
/// suites paint with.
///
/// Everything here is deterministic given a seed, so a failing fuzz case is
/// reproducible. The generator is deliberately conservative: it only ever builds
/// trees that a tight, bounded root can lay out without tripping a debug assert
/// (it never marks a child flexible, and every stack keeps a non-positioned
/// child), so a failure means a real invariant break rather than a malformed
/// tree.
library;

import 'dart:math';

import 'package:plume/plume.dart';

/// A leaf that fills its whole rect, recording one [FillIntent].
///
/// Gives a generated tree visible, clip-checkable paint output without pulling in
/// a real widget's styling.
class FillBox<S> extends RenderNode<S> {
  /// Fills [style] into a box that wants to be [w] by [h] cells, clamped to the
  /// incoming constraints.
  FillBox(this.style, this.w, this.h);

  /// The opaque style token painted into the rect.
  final S style;

  /// The requested width in cells, before constraints.
  final int w;

  /// The requested height in cells, before constraints.
  final int h;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.constrain(Size(w, h));

  @override
  void paintSelf(Surface<S> surface) => surface.fillRect(rect, style);
}

/// Grapheme clusters mixed into generated [Text], each stressing a different
/// measurer: a normal letter, a space and newline (wrap and paragraph breaks), a
/// wide CJK glyph, the oversize sentinel `#`, a zero-width space, a
/// base-plus-combining cluster, and the ellipsis indicator itself.
const List<String> stressGlyphs = <String>['a', 'b', ' ', '\n', '字', '#', '​', 'é', '…'];

/// Builds a random [Text] node: one to three styled runs of [stressGlyphs] with
/// randomized wrap, overflow, alignment and line-cap settings.
Text<String> randomText(Random rng) {
  final runs = <TextRun<String>>[];
  final runCount = 1 + rng.nextInt(3);
  for (var r = 0; r < runCount; r++) {
    final len = rng.nextInt(7);
    final text = StringBuffer();
    for (var i = 0; i < len; i++) {
      text.write(stressGlyphs[rng.nextInt(stressGlyphs.length)]);
    }
    runs.add(TextRun<String>(text.toString(), 's$r'));
  }
  return Text<String>(
    runs,
    softWrap: rng.nextBool(),
    align: TextAlign.values[rng.nextInt(TextAlign.values.length)],
    overflow: TextOverflow.values[rng.nextInt(TextOverflow.values.length)],
    maxLines: rng.nextBool() ? null : 1 + rng.nextInt(3),
  );
}

/// Builds a random leaf: a [SizedBox], a [FillBox], or a [randomText].
RenderNode<String> randomLeaf(Random rng) {
  switch (rng.nextInt(3)) {
    case 0:
      return SizedBox<String>(width: rng.nextInt(9), height: rng.nextInt(9));
    case 1:
      return FillBox<String>('fill', rng.nextInt(9), rng.nextInt(9));
    default:
      return randomText(rng);
  }
}

/// Builds a random layout tree rooted at this call, at most [depth] containers
/// deep.
///
/// At depth zero, or with a small chance earlier, it returns a leaf; otherwise
/// it picks a container (single-child decoration, flex line, or stack) and
/// recurses. Every branch keeps the tree layout-safe under a bounded root.
RenderNode<String> randomTree(Random rng, {int depth = 3}) {
  if (depth <= 0 || rng.nextInt(100) < 25) {
    return randomLeaf(rng);
  }
  switch (rng.nextInt(6)) {
    case 0:
      return Container<String>(
        child: randomTree(rng, depth: depth - 1),
        padding: _randomInsets(rng),
        width: rng.nextBool() ? null : rng.nextInt(11),
        height: rng.nextBool() ? null : rng.nextInt(11),
        border: rng.nextBool() ? 'border' : null,
        background: rng.nextBool() ? 'bg' : null,
      );
    case 1:
      return Padding<String>(
        insets: _randomInsets(rng),
        child: randomTree(rng, depth: depth - 1),
      );
    case 2:
      return Align<String>(
        alignment: Alignment.values[rng.nextInt(Alignment.values.length)],
        child: randomTree(rng, depth: depth - 1),
      );
    case 3:
      return ConstrainedBox<String>(
        additionalConstraints: BoxConstraints(
          maxW: rng.nextBool() ? null : rng.nextInt(11),
          maxH: rng.nextBool() ? null : rng.nextInt(11),
        ),
        child: randomTree(rng, depth: depth - 1),
      );
    case 4:
      return _randomFlex(rng, depth);
    default:
      return _randomStack(rng, depth);
  }
}

// Children are inflexible. An inflexible flex child is measured with an
// unbounded main axis, and a flex with a *flexible* child under an unbounded main
// axis is a deliberate author error the engine asserts on — so generating one
// would fail the fuzz on a non-bug. Flexible distribution is covered by the
// property tests instead.
Flex<String> _randomFlex(Random rng, int depth) {
  final n = 1 + rng.nextInt(3);
  final children = <RenderNode<String>>[
    for (var i = 0; i < n; i++) randomTree(rng, depth: depth - 1),
  ];
  return Flex<String>(
    direction: Axis.values[rng.nextInt(Axis.values.length)],
    children: children,
    mainAxisAlignment: MainAxisAlignment.values[rng.nextInt(MainAxisAlignment.values.length)],
    crossAxisAlignment: CrossAxisAlignment.values[rng.nextInt(CrossAxisAlignment.values.length)],
    mainAxisSize: MainAxisSize.values[rng.nextInt(MainAxisSize.values.length)],
  );
}

// The first child is always non-positioned, so the stack can size itself from a
// child even under an unbounded constraint (an all-positioned stack there is
// another asserted author error).
Stack<String> _randomStack(Random rng, int depth) {
  final n = 1 + rng.nextInt(3);
  final children = <RenderNode<String>>[
    randomTree(rng, depth: depth - 1),
    for (var i = 1; i < n; i++) _randomStackChild(rng, depth),
  ];
  return Stack<String>(
    children: children,
    alignment: Alignment.values[rng.nextInt(Alignment.values.length)],
    fit: StackFit.values[rng.nextInt(StackFit.values.length)],
  );
}

RenderNode<String> _randomStackChild(Random rng, int depth) {
  final child = randomTree(rng, depth: depth - 1);
  if (rng.nextBool()) {
    return child;
  }
  int? edge() => rng.nextBool() ? null : rng.nextInt(7);
  int? extent() => rng.nextBool() ? null : rng.nextInt(9);
  return Positioned<String>(
    left: edge(),
    top: edge(),
    right: edge(),
    bottom: edge(),
    width: extent(),
    height: extent(),
    child: child,
  );
}

EdgeInsets _randomInsets(Random rng) =>
    EdgeInsets.only(left: rng.nextInt(3), top: rng.nextInt(3), right: rng.nextInt(3), bottom: rng.nextInt(3));
