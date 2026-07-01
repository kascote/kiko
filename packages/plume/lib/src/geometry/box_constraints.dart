import 'package:meta/meta.dart';

import 'size.dart';

/// The bounds a parent imposes on a child's size, in whole cells.
///
/// Constraints flow *down* the tree: a parent hands each child a
/// [BoxConstraints], the child picks a [Size] within it and reports back. A
/// `null` [maxW] or [maxH] means that axis is unbounded — the child may be as
/// large as it likes there.
@immutable
class BoxConstraints {
  /// Creates constraints from explicit bounds.
  ///
  /// [minW] and [minH] default to `0`; [maxW] and [maxH] default to `null`
  /// (unbounded).
  const BoxConstraints({this.minW = 0, this.maxW, this.minH = 0, this.maxH});

  /// Constraints demanding exactly [size]: min equals max on both axes.
  BoxConstraints.tight(Size size) : minW = size.w, maxW = size.w, minH = size.h, maxH = size.h;

  /// Constraints allowing any size from zero up to [size].
  BoxConstraints.loose(Size size) : minW = 0, maxW = size.w, minH = 0, maxH = size.h;

  /// Constraints that allow any size at all.
  const BoxConstraints.unbounded() : minW = 0, maxW = null, minH = 0, maxH = null;

  /// The smallest allowed width in cells.
  final int minW;

  /// The largest allowed width in cells, or `null` if unbounded.
  final int? maxW;

  /// The smallest allowed height in cells.
  final int minH;

  /// The largest allowed height in cells, or `null` if unbounded.
  final int? maxH;

  /// Whether the width has an upper bound.
  bool get hasBoundedWidth => maxW != null;

  /// Whether the height has an upper bound.
  bool get hasBoundedHeight => maxH != null;

  /// Whether only a single width is allowed ([minW] equals [maxW]).
  bool get hasTightWidth => maxW == minW;

  /// Whether only a single height is allowed ([minH] equals [maxH]).
  bool get hasTightHeight => maxH == minH;

  /// Whether these constraints are well-formed.
  ///
  /// Well-formed means no negative bound and each maximum at least as large as
  /// its minimum, so clamping a size into them always lands in a real range.
  /// The layout pass asserts this on entry, so an inverted or negative
  /// constraint is caught at the node it reaches rather than surfacing later as
  /// a wrong size.
  bool get isNormalized {
    final hiW = maxW;
    final hiH = maxH;
    return minW >= 0 && minH >= 0 && (hiW == null || hiW >= minW) && (hiH == null || hiH >= minH);
  }

  /// Returns the nearest well-formed constraints.
  ///
  /// Negative minimums and maximums are clamped up to zero, then each maximum
  /// is raised to at least its minimum. Use this at call sites that derive
  /// bounds arithmetically and could produce an inverted or negative range.
  BoxConstraints normalize() {
    final loW = minW < 0 ? 0 : minW;
    final loH = minH < 0 ? 0 : minH;
    final hiW = maxW;
    final hiH = maxH;
    return BoxConstraints(
      minW: loW,
      maxW: hiW == null ? null : (hiW < loW ? loW : hiW),
      minH: loH,
      maxH: hiH == null ? null : (hiH < loH ? loH : hiH),
    );
  }

  /// The largest size these constraints allow.
  ///
  /// An unbounded axis falls back to its minimum, so this is only meaningful
  /// when both axes are bounded (a tight or loose constraint).
  Size get biggest => Size(maxW ?? minW, maxH ?? minH);

  /// The smallest size these constraints allow.
  Size get smallest => Size(minW, minH);

  /// Clamps [w] into the `[minW, maxW]` range.
  int constrainWidth(int w) {
    final hi = maxW;
    var v = w;
    if (v < minW) {
      v = minW;
    }
    if (hi != null && v > hi) {
      v = hi;
    }
    return v;
  }

  /// Clamps [h] into the `[minH, maxH]` range.
  int constrainHeight(int h) {
    final hi = maxH;
    var v = h;
    if (v < minH) {
      v = minH;
    }
    if (hi != null && v > hi) {
      v = hi;
    }
    return v;
  }

  /// The nearest [Size] to [size] that satisfies these constraints.
  Size constrain(Size size) => Size(constrainWidth(size.w), constrainHeight(size.h));

  /// Drops both minimums to zero, keeping the maximums.
  ///
  /// Use this to ask a child for its natural size within the available space.
  BoxConstraints loosen() => BoxConstraints(maxW: maxW, maxH: maxH);

  /// Shrinks the available space by [horizontal] cells of width and [vertical]
  /// cells of height, never dropping a bound below zero.
  ///
  /// Both the maximums and the minimums move inward, leaving room for
  /// surrounding chrome such as padding or a border.
  BoxConstraints deflate(int horizontal, int vertical) {
    final dw = horizontal < 0 ? 0 : horizontal;
    final dh = vertical < 0 ? 0 : vertical;
    final hiW = maxW;
    final hiH = maxH;
    return BoxConstraints(
      minW: _atLeastZero(minW - dw),
      maxW: hiW == null ? null : _atLeastZero(hiW - dw),
      minH: _atLeastZero(minH - dh),
      maxH: hiH == null ? null : _atLeastZero(hiH - dh),
    );
  }

  /// Returns these constraints clamped to lie within [outer].
  ///
  /// Every bound is pulled into `outer`'s range, so the result never permits a
  /// size that `outer` would reject.
  BoxConstraints enforce(BoxConstraints outer) {
    final hiW = maxW;
    final hiH = maxH;
    return BoxConstraints(
      minW: _into(minW, outer.minW, outer.maxW),
      maxW: hiW == null ? outer.maxW : _into(hiW, outer.minW, outer.maxW),
      minH: _into(minH, outer.minH, outer.maxH),
      maxH: hiH == null ? outer.maxH : _into(hiH, outer.minH, outer.maxH),
    );
  }

  /// Whether [size] satisfies every bound.
  bool isSatisfiedBy(Size size) {
    final hiW = maxW;
    final hiH = maxH;
    final wOk = size.w >= minW && (hiW == null || size.w <= hiW);
    final hOk = size.h >= minH && (hiH == null || size.h <= hiH);
    return wOk && hOk;
  }

  static int _atLeastZero(int v) => v < 0 ? 0 : v;

  static int _into(int v, int lo, int? hi) {
    var r = v < lo ? lo : v;
    if (hi != null && r > hi) {
      r = hi;
    }
    return r;
  }

  @override
  bool operator ==(Object other) =>
      other is BoxConstraints && other.minW == minW && other.maxW == maxW && other.minH == minH && other.maxH == maxH;

  @override
  int get hashCode => Object.hash(minW, maxW, minH, maxH);

  @override
  String toString() {
    final w = hasBoundedWidth ? '$minW..$maxW' : '$minW..∞';
    final h = hasBoundedHeight ? '$minH..$maxH' : '$minH..∞';
    return 'BoxConstraints(w: $w, h: $h)';
  }
}
