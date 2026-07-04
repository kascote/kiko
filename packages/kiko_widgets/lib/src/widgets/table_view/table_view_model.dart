import 'package:kiko/kiko.dart';

import '../../load/data_view.dart';
import '../../load/load.dart';
import 'table_column.dart';
import 'table_data_source.dart';
import 'types.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// State and update logic for TableView.
///
/// Handles cursor navigation, selection, scrolling, and data caching
/// with sliding window for large datasets.
///
/// Tracks each page fetch — forward and backward — with its own load slot, so it
/// shows a loading row, recovers from a failed fetch, and never asks for the same
/// page twice. The model performs no I/O: a near-edge navigation returns a
/// [LoadRequest], and the app fetches the page and hands it back through
/// [applyLoad]. Implements [Loadable] for that hand-back.
///
/// ```dart
/// final table = TableViewModel(
///   dataSource: TableDataSource.fromList(rows),
///   keyField: 'id',
///   columns: [
///     TableColumn(field: 'id', label: Line('ID'), width: 10),
///     TableColumn(field: 'name', label: Line('Name'), width: 30),
///   ],
///   focused: true,
/// );
/// ```
class TableViewModel implements Component, Loadable {
  /// Stable address for this model, carried by value in the [TableActionCmd] it
  /// emits and the [LoadRequest] it returns when a page is needed.
  ///
  /// Auto-generated when omitted; pass an explicit id to match against a literal
  /// (`id == 'usersTable'`) or to disambiguate multiple instances.
  @override
  final String id;

  /// Data provider.
  final TableDataSource dataSource;

  /// Field name for row identity.
  final String keyField;

  /// Column definitions.
  final List<TableColumn> columns;

  /// Rows per page load.
  final int pageSize;

  /// Rows to keep in memory.
  final int windowSize;

  /// Emit LoadPageCmd when N rows from edge.
  final int loadThreshold;

  /// Header pinned at top.
  final bool stickyHeader;

  /// Allow row selection.
  final bool selectionEnabled;

  /// Truncation character.
  final String ellipsis;

  /// Separator between columns.
  final Text columnSeparator;

  /// Shown while loading.
  final Line? loadingIndicator;

  /// Shown when no data.
  final Line? emptyPlaceholder;

  /// Style configuration.
  final TableViewStyle styles;

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  int _cursorRow = 0;
  int _cursorCol = 0;
  int _scrollRow = 0;
  int _scrollCol = 0;
  final Set<String> _selected = {};
  final Map<int, Map<String, Object?>> _cache = {};
  int _loadedStart = 0;
  int _loadedEnd = 0;
  int _visibleRows = 0;
  int _visibleCols = 0;

  final _loads = LoadTracker<TableLoadKey>();
  final _pendingPage = <TableLoadKey, int>{};
  bool _hasMore = false;

  /// Total row count (set via async callback on init).
  int? totalCount;

  /// Whether this model has focus.
  @override
  bool focused;

  /// Key bindings for table actions.
  late final KeyBinding<TableViewAction> keyBinding;

  /// Creates a TableViewModel.
  TableViewModel({
    required this.dataSource,
    required this.keyField,
    required this.columns,
    String? id,
    this.pageSize = 50,
    this.windowSize = 200,
    this.loadThreshold = 10,
    this.stickyHeader = true,
    this.selectionEnabled = false,
    this.ellipsis = '…',
    this.columnSeparator = const Text(' '),
    this.loadingIndicator,
    this.emptyPlaceholder,
    this.styles = const TableViewStyle(),
    KeyBinding<TableViewAction>? keyBinding,
    this.focused = false,
  }) : id = id ?? autoId('tableview') {
    this.keyBinding = keyBinding ?? defaultTableViewBindings.copy();
    totalCount = dataSource.totalCount;
    _hasMore = dataSource.hasMore;
  }

  // ─────────────────────────────────────────────
  // Getters - Cursor
  // ─────────────────────────────────────────────

  /// Current row index (0-based within loaded data).
  int get cursorRow => _cursorRow;

  /// Current column index.
  int get cursorCol => _cursorCol;

  /// Key of current row, or null if no row at cursor.
  String? get cursorRowKey {
    final row = _cache[_cursorRow];
    if (row == null) return null;
    final key = row[keyField];
    return key?.toString();
  }

  /// Field name of current column.
  String get cursorColField => _visibleColumns[_cursorCol].field;

