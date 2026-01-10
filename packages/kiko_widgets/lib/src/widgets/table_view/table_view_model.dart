import 'package:kiko/kiko.dart';

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
class TableViewModel implements Focusable {
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
  final Span columnSeparator;

  /// Shown while loading.
  final Line? loadingIndicator;

  /// Shown when no data.
  final Widget? emptyPlaceholder;

  /// Style configuration.
  final TableViewStyle styles;

  /// Called once on init to fetch total count.
  final Future<int?> Function()? fetchTotalCount;

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

  /// Loading in progress.
  bool isLoading = false;

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
    this.pageSize = 50,
    this.windowSize = 200,
    this.loadThreshold = 10,
    this.stickyHeader = true,
    this.selectionEnabled = false,
    this.ellipsis = '…',
    this.columnSeparator = const Span(' '),
    this.loadingIndicator,
    this.emptyPlaceholder,
    this.styles = const TableViewStyle(),
    KeyBinding<TableViewAction>? keyBinding,
    this.focused = false,
    this.fetchTotalCount,
  }) {
    this.keyBinding = keyBinding ?? defaultTableViewBindings.copy();
    totalCount = dataSource.totalCount;
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
  Set<String> get selectedKeys => Set.unmodifiable(_selected);

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
  TableScrollState get verticalScroll => TableScrollState(
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
    isLoading = false;
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
  Cmd? update(Msg msg) {
    if (!focused) return const Unhandled();
    if (isLoading) return null; // Ignore input while loading

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
          return TableActionCmd(this, 'primary');
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

    if (distToStart < loadThreshold && _loadedStart > 0) {
      return LoadPageCmd(this, direction: LoadDirection.backward);
    }
    if (distToEnd < loadThreshold && dataSource.hasMore) {
      return LoadPageCmd(this, direction: LoadDirection.forward);
    }
    return null;
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
