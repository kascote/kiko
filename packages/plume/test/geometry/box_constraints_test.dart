import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  group('BoxConstraints', () {
    test('default is fully unbounded on the maximums', () {
      const c = BoxConstraints();
      expect(c.minW, 0);
      expect(c.minH, 0);
      expect(c.hasBoundedWidth, isFalse);
      expect(c.hasBoundedHeight, isFalse);
    });

    test('tight demands exactly the given size', () {
      final c = BoxConstraints.tight(const Size(4, 5));
      expect(c.hasTightWidth, isTrue);
      expect(c.hasTightHeight, isTrue);
      expect(c.biggest, const Size(4, 5));
      expect(c.smallest, const Size(4, 5));
    });

    test('loose allows zero up to the given size', () {
      final c = BoxConstraints.loose(const Size(4, 5));
      expect(c.smallest, Size.zero);
      expect(c.biggest, const Size(4, 5));
    });

    group('constrain', () {
      final c = BoxConstraints.loose(const Size(10, 8));

      test('leaves an in-range size untouched', () {
        expect(c.constrain(const Size(6, 4)), const Size(6, 4));
      });

      test('raises a size below the minimum', () {
        const tight = BoxConstraints(minW: 3, maxW: 10, minH: 2, maxH: 8);
        expect(tight.constrain(const Size(1, 1)), const Size(3, 2));
      });

      test('lowers a size above the maximum', () {
        expect(c.constrain(const Size(20, 20)), const Size(10, 8));
      });

      test('does not cap an unbounded axis', () {
        const c = BoxConstraints(minH: 1, maxH: 4);
        expect(c.constrain(const Size(9999, 2)), const Size(9999, 2));
      });
    });

    test('loosen drops the minimums and keeps the maximums', () {
      const c = BoxConstraints(minW: 3, maxW: 10, minH: 2, maxH: 8);
      expect(c.loosen(), const BoxConstraints(maxW: 10, maxH: 8));
    });

    group('deflate', () {
      test('shrinks bounds and minimums inward', () {
        const c = BoxConstraints(minW: 6, maxW: 10, minH: 4, maxH: 8);
        expect(c.deflate(2, 2), const BoxConstraints(minW: 4, maxW: 8, minH: 2, maxH: 6));
      });

      test('never drops a bound below zero', () {
        const c = BoxConstraints(minW: 1, maxW: 3, minH: 1, maxH: 3);
        expect(c.deflate(10, 10), const BoxConstraints(maxW: 0, maxH: 0));
      });

      test('leaves an unbounded axis unbounded', () {
        const c = BoxConstraints(maxH: 8);
        expect(c.deflate(2, 2).hasBoundedWidth, isFalse);
        expect(c.deflate(2, 2).maxH, 6);
      });
    });

    group('enforce', () {
      test('pulls bounds into the outer range', () {
        const inner = BoxConstraints(maxW: 100, maxH: 100);
        const outer = BoxConstraints(minW: 2, maxW: 10, minH: 3, maxH: 8);
        expect(inner.enforce(outer), const BoxConstraints(minW: 2, maxW: 10, minH: 3, maxH: 8));
      });

      test('adopts the outer maximum when this axis is unbounded', () {
        const inner = BoxConstraints(minH: 1);
        const outer = BoxConstraints(maxW: 10, maxH: 8);
        expect(inner.enforce(outer).maxW, 10);
      });
    });

    test('isSatisfiedBy checks every bound', () {
      const c = BoxConstraints(minW: 2, maxW: 6, minH: 1, maxH: 4);
      expect(c.isSatisfiedBy(const Size(4, 2)), isTrue);
      expect(c.isSatisfiedBy(const Size(1, 2)), isFalse);
      expect(c.isSatisfiedBy(const Size(4, 5)), isFalse);
    });

    test('equal constraints are equal and share a hashCode', () {
      expect(const BoxConstraints(minW: 1, maxW: 2), const BoxConstraints(minW: 1, maxW: 2));
      expect(const BoxConstraints(minW: 1, maxW: 2).hashCode, const BoxConstraints(minW: 1, maxW: 2).hashCode);
    });

    test('toString shows ranges and unbounded axes', () {
      expect(const BoxConstraints(minW: 1, maxW: 4, minH: 2).toString(), 'BoxConstraints(w: 1..4, h: 2..∞)');
    });
  });
}
