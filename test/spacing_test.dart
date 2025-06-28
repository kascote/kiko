import 'package:kiko/iterators.dart';
import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Spacing', () {
    test('creates Space when value is positive', () {
      final spacing = Spacing(10);
      expect(spacing, isA<Space>());
      expect(spacing.value, 10);
    });

    test('creates Overlap when value is negative', () {
      final spacing = Spacing(-10);
      expect(spacing, isA<Overlap>());
      expect(spacing.value, 10); // value is absolute
    });

    test('clamps value to i16Max', () {
      final spacing = Spacing(i16Max + 1);
      expect(spacing.value, i16Max);
    });

    test('clamps value to i16Min', () {
      final spacing = Spacing(i16Min - 1);
      expect(spacing.value, -i16Min); // value is absolute
    });

    test('equality and hashCode', () {
      final spacing1 = Spacing(10);
      final spacing2 = Spacing(10);
      final spacing3 = Spacing(-10);

      expect(spacing1, equals(spacing2));
      expect(spacing1.hashCode, equals(spacing2.hashCode));
      expect(spacing1, isNot(equals(spacing3)));
    });

    test('toString', () {
      expect(Spacing(10).toString(), 'Space(10)');
      expect(Spacing(-5).toString(), 'Overlap(5)');
    });

    test('equality', () {
      expect(Spacing(10), equals(Spacing(10)));
      expect(Spacing(-10), equals(Spacing(-10)));
      expect(Spacing(10), isNot(equals(Spacing(-10))));
    });
  });

  group('Space', () {
    test('toString returns correct format', () {
      final space = Space(10);
      expect(Space(-10).toString(), 'Space(10)');
      expect(space.toString(), 'Space(10)');
    });

    test('equality and hashCode', () {
      final space1 = Space(10);
      final space2 = Space(10);
      final space3 = Space(20);

      expect(space1, equals(space2));
      expect(space1.hashCode, equals(space2.hashCode));
      expect(space1, isNot(equals(space3)));
    });

    test('toString', () {
      expect(Space(10).toString(), 'Space(10)');
    });
  });

  group('Overlap', () {
    test('toString returns correct format', () {
      expect(Overlap(10).toString(), 'Overlap(10)');
      expect(Overlap(-10).toString(), 'Overlap(10)');
    });

    test('equality and hashCode', () {
      final overlap1 = Overlap(10);
      final overlap2 = Overlap(10);
      final overlap3 = Overlap(20);

      expect(overlap1, equals(overlap2));
      expect(overlap1.hashCode, equals(overlap2.hashCode));
      expect(overlap1, isNot(equals(overlap3)));
    });
  });
}
