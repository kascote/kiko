import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  group('Rect', () {
    test('exposes edges and derived geometry', () {
      const r = Rect(2, 3, 4, 5);
      expect(r.left, 2);
      expect(r.top, 3);
      expect(r.right, 6);
      expect(r.bottom, 8);
      expect(r.topLeft, const Offset(2, 3));
      expect(r.size, const Size(4, 5));
    });

    test('fromOriginSize builds from an offset and size', () {
      expect(Rect.fromOriginSize(const Offset(2, 3), const Size(4, 5)), const Rect(2, 3, 4, 5));
    });

    test('shift moves the origin and keeps the size', () {
      expect(const Rect(1, 1, 3, 2).shift(const Offset(4, 5)), const Rect(5, 6, 3, 2));
    });

    group('contains', () {
      const r = Rect(0, 0, 3, 2);

      test('includes the top-left corner', () {
        expect(r.contains(Offset.zero), isTrue);
      });

      test('includes the last interior cell', () {
        expect(r.contains(const Offset(2, 1)), isTrue);
      });

      test('excludes the right edge', () {
        expect(r.contains(const Offset(3, 0)), isFalse);
      });

      test('excludes the bottom edge', () {
        expect(r.contains(const Offset(0, 2)), isFalse);
      });

      test('excludes points left or above the origin', () {
        expect(r.contains(const Offset(-1, 0)), isFalse);
        expect(r.contains(const Offset(0, -1)), isFalse);
      });
    });

    group('isEmpty', () {
      test('is false for a positive rect', () {
        expect(const Rect(0, 0, 3, 2).isEmpty, isFalse);
      });

      test('is true when either dimension is zero', () {
        expect(const Rect(0, 0, 0, 2).isEmpty, isTrue);
        expect(const Rect(0, 0, 3, 0).isEmpty, isTrue);
      });
    });

    group('intersect', () {
      test('overlapping rects yield their shared region', () {
        expect(const Rect(0, 0, 4, 4).intersect(const Rect(2, 1, 4, 4)), const Rect(2, 1, 2, 3));
      });

      test('a nested rect is its own intersection with the outer', () {
        const outer = Rect(0, 0, 10, 10);
        const inner = Rect(2, 2, 3, 3);
        expect(outer.intersect(inner), inner);
      });

      test('disjoint rects intersect to an empty rect', () {
        expect(const Rect(0, 0, 2, 2).intersect(const Rect(5, 5, 2, 2)).isEmpty, isTrue);
      });

      test('edge-touching rects share no cells (half-open bounds)', () {
        // The first ends at column 2 (exclusive); the second starts at 2.
        expect(const Rect(0, 0, 2, 2).intersect(const Rect(2, 0, 2, 2)).isEmpty, isTrue);
      });
    });

    group('containsRect', () {
      const outer = Rect(0, 0, 10, 10);

      test('a fully nested rect is contained', () {
        expect(outer.containsRect(const Rect(2, 2, 3, 3)), isTrue);
      });

      test('a rect reaching the right/bottom edge is contained', () {
        expect(outer.containsRect(const Rect(6, 6, 4, 4)), isTrue);
      });

      test('a rect spilling past an edge is not contained', () {
        expect(outer.containsRect(const Rect(8, 8, 4, 4)), isFalse);
        expect(outer.containsRect(const Rect(-1, 0, 2, 2)), isFalse);
      });
    });

    test('equal rects are equal and share a hashCode', () {
      expect(const Rect(1, 2, 3, 4), const Rect(1, 2, 3, 4));
      expect(const Rect(1, 2, 3, 4).hashCode, const Rect(1, 2, 3, 4).hashCode);
      expect(const Rect(1, 2, 3, 4), isNot(const Rect(1, 2, 3, 5)));
    });

    test('toString is readable', () {
      expect(const Rect(1, 2, 3, 4).toString(), 'Rect(1, 2, 3, 4)');
    });
  });
}
