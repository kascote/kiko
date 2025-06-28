import 'package:kiko/src/shared/lru_cache.dart';
import 'package:test/test.dart';

void main() {
  group('LruCache', () {
    test('basic insertion and retrieval', () {
      final cache = LruCache<int, String>(2)
        ..set(1, 'one')
        ..set(2, 'two');

      expect(cache.get(1), 'one');
      expect(cache.get(2), 'two');
      expect(cache.length, 2);
    });

    test('eviction when capacity is exceeded', () {
      final cache = LruCache<int, String>(2)
        ..set(1, 'one')
        ..set(2, 'two')
        ..set(3, 'three');

      expect(cache.get(1), isNull);
      expect(cache.get(2), 'two');
      expect(cache.get(3), 'three');
    });

    test('accessing an item makes it the most recently used', () {
      final cache = LruCache<int, String>(2)
        ..set(1, 'one')
        ..set(2, 'two')
        ..set(2, 'two') // removed from eviction when exists and add again
        ..get(1) // Access 1 to make it most recently used
        ..set(3, 'three');

      expect(cache.get(1), 'one');
      expect(cache.get(2), isNull);
      expect(cache.get(3), 'three');
    });

    test('cache hit and miss statistics', () {
      final cache = LruCache<int, String>(2)
        ..set(1, 'one')
        ..set(2, 'two')
        ..get(1) // hit
        ..get(3); // miss

      final stats = cache.stats;
      expect(stats.hits, 1);
      expect(stats.misses, 1);
      expect(stats.ratio, 0.5);

      cache.clear();
      final s = cache.stats;
      expect(s.hits, 0);
      expect(s.misses, 0);
      expect(s.ratio, 0);
    });

    test('zero capacity cache', () {
      expect(() => LruCache<int, String>(0), throwsArgumentError);
    });

    test('negative capacity cache', () {
      expect(() => LruCache<int, String>(-1), throwsArgumentError);
    });
  });
}
