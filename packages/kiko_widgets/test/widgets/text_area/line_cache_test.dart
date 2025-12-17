import 'package:kiko_widgets/src/widgets/text_area/line_cache.dart';
import 'package:test/test.dart';

class CacheItemMock implements CacheItem {
  @override
  final String digest;

  const CacheItemMock(this.digest);

  // @override
  // bool operator ==(Object other) {
  //   if (identical(this, other)) return true;

  //   return other is CacheItemMock && other.digest == digest;
  // }

  // @override
  // int get hashCode => digest.hashCode;
}

void main() {
  test('missing hit', () {
    final cache = LineCache<CacheItemMock, String>(3);
    expect(cache.get(const CacheItemMock('foo')), isNull);
  });

  test('set values', () {
    const toCache = CacheItemMock('foo');
    final cache = LineCache<CacheItemMock, String>(5)..set(toCache, 'value1');
    expect(cache.get(toCache), 'value1');

    cache.set(toCache, 'newValue');
    expect(cache.get(toCache), 'newValue');

    expect(cache.get(const CacheItemMock('baz')), isNull);

    cache.set(const CacheItemMock('baz'), 'value2');
    expect(cache.get(const CacheItemMock('baz')), 'value2');
  });

  test('setup null values', () {
    final cache = LineCache<CacheItemMock, String?>(3)..set(const CacheItemMock('foo'), null);
    expect(cache.get(const CacheItemMock('baz')), isNull);
  });

  test('check eviction', () {
    final cache = LineCache<CacheItemMock, String>(2)
      ..set(const CacheItemMock('foo'), 'value1')
      ..set(const CacheItemMock('bar'), 'value2');

    expect(cache.get(const CacheItemMock('foo')), 'value1');
    expect(cache.get(const CacheItemMock('bar')), 'value2');

    cache.set(const CacheItemMock('qux'), 'value3');
    expect(cache.get(const CacheItemMock('foo')), isNull);
    expect(cache.get(const CacheItemMock('bar')), 'value2');
    expect(cache.get(const CacheItemMock('qux')), 'value3');
  });

  test('test eviction lru', () {
    final cache = LineCache<CacheItemMock, String>(2)
      ..set(const CacheItemMock('foo'), 'value1')
      ..set(const CacheItemMock('bar'), 'value2');

    // move value to the top LRU
    expect(cache.get(const CacheItemMock('foo')), 'value1');
    // set new value, the top is safe
    cache.set(const CacheItemMock('baz'), 'value3');

    expect(cache.get(const CacheItemMock('foo')), 'value1');
    expect(cache.get(const CacheItemMock('baz')), 'value3');
    // evicted
    expect(cache.get(const CacheItemMock('bar')), isNull);

    final s = cache.stats;
    expect(s.hits, 3);
    expect(s.misses, 1);
    expect(s.ratio, 0.75);
  });

  test('test upsert', () {
    final cache = LineCache<CacheItemMock, String>(2)
      ..upsert(const CacheItemMock('foo'), () => 'value1')
      ..upsert(const CacheItemMock('bar'), () => 'value2');

    expect(cache.get(const CacheItemMock('foo')), 'value1');
    expect(cache.get(const CacheItemMock('bar')), 'value2');

    cache.upsert(const CacheItemMock('foo'), () => 'newValue');
    expect(cache.get(const CacheItemMock('foo')), 'value1');

    cache.upsert(const CacheItemMock('baz'), () => 'value3');
    expect(cache.get(const CacheItemMock('foo')), 'value1');
    expect(cache.get(const CacheItemMock('baz')), 'value3');
    expect(cache.get(const CacheItemMock('bar')), isNull);
  });
}
