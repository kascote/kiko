import 'dart:collection';

/// Record returned by the cache stats.
typedef CacheStats = ({int hits, int misses, double ratio});

/// Implements a simple cache with a fixed capacity and LRU access.
/// The cache is indexed by a [K] and stores a value of type [V].
/// The cache is implemented as a map with a queue to track the order of access.
class LruCache<K, V> {
  /// The maximum number of items that can be stored in the cache.
  final int capacity;
  final Map<K, V> _cache = {};
  final Queue<K> _eviction = Queue<K>();
  // Performance tracking
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
    _eviction.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Returns the number of items currently stored in the cache.
  int get length => _eviction.length;

  /// Returns the value associated with the given [key] or `null` if the value
  /// is not in the cache.
  V? get(K key) {
    final cachedValue = _cache[key];
    if (cachedValue == null) {
      _misses++;
      return null;
    }

    _hits++;
    _eviction
      ..remove(key)
      ..addFirst(key);
    return cachedValue;
  }

  /// Sets the given [value] in the cache with the given [key].
  /// If the cache is full, the least recently used item is removed.
  V set(K key, V value) {
    if (_cache.containsKey(key)) {
      _eviction.remove(key);
    }

    if (_eviction.length >= capacity) {
      final last = _eviction.removeLast();
      _cache.remove(last);
    }

    _eviction.addFirst(key);
    _cache[key] = value;

    return value;
  }

  /// Returns a record containing cache hit and miss statistics.
  CacheStats get stats {
    final total = _hits + _misses;
    final ratio = total > 0 ? _hits / total : 0.0;
    return (hits: _hits, misses: _misses, ratio: ratio);
  }
}
