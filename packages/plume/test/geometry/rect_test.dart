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
