/// Data provider for TableView.
///
/// Abstract class for async/paged table data. Use [fromList] for simple cases.
abstract class TableDataSource {
  /// Get page of rows. Returns list of row maps.
  /// [pageNum] is 0-indexed.
  Future<List<Map<String, Object?>>> getPage(int pageNum, int pageSize);

  /// True if more pages can be loaded.
  bool get hasMore;

  /// Total row count, or null if unknown.
  int? get totalCount;

  /// Creates a simple data source from a list.
  static TableDataSource fromList(List<Map<String, Object?>> rows) => _ListTableAdapter(rows);
}

/// Simple adapter wrapping a list of rows.
class _ListTableAdapter implements TableDataSource {
  final List<Map<String, Object?>> _rows;

  _ListTableAdapter(this._rows);

  @override
  Future<List<Map<String, Object?>>> getPage(int pageNum, int pageSize) async {
    final start = pageNum * pageSize;
    if (start >= _rows.length) return [];
    final end = (start + pageSize).clamp(0, _rows.length);
    return _rows.sublist(start, end);
  }

  @override
  bool get hasMore => false;

  @override
  int? get totalCount => _rows.length;
}
