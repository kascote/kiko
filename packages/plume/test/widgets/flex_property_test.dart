import 'dart:math';

import 'package:plume/plume.dart';
import 'package:test/test.dart';

// Property tests for the flex two-pass layout and its space distribution. Where
// flex_test.dart pins hand-picked examples, these assert the invariants the
// distribution must satisfy for *every* input in a range: nothing overflows,
// children stay ordered, the free space is conserved, and the remainder is
// shared fairly. Seeds are fixed so any failure reproduces.

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

SizedBox<String> _box(int w, int h) => SizedBox<String>(width: w, height: h);

/// Lays [flex] out under a bounded main/cross extent and returns its direct
/// children's rects.
List<Rect> _layout(Flex<String> flex, BoxConstraints constraints) {
  flex
    ..layout(constraints, _ctx)
    ..place(Offset.zero);
  final rects = <Rect>[];
  flex.visitChildren((child) => rects.add(child.rect));
  return rects;
}

void main() {
  group('flex placement invariants', () {
    // Along either axis, and under every alignment, children never overflow when
    // they fit, never overlap, keep their order, and stay inside the cross axis.
    test('children stay ordered, non-overlapping and in bounds', () {
      final rng = Random(1);
      for (var iter = 0; iter < 500; iter++) {
        final horizontal = rng.nextBool();
        final crossBound = 1 + rng.nextInt(4);
        var fixedTotal = 0;
        final children = <RenderNode<String>>[];
        final n = 1 + rng.nextInt(5);
        for (var i = 0; i < n; i++) {
          final cross = 1 + rng.nextInt(crossBound);
          if (rng.nextInt(3) == 0) {
            final child = horizontal ? _box(0, cross) : _box(cross, 0);
            children.add(Expanded<String>(flex: 1 + rng.nextInt(3), child: child));
          } else {
            final mainSize = rng.nextInt(6);
            fixedTotal += mainSize;
            children.add(horizontal ? _box(mainSize, cross) : _box(cross, mainSize));
          }
        }
        final mainBound = rng.nextInt(21);
        final ma = MainAxisAlignment.values[rng.nextInt(MainAxisAlignment.values.length)];
        final ca = CrossAxisAlignment.values[rng.nextInt(CrossAxisAlignment.values.length)];
        final flex = horizontal
            ? Row<String>(mainAxisAlignment: ma, crossAxisAlignment: ca, children: children)
            : Column<String>(mainAxisAlignment: ma, crossAxisAlignment: ca, children: children);
        final constraints = horizontal
            ? BoxConstraints(maxW: mainBound, maxH: crossBound)
            : BoxConstraints(maxW: crossBound, maxH: mainBound);
        final rects = _layout(flex, constraints);

        int mainStart(Rect r) => horizontal ? r.x : r.y;
        int mainEnd(Rect r) => horizontal ? r.right : r.bottom;
        int crossStart(Rect r) => horizontal ? r.y : r.x;
        int crossEnd(Rect r) => horizontal ? r.bottom : r.right;
        final crossExtent = horizontal ? flex.rect.height : flex.rect.width;
        final reason = 'iter $iter, horizontal=$horizontal, $ma/$ca, main=$mainBound';

        expect(mainStart(rects.first), greaterThanOrEqualTo(0), reason: reason);
        for (var i = 1; i < rects.length; i++) {
          expect(mainStart(rects[i]), greaterThanOrEqualTo(mainEnd(rects[i - 1])), reason: reason);
        }
        for (final r in rects) {
          expect(crossStart(r), greaterThanOrEqualTo(0), reason: reason);
          expect(crossEnd(r), lessThanOrEqualTo(crossExtent), reason: reason);
        }
        if (fixedTotal <= mainBound) {
          expect(mainEnd(rects.last), lessThanOrEqualTo(mainBound), reason: reason);
        }
      }
    });
  });

  group('flex share conservation', () {
    // Expanded children (tight fit) must consume the whole main axis with no cell
    // lost or invented — the last flexible child absorbs the integer remainder.
    test('Expanded children fill the main axis exactly', () {
      final rng = Random(2);
      for (var iter = 0; iter < 500; iter++) {
        final w = rng.nextInt(31);
        final children = <RenderNode<String>>[];
        // A handful of fixed children whose total never exceeds the width, so
        // there is always non-negative free space for the flexibles to divide.
        var budget = rng.nextInt(w + 1);
        final fixedCount = rng.nextInt(3);
        for (var i = 0; i < fixedCount && budget > 0; i++) {
          final piece = rng.nextInt(budget + 1);
          children.add(_box(piece, 1));
          budget -= piece;
        }
        final expandedCount = 1 + rng.nextInt(3);
        for (var i = 0; i < expandedCount; i++) {
          children.add(Expanded<String>(flex: 1 + rng.nextInt(4), child: _box(0, 1)));
        }
        children.shuffle(rng);
        final rects = _layout(Row<String>(children: children), BoxConstraints(maxW: w, maxH: 1));
        final sum = rects.fold<int>(0, (acc, r) => acc + r.width);
        expect(sum, w, reason: 'iter $iter, w=$w');
        for (final r in rects) {
          expect(r.width, greaterThanOrEqualTo(0), reason: 'iter $iter');
        }
      }
    });
  });

  group('space distribution invariants', () {
    // spaceBetween: no leading/trailing slack, gaps sum to the whole free space,
    // and no two gaps differ by more than a cell.
    test('spaceBetween reaches both edges and splits the gap fairly', () {
      final rng = Random(3);
      for (var iter = 0; iter < 500; iter++) {
        final n = 2 + rng.nextInt(4);
        final widths = <int>[for (var i = 0; i < n; i++) rng.nextInt(4)];
        final fixedTotal = widths.fold<int>(0, (acc, x) => acc + x);
        final free = rng.nextInt(16);
        final w = fixedTotal + free;
        final rects = _layout(
          Row<String>(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final x in widths) _box(x, 1)],
          ),
          BoxConstraints(maxW: w, maxH: 1),
        );
        final reason = 'iter $iter, widths=$widths, free=$free';
        expect(rects.first.x, 0, reason: reason);
        expect(rects.last.right, w, reason: reason);
        final gaps = <int>[for (var i = 1; i < n; i++) rects[i].x - rects[i - 1].right];
        for (final g in gaps) {
          expect(g, greaterThanOrEqualTo(0), reason: reason);
        }
        expect(gaps.fold<int>(0, (acc, g) => acc + g), free, reason: '$reason gaps=$gaps');
        expect(gaps.reduce(max) - gaps.reduce(min), lessThanOrEqualTo(1), reason: '$reason gaps=$gaps');
      }
    });

    // spaceEvenly and spaceAround keep every gap (ends included) non-negative,
    // consume all the free space, and bias the odd remainder to the leading side.
    test('spaceEvenly and spaceAround stay non-negative and bias slack forward', () {
      final rng = Random(4);
      for (final mode in [MainAxisAlignment.spaceEvenly, MainAxisAlignment.spaceAround]) {
        for (var iter = 0; iter < 300; iter++) {
          final n = 1 + rng.nextInt(5);
          final widths = <int>[for (var i = 0; i < n; i++) rng.nextInt(4)];
          final fixedTotal = widths.fold<int>(0, (acc, x) => acc + x);
          final free = rng.nextInt(16);
          final w = fixedTotal + free;
          final rects = _layout(
            Row<String>(mainAxisAlignment: mode, children: [for (final x in widths) _box(x, 1)]),
            BoxConstraints(maxW: w, maxH: 1),
          );
          final leading = rects.first.x;
          final trailing = w - rects.last.right;
          final gaps = <int>[for (var i = 1; i < n; i++) rects[i].x - rects[i - 1].right];
          final reason = '$mode iter $iter, widths=$widths, free=$free';
          expect(leading, greaterThanOrEqualTo(0), reason: reason);
          expect(trailing, greaterThanOrEqualTo(0), reason: reason);
          for (final g in gaps) {
            expect(g, greaterThanOrEqualTo(0), reason: reason);
          }
          expect(leading + gaps.fold<int>(0, (acc, g) => acc + g) + trailing, free, reason: reason);
          expect(leading, greaterThanOrEqualTo(trailing), reason: reason);
          expect(leading - trailing, lessThanOrEqualTo(1), reason: reason);
        }
      }
    });
  });
}
