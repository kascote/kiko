/// Record returned by the cache stats.
typedef CacheStats = ({int hits, int misses, double ratio});

/// Implements a simple cache with a fixed capacity and LRU access.
/// Uses insertion-order map for O(1) access and eviction.
class LruCache<K, V> {
  /// The maximum number of items that can be stored in the cache.
  final int capacity;
  final _cache = <K, V>{};
  int _hits = 0;
  int _misses = 0;

  /// Creates a new cache with the given [capacity].
  LruCache(this.capacity) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must be greater than 0');
    }
  }

  /// Removes all items from the cache.
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Returns the number of items currently stored in the cache.
  int get length => _cache.length;

  /// Returns whether [key] exists in the cache (does not affect LRU order).
  bool containsKey(K key) => _cache.containsKey(key);

  /// Returns the value associated with [key] or `null` if not present.
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      _misses++;
      return null;
    }
    _hits++;
    final value = _cache.remove(key) as V;
    _cache[key] = value; // Move to end (most recent)
    return value;
  }

  /// Sets [value] for [key]. Evicts LRU item if at capacity.
  V set(K key, V value) {
    _cache.remove(key); // Remove if exists to update position
    if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first); // Evict oldest
    }
    _cache[key] = value;
    return value;
  }

  /// Removes [key] from cache. Returns the removed value or `null`.
  V? remove(K key) => _cache.remove(key);

  /// Returns cache hit/miss statistics.
  CacheStats get stats {
    final total = _hits + _misses;
    return (hits: _hits, misses: _misses, ratio: total > 0 ? _hits / total : 0.0);
  }
}