  /// Value at cursor cell.
  Object? get cursorCellValue {
    final row = _cache[_cursorRow];
    if (row == null) return null;
    return row[cursorColField];
  }

  /// Full row data at cursor.
  Map<String, Object?>? get cursorRowData => _cache[_cursorRow];

  // ─────────────────────────────────────────────
  // Getters - Selection
  // ─────────────────────────────────────────────

  /// Unordered set of selected row keys.
  Set<String> getSelectedKeys() => Set.unmodifiable(_selected);

  /// Check if row at index is selected.
  bool isSelected(int rowIndex) {
    final row = _cache[rowIndex];
    if (row == null) return false;
    final key = row[keyField]?.toString();
    return key != null && _selected.contains(key);
  }

  // ─────────────────────────────────────────────
  // Getters - Scroll
  // ─────────────────────────────────────────────

  /// Vertical scroll state for external scrollbar.
  TableScrollState getScrollState() => TableScrollState(
    offset: _scrollRow,
    visible: _visibleRows,
    total: totalCount,
  );

  /// First visible column index.
  int get horizontalScrollCol => _scrollCol;

  /// Total visible column count.
  int get totalColumns => _visibleColumns.length;

  /// Current scroll row offset.
  int get scrollRow => _scrollRow;

  /// Current scroll column offset.
  int get scrollCol => _scrollCol;

  // ─────────────────────────────────────────────
  // Getters - State
  // ─────────────────────────────────────────────

  /// Loaded row range (start, end exclusive).
  (int, int) get loadedRange => (_loadedStart, _loadedEnd);

  /// Number of rows in cache.
  int get cachedRowCount => _cache.length;

  /// Visible columns (filtered by visible flag).
  List<TableColumn> get _visibleColumns => columns.where((c) => c.visible).toList();

  /// Number of visible rows (set by widget).
  int get visibleRows => _visibleRows;

  /// Number of visible columns (set by widget).
  int get visibleCols => _visibleCols;

  // ─────────────────────────────────────────────
  // Load lifecycle
  // ─────────────────────────────────────────────

  /// Whether a page fetch is in flight — for [key] if given, otherwise for
  /// either direction.
  bool isLoading([TableLoadKey? key]) => _loads.isLoading(key);

  /// The error from a failed load for [key], or null if it didn't fail.
  Object? errorFor(TableLoadKey key) => _loads.errorFor(key);

  /// The page number the model reserved for [key]'s pending load, or null if no
  /// load is pending in that direction.
  ///
  /// The app reads this to fetch the right page; [applyLoad] uses the same
  /// reservation to place the result, so the two never disagree even when a
  /// forward and backward load overlap.
  int? pendingPage(TableLoadKey key) => _pendingPage[key];

  /// A read-only view over the cached rows.
  ///
  /// [DataView.length] is the total row count (null until known), and
  /// [DataView.hasMore] reports whether more pages remain. Only rows currently in
  /// the window are readable: [DataView.itemAt] throws for a windowed-out row, so
  /// the widget reads through [getRow] to render holes as loading placeholders.
  DataView<Map<String, Object?>> get dataView => _dataView;
  late final _dataView = _TableDataView(this);

  /// Starts the initial page load: marks the forward slot loading and returns the
  /// [LoadRequest] for the app to fetch (page 0).
  ///
  /// The app calls this once (e.g. on init), turns the request into a
  /// `getPage(0, …)` fetch, and installs the result via [applyLoad]. Until then
  /// `isLoading(TableLoadKey.forward)` is true.
  LoadRequest loadFirstPage() {
    _loads.begin(TableLoadKey.forward);
    _pendingPage[TableLoadKey.forward] = 0;
    return LoadRequest(id, key: TableLoadKey.forward);
  }

