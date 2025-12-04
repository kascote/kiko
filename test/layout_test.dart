import 'package:cassowary/cassowary.dart' as cas;
import 'package:kiko/iterators.dart';
import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Layout >', () {
    test('validate strengths', () {
      expect(
        Strengths.spacerSizeEq.value,
        greaterThan(Strengths.maxSizeLe.value),
      );
      expect(Strengths.maxSizeLe.value, greaterThan(Strengths.maxSizeEq.value));
      expect(Strengths.minSizeGe.value, equals(Strengths.maxSizeLe.value));
      expect(
        Strengths.maxSizeLe.value,
        greaterThan(Strengths.lengthSizeEq.value),
      );
      expect(
        Strengths.lengthSizeEq.value,
        greaterThan(Strengths.percentageSizeEq.value),
      );
      expect(
        Strengths.percentageSizeEq.value,
        greaterThan(Strengths.ratioSizeEq.value),
      );
      expect(
        Strengths.ratioSizeEq.value,
        greaterThan(Strengths.maxSizeEq.value),
      );
      expect(Strengths.minSizeGe.value, greaterThan(Strengths.fillGrow.value));
      expect(Strengths.fillGrow.value, greaterThan(Strengths.grow.value));
      expect(Strengths.grow.value, greaterThan(Strengths.spaceGrow.value));
      expect(
        Strengths.spaceGrow.value,
        greaterThan(Strengths.allSegmentGrow.value),
      );
    });

    test('vertical', () {
      final v = Layout.vertical(const [ConstraintMin(0)]);
      expect(v.constraints.length, 1);
      expect(
        v,
        Layout(
          direction: Direction.vertical,
          margin: Margin.zero,
          constraints: const [ConstraintMin(0)],
          flex: Flex.start,
          spacing: Space(0),
        ),
      );
    });

    test('horizontal', () {
      final h = Layout.horizontal(const [ConstraintMin(0)]);
      expect(h.constraints.length, 1);
      expect(
        h,
        Layout(
          direction: Direction.horizontal,
          margin: Margin.zero,
          constraints: const [ConstraintMin(0)],
          flex: Flex.start,
          spacing: Space(0),
        ),
      );
    });

    test('solver', () {
      final s = cas.Solver();

      final x = cas.Param();
      final y = cas.Param();

      final c1 = ((x + y).equals(cas.cm(5)))..priority = 4.0;
      final c2 = (x.equals(cas.cm(2)))..priority = 1.0;

      s
        ..addConstraint(c1)
        ..addConstraint(c2)
        ..addConstraint((y.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((y.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((y.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((y.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((y.equals(cas.cm(2)))..priority = 1.0)
        ..flushUpdates();

      expect(x.value, 3.0);
      expect(y.value, 2.0);
    });
    test('solver 2', () {
      final s = cas.Solver();

      final x = cas.Param();
      final y = cas.Param();

      final c1 = ((x + y).equals(cas.cm(5)))..priority = 4.0;
      final c2 = (y.equals(cas.cm(2)))..priority = 1.0;

      s
        ..addConstraint(c1)
        ..addConstraint(c2)
        ..addConstraint((x.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((x.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((x.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((x.equals(cas.cm(2)))..priority = 1.0)
        ..addConstraint((x.equals(cas.cm(2)))..priority = 1.0)
        ..flushUpdates();

      expect(y.value, 3.0);
      expect(x.value, 2.0);
    });

    test('horizontal Margin', () {
      final ly = Layout(
        constraints: const [ConstraintLength(1)],
        margin: const Margin(1, 2),
        direction: Direction.horizontal,
      );

      expect(ly.horizontalMargin(10).margin, const Margin(10, 2));
    });

    test('vertical Margin', () {
      final ly = Layout(
        constraints: const [ConstraintLength(1)],
        margin: const Margin(1, 2),
        direction: Direction.horizontal,
      );

      expect(ly.verticalMargin(10).margin, const Margin(1, 10));
    });
  });

  group('Layout >', () {
    final abc = List.generate(26, (i) => String.fromCharCode(97 + i));
    void letters(
      Flex flex,
      List<Constraint> constraints,
      int width,
      String expected,
    ) {
      final area = Rect.create(x: 0, y: 0, width: width, height: 1);
      final layout = Layout(
        direction: Direction.horizontal,
        constraints: constraints,
        flex: flex,
      ).split(area);
      final buffer = Buffer.empty(area);
      for (final (c, area) in abc.take(constraints.length).zip(layout)) {
        final s = c * area.width;
        Line(content: s).render(area, Frame(buffer.area, buffer, 0));
      }
      expect(buffer.eq(Buffer.fromStringLines([expected])), isTrue);
    }

    group('split', () {
      test('length', () {
        final kases = [
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(0)],
            expected: 'a',
          ), // zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(1)],
            expected: 'a',
          ), // exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(2)],
            expected: 'a',
          ), // overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(0)],
            expected: 'aa',
          ), // zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(1)],
            expected: 'aa',
          ), // underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(2)],
            expected: 'aa',
          ), // exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(3)],
            expected: 'aa',
          ), // overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(0), const ConstraintLength(0)],
            expected: 'b',
          ), // zero, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(0), const ConstraintLength(1)],
            expected: 'b',
          ), // zero, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(0), const ConstraintLength(2)],
            expected: 'b',
          ), // zero, overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(1), const ConstraintLength(0)],
            expected: 'a',
          ), // exact, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(1), const ConstraintLength(1)],
            expected: 'a',
          ), // exact, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(1), const ConstraintLength(2)],
            expected: 'a',
          ), // exact, overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(2), const ConstraintLength(0)],
            expected: 'a',
          ), // overflow, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(2), const ConstraintLength(1)],
            expected: 'a',
          ), // overflow, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintLength(2), const ConstraintLength(2)],
            expected: 'a',
          ), // overflow, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(0), const ConstraintLength(0)],
            expected: 'bb',
          ), // zero, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(0), const ConstraintLength(1)],
            expected: 'bb',
          ), // zero, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(0), const ConstraintLength(2)],
            expected: 'bb',
          ), // zero, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(0), const ConstraintLength(3)],
            expected: 'bb',
          ), // zero, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(1), const ConstraintLength(0)],
            expected: 'ab',
          ), // underflow, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(1), const ConstraintLength(1)],
            expected: 'ab',
          ), // underflow, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(1), const ConstraintLength(2)],
            expected: 'ab',
          ), // underflow, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(1), const ConstraintLength(3)],
            expected: 'ab',
          ), // underflow, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(2), const ConstraintLength(0)],
            expected: 'aa',
          ), // exact, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(2), const ConstraintLength(1)],
            expected: 'aa',
          ), // exact, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(2), const ConstraintLength(2)],
            expected: 'aa',
          ), // exact, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(2), const ConstraintLength(3)],
            expected: 'aa',
          ), // exact, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(3), const ConstraintLength(0)],
            expected: 'aa',
          ), // overflow, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(3), const ConstraintLength(1)],
            expected: 'aa',
          ), // overflow, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(3), const ConstraintLength(2)],
            expected: 'aa',
          ), // overflow, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintLength(3), const ConstraintLength(3)],
            expected: 'aa',
          ), // overflow, overflow
          (
            f: Flex.legacy,
            w: 3,
            ct: [const ConstraintLength(2), const ConstraintLength(2)],
            expected: 'aab',
          ), // with stretchlast
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('max', () {
        final kases = [
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(0)],
            expected: 'a',
          ), // zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(1)],
            expected: 'a',
          ), // exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(2)],
            expected: 'a',
          ), // overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(0)],
            expected: 'aa',
          ), // zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(1)],
            expected: 'aa',
          ), // underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(2)],
            expected: 'aa',
          ), // exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(3)],
            expected: 'aa',
          ), // overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(0), const ConstraintMax(0)],
            expected: 'b',
          ), // zero, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(0), const ConstraintMax(1)],
            expected: 'b',
          ), // zero, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(0), const ConstraintMax(2)],
            expected: 'b',
          ), // zero, overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(1), const ConstraintMax(0)],
            expected: 'a',
          ), // exact, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(1), const ConstraintMax(1)],
            expected: 'a',
          ), // exact, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(1), const ConstraintMax(2)],
            expected: 'a',
          ), // exact, overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(2), const ConstraintMax(0)],
            expected: 'a',
          ), // overflow, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(2), const ConstraintMax(1)],
            expected: 'a',
          ), // overflow, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMax(2), const ConstraintMax(2)],
            expected: 'a',
          ), // overflow, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(0), const ConstraintMax(0)],
            expected: 'bb',
          ), // zero, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(0), const ConstraintMax(1)],
            expected: 'bb',
          ), // zero, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(0), const ConstraintMax(2)],
            expected: 'bb',
          ), // zero, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(0), const ConstraintMax(3)],
            expected: 'bb',
          ), // zero, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(1), const ConstraintMax(0)],
            expected: 'ab',
          ), // underflow, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(1), const ConstraintMax(1)],
            expected: 'ab',
          ), // underflow, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(1), const ConstraintMax(2)],
            expected: 'ab',
          ), // underflow, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(1), const ConstraintMax(3)],
            expected: 'ab',
          ), // underflow, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(2), const ConstraintMax(0)],
            expected: 'aa',
          ), // exact, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(2), const ConstraintMax(1)],
            expected: 'aa',
          ), // exact, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(2), const ConstraintMax(2)],
            expected: 'aa',
          ), // exact, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(2), const ConstraintMax(3)],
            expected: 'aa',
          ), // exact, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(3), const ConstraintMax(0)],
            expected: 'aa',
          ), // overflow, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(3), const ConstraintMax(1)],
            expected: 'aa',
          ), // overflow, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(3), const ConstraintMax(2)],
            expected: 'aa',
          ), // overflow, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMax(3), const ConstraintMax(3)],
            expected: 'aa',
          ), // overflow, overflow
          (
            f: Flex.legacy,
            w: 3,
            ct: [const ConstraintMax(2), const ConstraintMax(2)],
            expected: 'aab',
          ),
        ];
        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('min', () {
        final kases = [
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(0), const ConstraintMin(0)],
            expected: 'b',
          ), // zero, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(0), const ConstraintMin(1)],
            expected: 'b',
          ), // zero, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(0), const ConstraintMin(2)],
            expected: 'b',
          ), // zero, overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(1), const ConstraintMin(0)],
            expected: 'a',
          ), // exact, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(1), const ConstraintMin(1)],
            expected: 'a',
          ), // exact, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(1), const ConstraintMin(2)],
            expected: 'a',
          ), // exact, overflow
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(2), const ConstraintMin(0)],
            expected: 'a',
          ), // overflow, zero
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(2), const ConstraintMin(1)],
            expected: 'a',
          ), // overflow, exact
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintMin(2), const ConstraintMin(2)],
            expected: 'a',
          ), // overflow, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(0), const ConstraintMin(0)],
            expected: 'bb',
          ), // zero, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(0), const ConstraintMin(1)],
            expected: 'bb',
          ), // zero, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(0), const ConstraintMin(2)],
            expected: 'bb',
          ), // zero, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(0), const ConstraintMin(3)],
            expected: 'bb',
          ), // zero, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(1), const ConstraintMin(0)],
            expected: 'ab',
          ), // underflow, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(1), const ConstraintMin(1)],
            expected: 'ab',
          ), // underflow, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(1), const ConstraintMin(2)],
            expected: 'ab',
          ), // underflow, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(1), const ConstraintMin(3)],
            expected: 'ab',
          ), // underflow, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(2), const ConstraintMin(0)],
            expected: 'aa',
          ), // exact, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(2), const ConstraintMin(1)],
            expected: 'aa',
          ), // exact, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(2), const ConstraintMin(2)],
            expected: 'aa',
          ), // exact, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(2), const ConstraintMin(3)],
            expected: 'aa',
          ), // exact, overflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(3), const ConstraintMin(0)],
            expected: 'aa',
          ), // overflow, zero
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(3), const ConstraintMin(1)],
            expected: 'aa',
          ), // overflow, underflow
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(3), const ConstraintMin(2)],
            expected: 'aa',
          ), // overflow, exact
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintMin(3), const ConstraintMin(3)],
            expected: 'aa',
          ), // overflow, overflow
          (
            f: Flex.legacy,
            w: 3,
            ct: [const ConstraintMin(2), const ConstraintMin(2)],
            expected: 'aab',
          ),
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('percentage', () {
        final kases = [
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(0)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(25)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(50)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(90)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(100)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(200)],
            expected: 'a',
          ),
          // One constraint will take all the space (width = 2)
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(0)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(10)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(25)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(50)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(66)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(100)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(200)],
            expected: 'aa',
          ),
          // One constraint will take all the space (width = 3)
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(0)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(10)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(25)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(50)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(66)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(100)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(200)],
            expected: 'aaaaaaaaaa',
          ),
          // 0%/any allocates all the space to the second constraint
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(0), const ConstraintPercent(0)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(0), const ConstraintPercent(10)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(0), const ConstraintPercent(50)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(0), const ConstraintPercent(90)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(100),
            ],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(200),
            ],
            expected: 'b',
          ),
          // 10%/any allocates all the space to the second constraint (even if it is 0)
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(10), const ConstraintPercent(0)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(10),
            ],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(50),
            ],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(90),
            ],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(100),
            ],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(200),
            ],
            expected: 'b',
          ),
          // 50%/any allocates all the space to the first constraint
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(50), const ConstraintPercent(0)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(50),
            ],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(100),
            ],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(200),
            ],
            expected: 'a',
          ),
          // 90%/any allocates all the space to the first constraint
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintPercent(90), const ConstraintPercent(0)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(90),
              const ConstraintPercent(50),
            ],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(90),
              const ConstraintPercent(100),
            ],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(90),
              const ConstraintPercent(200),
            ],
            expected: 'a',
          ),
          // 100%/any allocates all the space to the first constraint
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(0),
            ],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(50),
            ],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(100),
            ],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(200),
            ],
            expected: 'a',
          ),
          // 0%/any allocates all the space to the second constraint
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(0), const ConstraintPercent(0)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(0), const ConstraintPercent(25)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(0), const ConstraintPercent(50)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(100),
            ],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(200),
            ],
            expected: 'bb',
          ),
          // 10%/any allocates all the space to the second constraint
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(10), const ConstraintPercent(0)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(25),
            ],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(50),
            ],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(100),
            ],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(200),
            ],
            expected: 'bb',
          ),
          // 25% * 2 = 0.5, which rounds up to 1, so the first constraint gets 1
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(25), const ConstraintPercent(0)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(50),
            ],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(100),
            ],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(200),
            ],
            expected: 'ab',
          ),
          // 33% * 2 = 0.66, so the first constraint gets 1
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(33), const ConstraintPercent(0)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(25),
            ],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(50),
            ],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(100),
            ],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(200),
            ],
            expected: 'ab',
          ),
          // 50% * 2 = 1, so the first constraint gets 1
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintPercent(50), const ConstraintPercent(0)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(50),
            ],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(100),
            ],
            expected: 'ab',
          ),
          // 100%/any allocates all the space to the first constraint
          // This is probably not the correct behavior, but it is the current behavior
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(0),
            ],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(50),
            ],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(100),
            ],
            expected: 'aa',
          ),
          // 33%/any allocates 1 to the first constraint the rest to the second
          (
            f: Flex.legacy,
            w: 3,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(33),
            ],
            expected: 'abb',
          ),
          (
            f: Flex.legacy,
            w: 3,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(66),
            ],
            expected: 'abb',
          ),
          // 33%/any allocates 1.33 = 1 to the first constraint the rest to the second
          (
            f: Flex.legacy,
            w: 4,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(33),
            ],
            expected: 'abbb',
          ),
          (
            f: Flex.legacy,
            w: 4,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(66),
            ],
            expected: 'abbb',
          ),
          // Longer tests zero allocates everything to the second constraint
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(0)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(25)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(50)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(100),
            ],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(200),
            ],
            expected: 'bbbbbbbbbb',
          ),
          // 10% allocates a single character to the first constraint
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(10), const ConstraintPercent(0)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(25),
            ],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(50),
            ],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(100),
            ],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(200),
            ],
            expected: 'abbbbbbbbb',
          ),
          // 25% allocates 2.5 = 3 characters to the first constraint
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(25), const ConstraintPercent(0)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(50),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(100),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(200),
            ],
            expected: 'aaabbbbbbb',
          ),
          // 33% allocates 3.3 = 3 characters to the first constraint
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(33), const ConstraintPercent(0)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(25),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(50),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(100),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(200),
            ],
            expected: 'aaabbbbbbb',
          ),
          // 50% allocates 5 characters to the first constraint
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintPercent(50), const ConstraintPercent(0)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(50),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(100),
            ],
            expected: 'aaaaabbbbb',
          ),
          // 100% allocates everything to the first constraint
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(0),
            ],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(50),
            ],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(100),
            ],
            expected: 'aaaaaaaaaa',
          ),
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('percentage start', () {
        final kases = [
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(0)],
            expected: '          ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(25)],
            expected: 'bbb       ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(50)],
            expected: 'bbbbb     ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(100),
            ],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(200),
            ],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintPercent(10), const ConstraintPercent(0)],
            expected: 'a         ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(25),
            ],
            expected: 'abbb      ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(50),
            ],
            expected: 'abbbbb    ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(100),
            ],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(200),
            ],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintPercent(25), const ConstraintPercent(0)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: 'aaabb     ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(50),
            ],
            expected: 'aaabbbbb  ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(100),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(200),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintPercent(33), const ConstraintPercent(0)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(25),
            ],
            expected: 'aaabbb    ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(50),
            ],
            expected: 'aaabbbbb  ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(100),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(200),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintPercent(50), const ConstraintPercent(0)],
            expected: 'aaaaa     ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(50),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(100),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(0),
            ],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(50),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(100),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(200),
            ],
            expected: 'aaaaabbbbb',
          ),
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('percentage spaceBetween', () {
        final kases = [
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(0)],
            expected: '          ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(25)],
            expected: '        bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintPercent(0), const ConstraintPercent(50)],
            expected: '     bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(100),
            ],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(0),
              const ConstraintPercent(200),
            ],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintPercent(10), const ConstraintPercent(0)],
            expected: 'a         ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(25),
            ],
            expected: 'a       bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(50),
            ],
            expected: 'a    bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(100),
            ],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(10),
              const ConstraintPercent(200),
            ],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintPercent(25), const ConstraintPercent(0)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: 'aaa     bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(50),
            ],
            expected: 'aaa  bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(100),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(200),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintPercent(33), const ConstraintPercent(0)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(25),
            ],
            expected: 'aaa     bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(50),
            ],
            expected: 'aaa  bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(100),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(33),
              const ConstraintPercent(200),
            ],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintPercent(50), const ConstraintPercent(0)],
            expected: 'aaaaa     ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(50),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(100),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(0),
            ],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(50),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(100),
            ],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [
              const ConstraintPercent(100),
              const ConstraintPercent(200),
            ],
            expected: 'aaaaabbbbb',
          ),
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('ratio', () {
        final kases = [
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(0, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 4)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 2)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(9, 10)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(2, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(0, 1)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 10)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 4)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 2)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(2, 3)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 1)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(2, 1)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(0, 1)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 10)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 2)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(9, 10)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 1)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(2, 1)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(0, 1)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 10)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 2)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(9, 10)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 1)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(2, 1)],
            expected: 'b',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(0, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 2)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(2, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(9, 10), const ConstraintRatio(0, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(9, 10), const ConstraintRatio(1, 2)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(9, 10), const ConstraintRatio(1, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(9, 10), const ConstraintRatio(2, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(0, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 2)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 1,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(2, 1)],
            expected: 'a',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(0, 1)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 4)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 2)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 1)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(2, 1)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(0, 1)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 4)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 2)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 1)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(2, 1)],
            expected: 'bb',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(0, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 4)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 2)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(2, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(0, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 4)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 2)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(2, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(0, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 2)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 1)],
            expected: 'ab',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(0, 1)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 2)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 2,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 1)],
            expected: 'aa',
          ),
          (
            f: Flex.legacy,
            w: 3,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 3)],
            expected: 'abb',
          ),
          (
            f: Flex.legacy,
            w: 3,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(2, 3)],
            expected: 'abb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(0, 1)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 4)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 2)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 1)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(2, 1)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(0, 1)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 4)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 2)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 1)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(2, 1)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(0, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 4)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 2)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(2, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(0, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 4)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 2)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(2, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(0, 1)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 2)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 1)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(0, 1)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 2)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.legacy,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 1)],
            expected: 'aaaaaaaaaa',
          ),
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('ratio start', () {
        final kases = [
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(0, 1)],
            expected: '          ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 4)],
            expected: 'bbb       ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 2)],
            expected: 'bbbbb     ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 1)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(2, 1)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(0, 1)],
            expected: 'a         ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 4)],
            expected: 'abbb      ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 2)],
            expected: 'abbbbb    ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 1)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(2, 1)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(0, 1)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 4)],
            expected: 'aaabb     ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 2)],
            expected: 'aaabbbbb  ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(2, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(0, 1)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 4)],
            expected: 'aaabbb    ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 2)],
            expected: 'aaabbbbb  ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(2, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(0, 1)],
            expected: 'aaaaa     ',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 2)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 1)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(0, 1)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 2)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 1)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.start,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(2, 1)],
            expected: 'aaaaabbbbb',
          ),
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('ratio speceBetween', () {
        final kases = [
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(0, 1)],
            expected: '          ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 4)],
            expected: '        bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 2)],
            expected: '     bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(1, 1)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(0, 1), const ConstraintRatio(2, 1)],
            expected: 'bbbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(0, 1)],
            expected: 'a         ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 4)],
            expected: 'a       bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 2)],
            expected: 'a    bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(1, 1)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 10), const ConstraintRatio(2, 1)],
            expected: 'abbbbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(0, 1)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 4)],
            expected: 'aaa     bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 2)],
            expected: 'aaa  bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(1, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 4), const ConstraintRatio(2, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(0, 1)],
            expected: 'aaa       ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 4)],
            expected: 'aaa     bb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 2)],
            expected: 'aaa  bbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(1, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 3), const ConstraintRatio(2, 1)],
            expected: 'aaabbbbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(0, 1)],
            expected: 'aaaaa     ',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 2)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 2), const ConstraintRatio(1, 1)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(0, 1)],
            expected: 'aaaaaaaaaa',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 2)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(1, 1)],
            expected: 'aaaaabbbbb',
          ),
          (
            f: Flex.spaceBetween,
            w: 10,
            ct: [const ConstraintRatio(1, 1), const ConstraintRatio(2, 1)],
            expected: 'aaaaabbbbb',
          ),
        ];

        for (final kase in kases) {
          letters(kase.f, kase.ct, kase.w, kase.expected);
        }
      });

      test('vertical split by height', () {
        final target = Rect.create(x: 2, y: 2, width: 10, height: 10);
        final chunks = Layout(
          direction: Direction.vertical,
          constraints: const [
            ConstraintPercent(10),
            ConstraintMax(5),
            ConstraintMin(1),
          ],
        ).split(target);

        expect(
          chunks.map((c) => c.height).fold(0, (acc, c) => acc + c),
          target.height,
        );
        chunks.tuples().forEach((tup) => expect(tup.$1.y, lessThan(tup.$2.y)));
      });

      test('edge cases', () {
        // stretches into last
        final layout1 = Layout.vertical(const [
          ConstraintPercent(50),
          ConstraintPercent(50),
          ConstraintMin(0),
        ]).split(Rect.create(x: 0, y: 0, width: 1, height: 1));
        expect(layout1, [
          Rect.create(x: 0, y: 0, width: 1, height: 1),
          Rect.create(x: 0, y: 1, width: 1, height: 0),
          Rect.create(x: 0, y: 1, width: 1, height: 0),
        ]);

        // stretches into last
        final layout2 = Layout.vertical(const [
          ConstraintMax(1),
          ConstraintPercent(99),
          ConstraintMin(0),
        ]).split(Rect.create(x: 0, y: 0, width: 1, height: 1));
        expect(layout2, [
          Rect.create(x: 0, y: 0, width: 1, height: 0),
          Rect.create(x: 0, y: 0, width: 1, height: 1),
          Rect.create(x: 0, y: 1, width: 1, height: 0),
        ]);

        final layout3 = Layout.horizontal(const [
          ConstraintMin(1),
          ConstraintLength(0),
          ConstraintMin(1),
        ]).split(Rect.create(x: 0, y: 0, width: 1, height: 1));
        expect(layout3, [
          Rect.create(x: 0, y: 0, width: 1, height: 1),
          Rect.create(x: 1, y: 0, width: 0, height: 1),
          Rect.create(x: 1, y: 0, width: 0, height: 1),
        ]);

        final layout4 = Layout.horizontal(const [
          ConstraintLength(3),
          ConstraintMin(4),
          ConstraintLength(1),
          ConstraintMin(4),
        ]).split(Rect.create(x: 0, y: 0, width: 7, height: 1));
        expect(layout4, [
          Rect.create(x: 0, y: 0, width: 0, height: 1),
          Rect.create(x: 0, y: 0, width: 4, height: 1),
          Rect.create(x: 4, y: 0, width: 0, height: 1),
          Rect.create(x: 4, y: 0, width: 3, height: 1),
        ]);
      });

      test('constraint length', () {
        final kases = [
          (
            exp: [0, 100],
            ct: [const ConstraintLength(25), const ConstraintMin(100)],
          ),
          (
            exp: [25, 75],
            ct: [const ConstraintLength(25), const ConstraintMin(0)],
          ),
          (
            exp: [100, 0],
            ct: [const ConstraintLength(25), const ConstraintMax(0)],
          ),
          (
            exp: [25, 75],
            ct: [const ConstraintLength(25), const ConstraintMax(100)],
          ),
          (
            exp: [25, 75],
            ct: [const ConstraintLength(25), const ConstraintPercent(25)],
          ),
          (
            exp: [75, 25],
            ct: [const ConstraintPercent(25), const ConstraintLength(25)],
          ),
          (
            exp: [25, 75],
            ct: [const ConstraintLength(25), const ConstraintRatio(1, 4)],
          ),
          (
            exp: [75, 25],
            ct: [const ConstraintRatio(1, 4), const ConstraintLength(25)],
          ),
          (
            exp: [25, 75],
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
          ),
          (
            exp: [15, 35, 50],
            ct: [
              const ConstraintLength(15),
              const ConstraintLength(35),
              const ConstraintLength(25),
            ],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: Flex.legacy).split(rect);
          expect(r.map((c) => c.width), kase.exp);
        }
      });

      test('table length', () {
        final kases = [
          (
            ct: [const ConstraintLength(4), const ConstraintLength(4)],
            exp: [(0, 3), (4, 3)],
            w: 7,
          ),
          (
            ct: [const ConstraintLength(4), const ConstraintLength(4)],
            exp: [(0, 2), (3, 1)],
            w: 4,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: kase.w, height: 1);
          final r = Layout.horizontal(
            kase.ct,
            spacing: Space(1),
            flex: Flex.start,
          ).split(rect);
          expect(r.map((c) => (c.x, c.width)), kase.exp);
        }
      });

      test('length is higher priority', () {
        final kases = [
          (
            exp: [50, 25, 25],
            ct: [
              const ConstraintMin(25),
              const ConstraintLength(25),
              const ConstraintMax(25),
            ],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintMax(25),
              const ConstraintLength(25),
              const ConstraintMin(25),
            ],
          ),
          (
            exp: [33, 33, 34],
            ct: [
              const ConstraintLength(33),
              const ConstraintLength(33),
              const ConstraintLength(33),
            ],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintPercent(25),
              const ConstraintLength(25),
              const ConstraintRatio(1, 4),
            ],
          ),
          (
            exp: [25, 50, 25],
            ct: [
              const ConstraintLength(25),
              const ConstraintRatio(1, 4),
              const ConstraintPercent(25),
            ],
          ),
          (
            exp: [50, 25, 25],
            ct: [
              const ConstraintRatio(1, 4),
              const ConstraintLength(25),
              const ConstraintPercent(25),
            ],
          ),
          (
            exp: [50, 25, 25],
            ct: [
              const ConstraintRatio(1, 4),
              const ConstraintPercent(25),
              const ConstraintLength(25),
            ],
          ),
          (
            exp: [80, 0, 20],
            ct: [
              const ConstraintLength(100),
              const ConstraintLength(1),
              const ConstraintMin(20),
            ],
          ),
          (
            exp: [20, 1, 79],
            ct: [
              const ConstraintMin(20),
              const ConstraintLength(1),
              const ConstraintLength(100),
            ],
          ),
          (
            exp: [45, 10, 45],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
          ),
          (
            exp: [30, 10, 60],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(2),
            ],
          ),
          (
            exp: [18, 10, 72],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(4),
            ],
          ),
          (
            exp: [15, 10, 75],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(5),
            ],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: Flex.legacy).split(rect);
          expect(r.map((c) => c.width), kase.exp);
        }
      });

      test('length is higher priority in flex', () {
        final kases = [
          (
            exp: [50, 25, 25],
            ct: [
              const ConstraintMin(25),
              const ConstraintLength(25),
              const ConstraintMax(25),
            ],
          ),
          (
            exp: [25, 25, 50],
            ct: [
              const ConstraintMax(25),
              const ConstraintLength(25),
              const ConstraintMin(25),
            ],
          ),
          (
            exp: [33, 33, 33],
            ct: [
              const ConstraintLength(33),
              const ConstraintLength(33),
              const ConstraintLength(33),
            ],
          ),
          (
            exp: [25, 25, 25],
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
          ),
          (
            exp: [25, 25, 25],
            ct: [
              const ConstraintPercent(25),
              const ConstraintLength(25),
              const ConstraintRatio(1, 4),
            ],
          ),
          (
            exp: [25, 25, 25],
            ct: [
              const ConstraintLength(25),
              const ConstraintRatio(1, 4),
              const ConstraintPercent(25),
            ],
          ),
          (
            exp: [25, 25, 25],
            ct: [
              const ConstraintRatio(1, 4),
              const ConstraintLength(25),
              const ConstraintPercent(25),
            ],
          ),
          (
            exp: [25, 25, 25],
            ct: [
              const ConstraintRatio(1, 4),
              const ConstraintPercent(25),
              const ConstraintLength(25),
            ],
          ),
          (
            exp: [79, 1, 20],
            ct: [
              const ConstraintLength(100),
              const ConstraintLength(1),
              const ConstraintMin(20),
            ],
          ),
          (
            exp: [20, 1, 79],
            ct: [
              const ConstraintMin(20),
              const ConstraintLength(1),
              const ConstraintLength(100),
            ],
          ),
          (
            exp: [45, 10, 45],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
          ),
          (
            exp: [30, 10, 60],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(2),
            ],
          ),
          (
            exp: [18, 10, 72],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(4),
            ],
          ),
          (
            exp: [15, 10, 75],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(5),
            ],
          ),
          (
            exp: [25, 25, 25],
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
          ),
        ];

        for (final kase in kases) {
          final rect1 = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r1 = Layout.horizontal(kase.ct, flex: Flex.start).split(rect1);
          expect(r1.map((c) => c.width), kase.exp);

          final rect2 = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r2 = Layout.horizontal(kase.ct, flex: Flex.center).split(rect2);
          expect(r2.map((c) => c.width), kase.exp);

          final rect3 = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r3 = Layout.horizontal(kase.ct, flex: Flex.end).split(rect3);
          expect(r3.map((c) => c.width), kase.exp);

          final rect4 = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r4 = Layout.horizontal(
            kase.ct,
            flex: Flex.spaceAround,
          ).split(rect4);
          expect(r4.map((c) => c.width), kase.exp);

          final rect5 = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r5 = Layout.horizontal(
            kase.ct,
            flex: Flex.spaceBetween,
          ).split(rect5);
          expect(r5.map((c) => c.width), kase.exp);
        }
      });

      test('fixed with 50 width', () {
        final kases = [
          (
            exp: [13, 10, 27],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(2),
            ],
          ),
          (
            exp: [10, 27, 13],
            ct: [
              const ConstraintLength(10),
              const ConstraintFill(2),
              const ConstraintFill(1),
            ],
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 50, height: 1);
          final r = Layout.horizontal(kase.ct, flex: Flex.legacy).split(rect);
          expect(r.map((c) => c.width), kase.exp);
        }
      });

      test('fill', () {
        final kases = [
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(2),
              const ConstraintFill(1),
              const ConstraintFill(1),
            ],
            expect: [20, 40, 20, 20],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(2),
              const ConstraintFill(3),
              const ConstraintFill(4),
            ],
            expect: [10, 20, 30, 40],
          ),
          (
            ct: [
              const ConstraintFill(4),
              const ConstraintFill(3),
              const ConstraintFill(2),
              const ConstraintFill(1),
            ],
            expect: [40, 30, 20, 10],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(3),
              const ConstraintFill(2),
              const ConstraintFill(4),
            ],
            expect: [10, 30, 20, 40],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(3),
              const ConstraintLength(50),
              const ConstraintFill(2),
              const ConstraintFill(4),
            ],
            expect: [5, 15, 50, 10, 20],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(3),
              const ConstraintPercent(50),
              const ConstraintFill(2),
              const ConstraintFill(4),
            ],
            expect: [5, 15, 50, 10, 20],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(3),
              const ConstraintMin(50),
              const ConstraintFill(2),
              const ConstraintFill(4),
            ],
            expect: [5, 15, 50, 10, 20],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(3),
              const ConstraintMax(50),
              const ConstraintFill(2),
              const ConstraintFill(4),
            ],
            expect: [5, 15, 50, 10, 20],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintFill(1),
              const ConstraintFill(0),
            ],
            expect: [0, 100, 0],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintLength(1),
              const ConstraintFill(0),
            ],
            expect: [50, 1, 49],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintPercent(1),
              const ConstraintFill(0),
            ],
            expect: [50, 1, 49],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintMin(1),
              const ConstraintFill(0),
            ],
            expect: [50, 1, 49],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintMax(1),
              const ConstraintFill(0),
            ],
            expect: [50, 1, 49],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintFill(2),
              const ConstraintFill(0),
              const ConstraintFill(1),
            ],
            expect: [0, 67, 0, 33],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintFill(2),
              const ConstraintPercent(20),
            ],
            expect: [0, 80, 20],
          ),
          (
            ct: [
              const ConstraintFill(0),
              const ConstraintFill(0),
              const ConstraintPercent(20),
            ],
            expect: [40, 40, 20],
          ),
          (
            ct: [const ConstraintFill(0), const ConstraintRatio(1, 5)],
            expect: [80, 20],
          ),
          (
            ct: [const ConstraintFill(0), const ConstraintFill(u16Max)],
            expect: [0, 100],
          ),
          (
            ct: [const ConstraintFill(u16Max), const ConstraintFill(0)],
            expect: [100, 0],
          ),
          (
            ct: [const ConstraintFill(0), const ConstraintPercent(20)],
            expect: [80, 20],
          ),
          (
            ct: [const ConstraintFill(1), const ConstraintPercent(20)],
            expect: [80, 20],
          ),
          (
            ct: [const ConstraintFill(u16Max), const ConstraintPercent(20)],
            expect: [80, 20],
          ),
          (
            ct: [
              const ConstraintFill(u16Max),
              const ConstraintFill(0),
              const ConstraintPercent(20),
            ],
            expect: [80, 0, 20],
          ),
          (
            ct: [const ConstraintFill(0), const ConstraintLength(20)],
            expect: [80, 20],
          ),
          (
            ct: [const ConstraintFill(0), const ConstraintMin(20)],
            expect: [80, 20],
          ),
          (
            ct: [const ConstraintFill(0), const ConstraintMax(20)],
            expect: [80, 20],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintMin(30),
              const ConstraintLength(50),
            ],
            expect: [7, 6, 7, 30, 50],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintLength(50),
              const ConstraintLength(50),
            ],
            expect: [0, 0, 0, 50, 50],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintLength(75),
              const ConstraintLength(50),
            ],
            expect: [0, 0, 0, 75, 25],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintMin(50),
              const ConstraintMax(50),
            ],
            expect: [0, 0, 0, 50, 50],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintRatio(1, 1),
            ],
            expect: [0, 0, 0, 100],
          ),
          (
            ct: [
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintFill(1),
              const ConstraintPercent(100),
            ],
            expect: [0, 0, 0, 100],
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: Flex.legacy).split(rect);
          expect(r.map((c) => c.width), kase.expect);
        }
      });

      test('percentage parametrized', () {
        final kases = [
          (
            ct: [const ConstraintMin(0), const ConstraintPercent(20)],
            expected: [80, 20],
          ),
          (
            ct: [const ConstraintMax(0), const ConstraintPercent(20)],
            expected: [0, 100],
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: Flex.legacy).split(rect);
          expect(r.map((c) => c.width), kase.expected);
        }
      });

      test('min max', () {
        final kases = [
          (
            ct: [const ConstraintMax(100), const ConstraintMin(0)],
            expected: [100, 0],
          ),
          (
            ct: [const ConstraintMin(0), const ConstraintMax(100)],
            expected: [0, 100],
          ),
          (
            ct: [const ConstraintLength(u16Max), const ConstraintMin(10)],
            expected: [90, 10],
          ),
          (
            ct: [const ConstraintMin(10), const ConstraintLength(u16Max)],
            expected: [10, 90],
          ),
          (
            ct: [const ConstraintLength(0), const ConstraintMax(10)],
            expected: [90, 10],
          ),
          (
            ct: [const ConstraintMax(10), const ConstraintLength(0)],
            expected: [10, 90],
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: Flex.legacy).split(rect);
          expect(r.map((c) => c.width), kase.expected);
        }
      });

      test('flex constraint', () {
        final kases = [
          (ct: [const ConstraintLength(50)], expected: [100], f: Flex.legacy),
          (ct: [const ConstraintLength(50)], expected: [50], f: Flex.start),
          (ct: [const ConstraintLength(50)], expected: [50], f: Flex.end),
          (ct: [const ConstraintLength(50)], expected: [50], f: Flex.center),
          (ct: [const ConstraintRatio(1, 2)], expected: [100], f: Flex.legacy),
          (ct: [const ConstraintRatio(1, 2)], expected: [50], f: Flex.start),
          (ct: [const ConstraintRatio(1, 2)], expected: [50], f: Flex.end),
          (ct: [const ConstraintRatio(1, 2)], expected: [50], f: Flex.center),
          (
            ct: [const ConstraintPercent(50)],
            expected: [100],
            f: Flex.legacy,
          ),
          (ct: [const ConstraintPercent(50)], expected: [50], f: Flex.start),
          (ct: [const ConstraintPercent(50)], expected: [50], f: Flex.end),
          (
            ct: [const ConstraintPercent(50)],
            expected: [50],
            f: Flex.center,
          ),
          (ct: [const ConstraintMin(50)], expected: [100], f: Flex.legacy),
          (ct: [const ConstraintMin(50)], expected: [100], f: Flex.start),
          (ct: [const ConstraintMin(50)], expected: [100], f: Flex.end),
          (ct: [const ConstraintMin(50)], expected: [100], f: Flex.center),
          (ct: [const ConstraintMax(50)], expected: [100], f: Flex.legacy),
          (ct: [const ConstraintMax(50)], expected: [50], f: Flex.start),
          (ct: [const ConstraintMax(50)], expected: [50], f: Flex.end),
          (ct: [const ConstraintMax(50)], expected: [50], f: Flex.center),
          (ct: [const ConstraintMin(1)], expected: [100], f: Flex.spaceBetween),
          (
            ct: [const ConstraintMax(20)],
            expected: [100],
            f: Flex.spaceBetween,
          ),
          (
            ct: [const ConstraintLength(20)],
            expected: [100],
            f: Flex.spaceBetween,
          ),
          (
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
            expected: [25, 75],
            f: Flex.legacy,
          ),
          (
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
            expected: [25, 25],
            f: Flex.start,
          ),
          (
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
            expected: [25, 25],
            f: Flex.center,
          ),
          (
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
            expected: [25, 25],
            f: Flex.end,
          ),
          (
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
            expected: [25, 25],
            f: Flex.spaceBetween,
          ),
          (
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
            expected: [25, 25],
            f: Flex.spaceAround,
          ),
          (
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: [25, 75],
            f: Flex.legacy,
          ),
          (
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: [25, 25],
            f: Flex.start,
          ),
          (
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: [25, 25],
            f: Flex.center,
          ),
          (
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: [25, 25],
            f: Flex.end,
          ),
          (
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: [25, 25],
            f: Flex.spaceBetween,
          ),
          (
            ct: [
              const ConstraintPercent(25),
              const ConstraintPercent(25),
            ],
            expected: [25, 25],
            f: Flex.spaceAround,
          ),
          (
            ct: [const ConstraintMin(25), const ConstraintMin(25)],
            expected: [25, 75],
            f: Flex.legacy,
          ),
          (
            ct: [const ConstraintMin(25), const ConstraintMin(25)],
            expected: [50, 50],
            f: Flex.start,
          ),
          (
            ct: [const ConstraintMin(25), const ConstraintMin(25)],
            expected: [50, 50],
            f: Flex.center,
          ),
          (
            ct: [const ConstraintMin(25), const ConstraintMin(25)],
            expected: [50, 50],
            f: Flex.end,
          ),
          (
            ct: [const ConstraintMin(25), const ConstraintMin(25)],
            expected: [50, 50],
            f: Flex.spaceBetween,
          ),
          (
            ct: [const ConstraintMin(25), const ConstraintMin(25)],
            expected: [50, 50],
            f: Flex.spaceAround,
          ),
          (
            ct: [const ConstraintMax(25), const ConstraintMax(25)],
            expected: [25, 75],
            f: Flex.legacy,
          ),
          (
            ct: [const ConstraintMax(25), const ConstraintMax(25)],
            expected: [25, 25],
            f: Flex.start,
          ),
          (
            ct: [const ConstraintMax(25), const ConstraintMax(25)],
            expected: [25, 25],
            f: Flex.center,
          ),
          (
            ct: [const ConstraintMax(25), const ConstraintMax(25)],
            expected: [25, 25],
            f: Flex.end,
          ),
          (
            ct: [const ConstraintMax(25), const ConstraintMax(25)],
            expected: [25, 25],
            f: Flex.spaceBetween,
          ),
          (
            ct: [const ConstraintMax(25), const ConstraintMax(25)],
            expected: [25, 25],
            f: Flex.spaceAround,
          ),
          (
            ct: [
              const ConstraintLength(25),
              const ConstraintLength(25),
              const ConstraintLength(25),
            ],
            expected: [25, 25, 25],
            f: Flex.spaceBetween,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: kase.f).split(rect);
          expect(r.map((c) => c.width), kase.expected);
        }
      });

      test('flex overlap', () {
        final kases = [
          (
            expected: [(0, 20), (20, 20), (40, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.start,
            s: 0,
          ),
          (
            expected: [(0, 20), (19, 20), (38, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.start,
            s: -1,
          ),
          (
            expected: [(21, 20), (40, 20), (59, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.center,
            s: -1,
          ),
          (
            expected: [(42, 20), (61, 20), (80, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.end,
            s: -1,
          ),
          (
            expected: [(0, 20), (19, 20), (38, 62)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.legacy,
            s: -1,
          ),
          (
            expected: [(0, 20), (40, 20), (80, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.spaceBetween,
            s: -1,
          ),
          (
            expected: [(10, 20), (40, 20), (70, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.spaceAround,
            s: -1,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).split(rect);
          for (var i = 0; i < r.length; i++) {
            expect(r.map((c) => (c.x, c.width)), kase.expected);
          }
        }
      });

      test('flex spacing', () {
        final kases = [
          (
            expected: [(0, 20), (20, 20), (40, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.start,
            s: 0,
          ),
          (
            expected: [(0, 20), (22, 20), (44, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.start,
            s: 2,
          ),
          (
            expected: [(18, 20), (40, 20), (62, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.center,
            s: 2,
          ),
          (
            expected: [(36, 20), (58, 20), (80, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.end,
            s: 2,
          ),
          (
            expected: [(0, 20), (22, 20), (44, 56)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.legacy,
            s: 2,
          ),
          (
            expected: [(0, 20), (40, 20), (80, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.spaceBetween,
            s: 2,
          ),
          (
            expected: [(10, 20), (40, 20), (70, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.spaceAround,
            s: 2,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).split(rect);
          for (var i = 0; i < r.length; i++) {
            expect(r.map((c) => (c.x, c.width)), kase.expected);
          }
        }
      });

      test('constraint specification tests for priority', () {
        final kases = [
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintLength(25), const ConstraintLength(25)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintLength(25), const ConstraintPercent(25)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintPercent(25), const ConstraintLength(25)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintMin(25), const ConstraintPercent(25)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintPercent(25), const ConstraintMin(25)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintMin(25), const ConstraintPercent(100)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintPercent(100), const ConstraintMin(25)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintMax(75), const ConstraintPercent(75)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintPercent(75), const ConstraintMax(75)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintMax(25), const ConstraintPercent(25)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintPercent(25), const ConstraintMax(25)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintLength(25), const ConstraintRatio(1, 4)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintRatio(1, 4), const ConstraintLength(25)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintPercent(25), const ConstraintRatio(1, 4)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintRatio(1, 4), const ConstraintPercent(25)],
          ),
          (
            expected: [(0, 25), (25, 75)],
            ct: [const ConstraintRatio(1, 4), const ConstraintFill(25)],
          ),
          (
            expected: [(0, 75), (75, 25)],
            ct: [const ConstraintFill(25), const ConstraintRatio(1, 4)],
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: Flex.legacy).split(rect);
          expect(r.map((c) => (c.x, c.width)), kase.expected);
        }
      });
      test('constraint specification tests for priority with spacing', () {
        final kases = [
          (
            expected: [(0, 20), (20, 20), (40, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.start,
            s: 0,
          ),
          (
            expected: [(18, 20), (40, 20), (62, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.center,
            s: 2,
          ),
          (
            expected: [(36, 20), (58, 20), (80, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.end,
            s: 2,
          ),
          (
            expected: [(0, 20), (22, 20), (44, 56)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.legacy,
            s: 2,
          ),
          (
            expected: [(0, 20), (22, 20), (44, 56)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.legacy,
            s: 2,
          ),
          (
            expected: [(10, 20), (40, 20), (70, 20)],
            ct: [
              const ConstraintLength(20),
              const ConstraintLength(20),
              const ConstraintLength(20),
            ],
            f: Flex.spaceAround,
            s: 2,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).split(rect);
          for (var i = 0; i < r.length; i++) {
            expect(r.map((c) => (c.x, c.width)), kase.expected);
          }
        }
      });

      test('fill vs flex', () {
        final kases = [
          (
            expected: [(0, 10), (10, 80), (90, 10)],
            ct: [
              const ConstraintLength(10),
              const ConstraintFill(1),
              const ConstraintLength(10),
            ],
            f: Flex.legacy,
          ),
          (
            expected: [(0, 10), (90, 10)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceBetween,
          ),
          (
            expected: [(0, 27), (27, 10), (37, 26), (63, 10), (73, 27)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.legacy,
          ),
          (
            expected: [(27, 10), (63, 10)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceAround,
          ),
          (
            expected: [(0, 10), (10, 10), (20, 80)],
            ct: [
              const ConstraintLength(10),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.legacy,
          ),
          (
            expected: [(0, 10), (10, 10)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.start,
          ),
          (
            expected: [(0, 80), (80, 10), (90, 10)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintLength(10),
            ],
            f: Flex.legacy,
          ),
          (
            expected: [(80, 10), (90, 10)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.end,
          ),
          (
            expected: [(0, 40), (40, 10), (50, 10), (60, 40)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.legacy,
          ),
          (
            expected: [(40, 10), (50, 10)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.center,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: kase.f).split(rect);
          expect(r.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('fill spacing', () {
        final kases = [
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.legacy,
            s: 0,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceAround,
            s: 0,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceBetween,
            s: 0,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.start,
            s: 0,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.center,
            s: 0,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.end,
            s: 0,
          ),
          (
            expected: [(0, 45), (55, 45)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.legacy,
            s: 10,
          ),
          (
            expected: [(0, 45), (55, 45)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.start,
            s: 10,
          ),
          (
            expected: [(0, 45), (55, 45)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.center,
            s: 10,
          ),
          (
            expected: [(0, 45), (55, 45)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.end,
            s: 10,
          ),
          (
            expected: [(10, 35), (55, 35)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceAround,
            s: 10,
          ),
          (
            expected: [(0, 45), (55, 45)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceBetween,
            s: 10,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.legacy,
            s: 0,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceAround,
            s: 0,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceBetween,
            s: 0,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.start,
            s: 0,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.center,
            s: 0,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.end,
            s: 0,
          ),
          (
            expected: [(0, 35), (45, 10), (65, 35)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.legacy,
            s: 10,
          ),
          (
            expected: [(0, 35), (45, 10), (65, 35)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.start,
            s: 10,
          ),
          (
            expected: [(0, 35), (45, 10), (65, 35)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.center,
            s: 10,
          ),
          (
            expected: [(0, 35), (45, 10), (65, 35)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.end,
            s: 10,
          ),
          (
            expected: [(10, 25), (45, 10), (65, 25)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceAround,
            s: 10,
          ),
          (
            expected: [(0, 35), (45, 10), (65, 35)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceBetween,
            s: 10,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).split(rect);
          expect(r.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('fill overlap', () {
        final kases = [
          (
            expected: [(0, 55), (45, 55)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.legacy,
            s: -10,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceAround,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 55)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceBetween,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 55)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.start,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 55)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.center,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 55)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.end,
            s: -10,
          ),
          (
            expected: [(0, 51), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.legacy,
            s: -1,
          ),
          (
            expected: [(0, 51), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.start,
            s: -1,
          ),
          (
            expected: [(0, 51), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.center,
            s: -1,
          ),
          (
            expected: [(0, 51), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.end,
            s: -1,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceAround,
            s: -1,
          ),
          (
            expected: [(0, 51), (50, 50)],
            ct: [const ConstraintFill(1), const ConstraintFill(1)],
            f: Flex.spaceBetween,
            s: -1,
          ),
          (
            expected: [(0, 55), (45, 10), (45, 55)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.legacy,
            s: -10,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceAround,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 10), (45, 55)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceBetween,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 10), (45, 55)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.start,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 10), (45, 55)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.center,
            s: -10,
          ),
          (
            expected: [(0, 55), (45, 10), (45, 55)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.end,
            s: -10,
          ),
          (
            expected: [(0, 46), (45, 10), (54, 46)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.legacy,
            s: -1,
          ),
          (
            expected: [(0, 46), (45, 10), (54, 46)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.start,
            s: -1,
          ),
          (
            expected: [(0, 46), (45, 10), (54, 46)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.center,
            s: -1,
          ),
          (
            expected: [(0, 46), (45, 10), (54, 46)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.end,
            s: -1,
          ),
          (
            expected: [(0, 45), (45, 10), (55, 45)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceAround,
            s: -1,
          ),
          (
            expected: [(0, 46), (45, 10), (54, 46)],
            ct: [
              const ConstraintFill(1),
              const ConstraintLength(10),
              const ConstraintFill(1),
            ],
            f: Flex.spaceBetween,
            s: -1,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).split(rect);
          expect(r.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('flex spacing lower priority than_user spacing', () {
        final kases = [
          (
            expected: [(0, 10), (90, 10)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.center,
            s: 80,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).split(rect);
          expect(r.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('split with spacers no spacing', () {
        final kases = [
          (
            expected: [(0, 0), (10, 0), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.legacy,
          ),
          (
            expected: [(0, 0), (10, 80), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceBetween,
          ),
          (
            expected: [(0, 27), (37, 26), (73, 27)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceAround,
          ),
          (
            expected: [(0, 0), (10, 0), (20, 80)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.start,
          ),
          (
            expected: [(0, 40), (50, 0), (60, 40)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.center,
          ),
          (
            expected: [(0, 80), (90, 0), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.end,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final (_, s) = Layout.horizontal(
            kase.ct,
            flex: kase.f,
          ).splitWithSpacers(rect);

          expect(s.length, kase.ct.length + 1);
          expect(s.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('split with spacers and spacing', () {
        final kases = [
          (
            expected: [(0, 0), (10, 5), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.legacy,
            s: 5,
          ),
          (
            expected: [(0, 0), (10, 80), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceBetween,
            s: 5,
          ),
          (
            expected: [(0, 27), (37, 26), (73, 27)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceAround,
            s: 5,
          ),
          (
            expected: [(0, 0), (10, 5), (25, 75)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.start,
            s: 5,
          ),
          (
            expected: [(0, 38), (48, 5), (63, 37)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.center,
            s: 5,
          ),
          (
            expected: [(0, 75), (85, 5), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.end,
            s: 5,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final (_, s) = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).splitWithSpacers(rect);

          expect(s.length, kase.ct.length + 1);
          expect(s.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('split with spaces and overlap', () {
        final kases = [
          (
            expected: [(0, 0), (10, 0), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.legacy,
            s: -1,
          ),
          (
            expected: [(0, 0), (10, 80), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceBetween,
            s: -1,
          ),
          (
            expected: [(0, 27), (37, 26), (73, 27)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceAround,
            s: -1,
          ),
          (
            expected: [(0, 0), (10, 0), (19, 81)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.start,
            s: -1,
          ),
          (
            expected: [(0, 41), (51, 0), (60, 40)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.center,
            s: -1,
          ),
          (
            expected: [(0, 81), (91, 0), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.end,
            s: -1,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final (_, s) = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).splitWithSpacers(rect);

          expect(s.length, kase.ct.length + 1);
          expect(s.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('split with spacers and too much spacing', () {
        final kases = [
          (
            expected: [(0, 0), (0, 100), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.legacy,
            s: 200,
          ),
          (
            expected: [(0, 0), (0, 100), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceBetween,
            s: 200,
          ),
          (
            expected: [(0, 33), (33, 34), (67, 33)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.spaceAround,
            s: 200,
          ),
          (
            expected: [(0, 0), (0, 100), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.start,
            s: 200,
          ),
          (
            expected: [(0, 0), (0, 100), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.center,
            s: 200,
          ),
          (
            expected: [(0, 0), (0, 100), (100, 0)],
            ct: [const ConstraintLength(10), const ConstraintLength(10)],
            f: Flex.end,
            s: 200,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final (_, s) = Layout.horizontal(
            kase.ct,
            flex: kase.f,
            spacing: Spacing(kase.s),
          ).splitWithSpacers(rect);

          expect(s.length, kase.ct.length + 1);
          expect(s.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('legacy vs default', () {
        final kases = [
          (
            expected: [(0, 90), (90, 10)],
            ct: [const ConstraintMin(10), const ConstraintLength(10)],
            f: Flex.legacy,
          ),
          (
            expected: [(0, 90), (90, 10)],
            ct: [const ConstraintMin(10), const ConstraintLength(10)],
            f: Flex.start,
          ),
          (
            expected: [(0, 10), (10, 90)],
            ct: [const ConstraintMin(10), const ConstraintPercent(100)],
            f: Flex.legacy,
          ),
          (
            expected: [(0, 10), (10, 90)],
            ct: [const ConstraintMin(10), const ConstraintPercent(100)],
            f: Flex.start,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(50),
            ],
            f: Flex.legacy,
          ),
          (
            expected: [(0, 50), (50, 50)],
            ct: [
              const ConstraintPercent(50),
              const ConstraintPercent(50),
            ],
            f: Flex.start,
          ),
        ];

        for (final kase in kases) {
          final rect = Rect.create(x: 0, y: 0, width: 100, height: 1);
          final r = Layout.horizontal(kase.ct, flex: kase.f).split(rect);

          expect(r.map((c) => (c.x, c.width)), kase.expected);
        }
      });

      test('get areas from rect', () {
        final v = Layout.vertical(const [
          ConstraintLength(1),
          ConstraintMin(0),
        ]);
        final areas = v.areas(Rect.create(x: 0, y: 0, width: 5, height: 2));
        expect(areas.length, 2);
        expect(areas.first.toString(), 'Rect(0x0+5+1)');
        expect(areas.last.toString(), 'Rect(0x1+5+1)');
      });

      test('get spacers from rect', () {
        final v = Layout.horizontal(const [ConstraintMax(1), ConstraintMax(1)]);
        final areas = v.spacers(Rect.create(x: 0, y: 0, width: 5, height: 4));
        expect(areas.length, 3);
        expect(areas[0].toString(), 'Rect(0x0+0+4)');
        expect(areas[1].toString(), 'Rect(1x0+0+4)');
        expect(areas[2].toString(), 'Rect(2x0+3+4)');
      });

      test('copyWith', () {
        final v = Layout.vertical(const [
          ConstraintLength(1),
          ConstraintMin(0),
        ]);
        final v2 = v.copyWith(flex: Flex.center);
        expect(v2.flex, Flex.center);
        expect(v2.constraints, v.constraints);
      });
    }); // group split
  }); // group layout
}
