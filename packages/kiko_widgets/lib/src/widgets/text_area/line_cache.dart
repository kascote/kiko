import 'dart:collection';

/// An item that can be stored in a [LineCache].
/// The item must have a [digest] that is used as the key in the cache.
/// The [digest] must be unique for each item.
/// The [digest] must be stable for the lifetime of the item.
abstract class CacheItem {
  /// The unique identifier for the item.
  String get digest;
}

/// Record returned by the cache stats.
typedef CacheStats = ({int hits, int misses, double ratio});

/// Implements a simple cache with a fixed capacity and LRU access.
/// The cache is indexed by a [CacheItem] and stores a value of type [V].
/// The cache is implemented as a map with a queue to track the order of access.
class LineCache<T extends CacheItem, V> {
  /// The maximum number of items that can be stored in the cache.
  final int capacity;
  final Map<String, V> _cache = {};
  final Queue<String> _eviction = Queue<String>();
  // Performance tracking
  int _hits = 0;
  int _misses = 0;

  /// Creates a new cache with the given [capacity].
  LineCache(this.capacity);

  /// Returns the number of items currently stored in the cache.
  int get length => _eviction.length;

  /// Returns the value associated with the given [value] or `null` if the value
  /// is not in the cache.
  V? get(T value) {
    final key = value.digest;

    final cachedValue = _cache[key];
    if (cachedValue != null) {
      _hits++;
      _eviction
        ..remove(key)
        ..addFirst(key);
      return cachedValue;
    }

    _misses++;
    return null;
  }

  /// Sets the given [value] in the cache with the given [key].
  /// If the cache is full, the least recently used item is removed.
  V set(T key, V value) {
    final keyHash = key.digest;

    if (_cache.containsKey(keyHash)) {
      _eviction.remove(keyHash);
    }

    if (_eviction.length >= capacity) {
      final last = _eviction.removeLast();
      _cache.remove(last);
    }

    _eviction.addFirst(keyHash);
    _cache[keyHash] = value;

    return value;
  }

  /// Try to get the value associated with the given [key].
  /// If the value is not in the cache, the given [fx] function is called to
  /// create the value and store it in the cache.
  /// The created value is returned.
  V upsert(T key, V Function() fx) => get(key) ?? set(key, fx());

  /// Returns a record containing cache hit and miss statistics.
  CacheStats get stats {
    final total = _hits + _misses;
    final ratio = total > 0 ? _hits / total : 0.0;
    return (hits: _hits, misses: _misses, ratio: ratio);
  }
}