  /// Installs the outcome of a page load and clears (or fails) its slot.
  ///
  /// This is the app's single entry point for delivering a fetched page, keyed by
  /// direction ([TableLoadKey.forward] / [TableLoadKey.backward]). A result for
  /// another model (by id), a non-table key, or a slot that is no longer loading
  /// (e.g. after a [reset]) is dropped rather than corrupting the cache.
  ///
  /// On success the rows are inserted at the page the request reserved, and a
  /// forward load updates [DataView.hasMore] from the page size — a short page is
  /// the last. On failure the slot records the error; a later near-edge
  /// navigation retries it.
  @override
  void applyLoad(LoadResult<Object?> result) {
    if (result.id != id) return;
    final key = result.key;
    if (key is! TableLoadKey) return;
    // Staleness guard: only a slot still in flight accepts a result.
    if (!_loads.isLoading(key)) return;
    final page = _pendingPage.remove(key);
    if (result.ok) {
      final rows = (result.data as List<Map<String, Object?>>?) ?? const <Map<String, Object?>>[];
      if (page != null) insertRows(rows, page);
      if (key == TableLoadKey.forward) _hasMore = rows.length >= pageSize;
      _loads.complete(key);
    } else {
      _loads.fail(key, result.error!);
    }
  }

  // ─────────────────────────────────────────────
  // Setters for widget
  // ─────────────────────────────────────────────

  /// Called by widget during render to update visible dimensions.
  void setVisibleDimensions(int rows, int cols) {
    _visibleRows = rows;
    _visibleCols = cols;
  }

  // ─────────────────────────────────────────────
  // Data management
  // ─────────────────────────────────────────────

  /// Insert rows into cache at page position.
  void insertRows(List<Map<String, Object?>> rows, int pageNum) {
    final startIdx = pageNum * pageSize;
    for (var i = 0; i < rows.length; i++) {
      _cache[startIdx + i] = rows[i];
    }
    _updateLoadedRange();
    _evictIfNeeded();
  }

  /// Get row at index from cache.
  Map<String, Object?>? getRow(int index) => _cache[index];

  /// Clear cache and reset state.
  void reset() {
    _cache.clear();
    _cursorRow = 0;
    _cursorCol = 0;
    _scrollRow = 0;
    _scrollCol = 0;
    _selected.clear();
    _loadedStart = 0;
    _loadedEnd = 0;
    _loads
      ..complete(TableLoadKey.forward)
      ..complete(TableLoadKey.backward);
    _pendingPage.clear();
    _hasMore = dataSource.hasMore;
  }

  void _updateLoadedRange() {
    if (_cache.isEmpty) {
      _loadedStart = 0;
      _loadedEnd = 0;
      return;
    }
    _loadedStart = _cache.keys.reduce((a, b) => a < b ? a : b);
    _loadedEnd = _cache.keys.reduce((a, b) => a > b ? a : b) + 1;
  }

  void _evictIfNeeded() {
    while (_cache.length > windowSize) {
      // Find row furthest from cursor
      int? furthest;
      var maxDist = 0;
      for (final idx in _cache.keys) {
        final dist = (idx - _cursorRow).abs();
        if (dist > maxDist) {
          maxDist = dist;
          furthest = idx;
        }
      }
      if (furthest != null) {
        _cache.remove(furthest);
      }
    }
    _updateLoadedRange();
  }

  /// Next page number to load (forward direction).
  int get nextPageNum => _loadedEnd ~/ pageSize;

