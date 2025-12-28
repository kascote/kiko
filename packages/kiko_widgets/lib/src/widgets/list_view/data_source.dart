/// Data provider for ListView.
///
/// Unifies simple lists and dynamic/paged sources.
abstract class ListDataSource<T> {
  /// Total items, or null if unknown/infinite.
  int? get length;

  /// Item at index. May throw if out of bounds.
  T itemAt(int index);

  /// True if more data can be loaded (for pagination).
  bool get hasMore;

  /// Creates a simple data source from a list.
  static ListDataSource<T> fromList<T>(List<T> items) => _ListAdapter(items);
}

/// Simple adapter wrapping `List<T>`.
class _ListAdapter<T> implements ListDataSource<T> {
  final List<T> _items;
  _ListAdapter(this._items);

  @override
  int get length => _items.length;

  @override
  T itemAt(int index) => _items[index];

  @override
  bool get hasMore => false;
}
