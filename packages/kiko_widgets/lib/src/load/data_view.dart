// ═══════════════════════════════════════════════════════════
// DATA VIEW (read) + DATA BUFFER (mutable backing)
// ═══════════════════════════════════════════════════════════

/// A read-only, synchronous window onto the items a widget displays.
///
/// A widget renders through this without knowing where the items come from —
/// a plain in-memory list, a page-by-page buffer, or values computed on the fly
/// all look the same to it. When it needs more, it asks the app to fetch them
/// rather than reaching for them here.
///
/// Reads never block: [itemAt] returns right away and must not wait on I/O.
/// If the next items aren't ready yet, the widget shows a placeholder and tracks
/// that as load state — it never blocks here waiting for them.
///
/// [DataBuffer] is the usual implementation; [fromList] wraps a fixed list.
abstract interface class DataView<T> {
  /// A view over a fixed [items] list that never loads more.
  static DataView<T> fromList<T>(List<T> items) => DataBuffer<T>(items);

  /// How many items there are, or null if that isn't known — an infinite or
  /// lazily computed source.
  int? get length;

  /// The item at [index], looked up or computed immediately — never awaiting.
  T itemAt(int index);

  /// Whether more items could be loaded. The widget reads this to decide when
  /// to ask the app for the next page; it never loads anything itself.
  bool get hasMore;
}

/// A growable, in-memory [DataView] that a widget fills as data arrives.
///
/// This is the everyday backing. Start it empty or seeded with a fixed list,
/// then [append] each page as it loads, or [replace] everything at once when the
/// data changes wholesale — like a search box swapping its results on every
/// keystroke.
///
/// Edits live here rather than on [DataView] so read-only sources (computed or
/// fixed views) aren't forced to implement them, and so nothing rendering
/// through the read view can change it by accident.
class DataBuffer<T> implements DataView<T> {
  /// Creates a buffer, optionally seeded with [seed]. Starts with [hasMore]
  /// false; set it after the first load if more pages remain.
  DataBuffer([Iterable<T>? seed]) : _items = [...?seed];

  final List<T> _items;
  bool _hasMore = false;

  @override
  int? get length => _items.length;

  @override
  T itemAt(int index) => _items[index];

  @override
  bool get hasMore => _hasMore;

  /// Adds [page] to the end.
  void append(Iterable<T> page) => _items.addAll(page);

  /// Swaps in [next], dropping everything currently held.
  void replace(Iterable<T> next) => _items
    ..clear()
    ..addAll(next);

  /// Removes all items.
  void clear() => _items.clear();

  /// Sets whether more items can still be loaded.
  set hasMore(bool value) => _hasMore = value;
}