  /// Previous page number to load (backward direction).
  int get prevPageNum => (_loadedStart ~/ pageSize) - 1;

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  /// Handles keyboard messages. Returns command or [Unhandled].
  ///
  /// Navigation is never frozen by a load: a fetch in flight only stops the same
  /// direction from being requested again, so the cursor keeps moving and a
  /// forward and backward page can load at once.
  @override
  Cmd? update(Msg msg) {
    if (!focused) return const Unhandled();

    if (msg case KeyMsg()) {
      final action = keyBinding.resolve(msg);
      if (action == null) return const Unhandled();

      switch (action) {
        case TableViewAction.up:
          _moveCursorRow(-1);
        case TableViewAction.down:
          _moveCursorRow(1);
        case TableViewAction.left:
          _moveCursorCol(-1);
        case TableViewAction.right:
          _moveCursorCol(1);
        case TableViewAction.pageUp:
          _moveCursorRow(-_visibleRows.clamp(1, 100));
        case TableViewAction.pageDown:
          _moveCursorRow(_visibleRows.clamp(1, 100));
        case TableViewAction.home:
          _cursorRow = _loadedStart;
          _adjustScrollToCursor();
        case TableViewAction.end:
          _cursorRow = (_loadedEnd - 1).clamp(0, _loadedEnd);
          _adjustScrollToCursor();
        case TableViewAction.firstCol:
          _cursorCol = 0;
          _adjustHorizontalScroll();
        case TableViewAction.lastCol:
          _cursorCol = (_visibleColumns.length - 1).clamp(0, 999);
          _adjustHorizontalScroll();
        case TableViewAction.toggleSelect:
          if (selectionEnabled) _toggleSelectAtCursor();
        case TableViewAction.confirm:
          return TableActionCmd(id, 'primary');
      }

      return _checkLoadThreshold();
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────

  void _moveCursorRow(int delta) {
    final maxRow = totalCount != null ? (totalCount! - 1).clamp(0, 999999) : (_loadedEnd - 1).clamp(0, 999999);
    _cursorRow = (_cursorRow + delta).clamp(0, maxRow);
    _adjustScrollToCursor();
  }

  void _moveCursorCol(int delta) {
    final maxCol = (_visibleColumns.length - 1).clamp(0, 999);
    _cursorCol = (_cursorCol + delta).clamp(0, maxCol);
    _adjustHorizontalScroll();
  }

  void _adjustScrollToCursor() {
    if (_visibleRows <= 0) return;

    // Cursor above visible area
    if (_cursorRow < _scrollRow) {
      _scrollRow = _cursorRow;
    }
    // Cursor below visible area
    else if (_cursorRow >= _scrollRow + _visibleRows) {
      _scrollRow = _cursorRow - _visibleRows + 1;
    }
  }

  void _adjustHorizontalScroll() {
    if (_visibleCols <= 0) return;

    // Cursor left of visible area
    if (_cursorCol < _scrollCol) {
      _scrollCol = _cursorCol;
    }
    // Cursor right of visible area
    else if (_cursorCol >= _scrollCol + _visibleCols) {
      _scrollCol = _cursorCol - _visibleCols + 1;
    }
  }

  void _toggleSelectAtCursor() {
    final key = cursorRowKey;
    if (key == null) return;

    if (_selected.contains(key)) {
      _selected.remove(key);
    } else {
      _selected.add(key);
    }
  }

  Cmd? _checkLoadThreshold() {
    if (_cache.isEmpty) return null;

    final distToStart = _cursorRow - _loadedStart;
    final distToEnd = _loadedEnd - _cursorRow;

    // Near the start: pull the previous page, unless one is already on its way.
    if (distToStart < loadThreshold && _loadedStart > 0 && !_loads.isLoading(TableLoadKey.backward)) {
      final page = prevPageNum;
      if (page >= 0) {
        _loads.begin(TableLoadKey.backward);
        _pendingPage[TableLoadKey.backward] = page;
        return LoadRequest(id, key: TableLoadKey.backward);
      }
    }
    // Near the end: pull the next page, unless one is already on its way.
    if (distToEnd < loadThreshold && _hasMore && !_loads.isLoading(TableLoadKey.forward)) {
      final page = nextPageNum;
      _loads.begin(TableLoadKey.forward);
      _pendingPage[TableLoadKey.forward] = page;
      return LoadRequest(id, key: TableLoadKey.forward);
    }
    return null;
  }
}

/// Read-only [DataView] over a table model's windowed row cache.
class _TableDataView implements DataView<Map<String, Object?>> {
  _TableDataView(this._model);

  final TableViewModel _model;

  @override
  int? get length => _model.totalCount;

  @override
  bool get hasMore => _model._hasMore;

  @override
  Map<String, Object?> itemAt(int index) {
    final row = _model._cache[index];
    if (row == null) {
      throw StateError(
        'TableView row $index is not loaded; the windowed view exposes only '
        'cached rows. Use getRow for hole-tolerant access.',
      );
    }
    return row;
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// Default key bindings for TableView.
final defaultTableViewBindings = KeyBinding<TableViewAction>()
  ..map(['up', 'k'], TableViewAction.up)
  ..map(['down', 'j'], TableViewAction.down)
  ..map(['left', 'h'], TableViewAction.left)
  ..map(['right', 'l'], TableViewAction.right)
  ..map(['pageUp'], TableViewAction.pageUp)
  ..map(['pageDown'], TableViewAction.pageDown)
  ..map(['home'], TableViewAction.home)
  ..map(['end'], TableViewAction.end)
  ..map(['ctrl+left'], TableViewAction.firstCol)
  ..map(['ctrl+right'], TableViewAction.lastCol)
  ..map(['space'], TableViewAction.toggleSelect)
  ..map(['enter'], TableViewAction.confirm);
