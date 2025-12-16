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

    test('stores null values correctly', () {
      final cache = LruCache<int, String?>(2)
        ..set(1, null)
        ..set(2, 'two');

      expect(cache.containsKey(1), isTrue);
      expect(cache.get(1), isNull);
      expect(cache.stats.hits, 1); // Should be hit, not miss
    });

    test('remove removes key and returns value', () {
      final cache = LruCache<int, String>(2)
        ..set(1, 'one')
        ..set(2, 'two');

      expect(cache.remove(1), 'one');
      expect(cache.containsKey(1), isFalse);
      expect(cache.length, 1);
      expect(cache.remove(99), isNull); // Non-existent key
    });

    test('containsKey does not affect LRU order', () {
      final cache = LruCache<int, String>(2)
        ..set(1, 'one')
        ..set(2, 'two')
        ..containsKey(1) // Should NOT make 1 most-recent
        ..set(3, 'three'); // Should evict 1, not 2

      expect(cache.get(1), isNull);
      expect(cache.get(2), 'two');
    });

    test('update existing key moves to most recent', () {
      final cache = LruCache<int, String>(2)
        ..set(1, 'one')
        ..set(2, 'two')
        ..set(1, 'ONE') // Update 1, should move to most-recent
        ..set(3, 'three'); // Should evict 2, not 1

      expect(cache.get(1), 'ONE');
      expect(cache.get(2), isNull);
      expect(cache.get(3), 'three');
    });

    test('capacity of 1', () {
      final cache = LruCache<int, String>(1)..set(1, 'one');

      expect(cache.get(1), 'one');

      cache.set(2, 'two');

      expect(cache.get(1), isNull);
      expect(cache.get(2), 'two');
      expect(cache.length, 1);
    });

    test('longer eviction sequence validates LRU order', () {
      final cache = LruCache<int, String>(3)
        ..set(1, 'a')
        ..set(2, 'b')
        ..set(3, 'c') // Order: 1, 2, 3 (1 is oldest)
        ..get(1) // Access 1, order: 2, 3, 1
        ..get(2) // Access 2, order: 3, 1, 2
        ..set(4, 'd'); // Evict 3 (oldest)

      expect(cache.get(3), isNull);
      expect(cache.get(1), 'a');
      expect(cache.get(2), 'b');
      expect(cache.get(4), 'd');
    });
  });
}
