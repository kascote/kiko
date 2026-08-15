import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('segment validity', () {
    test('an id may not contain the path separator', () {
      expect(() => IdTag('a/b'), throwsA(isA<AssertionError>()));
    });

    test('a scope name may not contain the path separator', () {
      expect(() => ScopeTag('a/b'), throwsA(isA<AssertionError>()));
    });
  });

  group('HitTag.leafOf', () {
    test('returns the last segment of a path', () {
      expect(HitTag.leafOf('cb/field'), 'field');
      expect(HitTag.leafOf('a/b/c'), 'c');
    });

    test('returns an unscoped id unchanged', () {
      expect(HitTag.leafOf('field'), 'field');
    });
  });

  group('HitTag.isPrefix', () {
    test('a path is a prefix of itself', () {
      expect(HitTag.isPrefix('cb', of: 'cb'), isTrue);
    });

    test('an ancestor on the path is a prefix', () {
      expect(HitTag.isPrefix('cb', of: 'cb/field'), isTrue);
      expect(HitTag.isPrefix('a/b', of: 'a/b/c'), isTrue);
    });

    test('matching stops at segment boundaries', () {
      expect(HitTag.isPrefix('cb', of: 'cbx'), isFalse);
      expect(HitTag.isPrefix('cb', of: 'cbx/field'), isFalse);
    });

    test('a longer path is not a prefix of a shorter one', () {
      expect(HitTag.isPrefix('cb/field', of: 'cb'), isFalse);
    });
  });

  group('HitTag.resolve', () {
    test('an exact registration wins', () {
      expect(HitTag.resolve('cb/field', {'cb', 'cb/field'}), 'cb/field');
    });

    test('the longest registered prefix wins when there is no exact match', () {
      expect(HitTag.resolve('cb/field', {'cb'}), 'cb');
    });

    test('a deeper registration under the same path beats a shallower one', () {
      expect(HitTag.resolve('a/b/c', {'a', 'a/b'}), 'a/b');
    });

    test('matching respects segment boundaries', () {
      expect(HitTag.resolve('cbx/field', {'cb'}), isNull);
    });

    test('an unscoped path — no separator to climb from — matches only exactly', () {
      expect(HitTag.resolve('field', {'field'}), 'field');
      expect(HitTag.resolve('fieldx', {'field'}), isNull, reason: 'no shorter candidate to fall back to');
    });

    test('a scoped path still resolves to a shorter registered prefix', () {
      expect(HitTag.resolve('field/inner', {'field'}), 'field');
    });

    test('nothing registered along the path answers null', () {
      expect(HitTag.resolve('cb/field', {'elsewhere'}), isNull);
    });
  });

  group('equality', () {
    test('tags compare by case and segment', () {
      expect(IdTag('a'), IdTag('a'));
      expect(IdTag('a').hashCode, IdTag('a').hashCode);
      expect(IdTag('a'), isNot(IdTag('b')));
      expect(ScopeTag('a'), ScopeTag('a'));
      expect(ScopeTag('a').hashCode, ScopeTag('a').hashCode);
      expect(IdTag('a'), isNot(ScopeTag('a')));
    });
  });
}
