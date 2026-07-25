import 'package:kiko/kiko.dart';
import 'package:kiko_log/kiko_log.dart';

import '../../load/data_view.dart';
import '../../load/load.dart';
import '../../load/page_source.dart';
import '../../load/page_window.dart';
import '../row_region.dart';
import '../scrollable_model.dart';
import 'table_column.dart';
import 'types.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// State and update logic for TableView.
///
/// Handles cursor navigation, selection, scrolling, and paged data held in a
/// sliding window over large datasets.
///
/// The page is the unit of loading: each page gets its own load slot named by a
/// [TablePageKey], so several pages can be in flight at once, a result places
/// itself, and a page is never asked for twice while it is on its way. The model
/// performs no I/O — anything that moves the viewport runs a [demand] pass, which
/// returns a [LoadRequest] (or a [Batch] of them) for the pages the viewport
/// needs and does not have. The app fetches and hands each page back through
/// [applyLoad]. Implements [Loadable] for that hand-back.
///
/// Two obligations sit on the app, and both are one line:
///
/// - Answer **every** request — with rows, with an error, or with a refusal
///   built by `declineLoad`. A request left unanswered leaves its page painting
///   a placeholder forever, because the model will not ask again while it
///   believes the page is loading.
/// - Pump demand on the frame tick: `FrameTickMsg() => (model, model.table
///   .demandIfDirty())`. A terminal resize reveals rows through the paint path,
///   where a widget cannot return a command, so without that arm the rows a
///   taller terminal reveals are demanded by nobody. The model says so in the
///   log if it notices the arm missing.
///
/// A table over rows already in memory is one constructor call, and never meets
/// any of the loading machinery:
///
/// ```dart
/// final table = TableViewModel(
///   rows: employees,
///   keyField: 'id',
///   columns: [
///     TableColumn(field: 'id', label: Line('ID'), width: 10),
///     TableColumn(field: 'name', label: Line('Name'), width: 30),
///   ],
///   focused: true,
/// );
/// ```
///
/// A table that loads passes no rows at all — it asks for its first page and
/// fills from there.
class TableViewModel with ScrollableModel implements Component, Loadable {
  /// Stable address for this model, carried by value in the [TableActionCmd] it
  /// emits and the [LoadRequest] it returns when a page is needed.
  ///
  /// Auto-generated when omitted; pass an explicit id to match against a literal
  /// (`id == 'usersTable'`) or to disambiguate multiple instances.
  @override
  final String id;

  /// Field name for row identity.
  final String keyField;

  /// Column definitions.
  final List<TableColumn> columns;

  /// Rows per page load.
  final int pageSize;

  /// How many pages beyond the ones the viewport needs stay in memory.
  ///
  /// Retention is relative: the pages the viewport is asking for are always
  /// kept, and this many more survive on each side of them. That is what makes
  /// a load-evict-reload livelock unrepresentable — there is no absolute budget
  /// to accidentally set below what the screen needs. Zero is legal and means
  /// "keep what is on screen, re-fetch anything scrolled back to".
  final int keepPages;

  /// How far past the viewport, in rows, the table asks for pages.
  final int loadThreshold;

  /// How many page fetches the table will have outstanding at once.
  ///
  /// Only the widget's own requests are bounded; how the app schedules the I/O
  /// is its business. Correctness never depends on this value: every demand
  /// pass re-derives what is missing, so a pass truncated here is picked up by
  /// the next one. Lower it for a metered source, raise it for a fast local one.
  final int maxConcurrentLoads;

  /// Header pinned at top.
  final bool stickyHeader;

  /// Paints the full crosshair: a wash across the cursor's column, in
  /// addition to the cursor row wash and cursor cell fill that always paint.
  ///
  /// Off by default, matching the table's look before the crosshair existed:
  /// only the cursor row and the cursor cell are highlighted. Mutable so an
  /// app can offer a live toggle, the way it flips [focused].
  bool showCrosshair;

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

  /// Anatomy overrides. Mutable so an app can swap in a custom look at
  /// runtime, the way it flips [showCrosshair].
  TableViewStyle styles;

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  int _cursorRow = 0;
  int _cursorCol = 0;
  int _scrollRow = 0;
  int _scrollCol = 0;
  final Set<String> _selected = {};
  late final PageWindow<Map<String, Object?>> _window;
  int _visibleRows = 0;
  int _visibleCols = 0;

  /// The data row the pointer is hovering, or null when it is over the header or
  /// no row.
  ///
  /// Set from any pointer message the table receives and cleared when the pointer
  /// leaves. The renderer folds it into the hovered row's style as the weakest
  /// state, so a hovered selected or cursor row still reads selected or cursor.
  int? hoverRow;

  final _loads = LoadTracker<TablePageKey>();

  /// The pages whose fetches are outstanding. The tracker holds their state; this
  /// says which slots to count against [maxConcurrentLoads] and which to clear on
  /// a [reset].
  final Set<int> _inFlight = {};

  bool _demandDirty = false;
  int _paintsWhileDirty = 0;
  bool _pumpWarned = false;

  /// Paints with demand outstanding before the model suspects the app is missing
  /// its frame-tick arm. Half a second at 60fps — long enough that a fetch in
  /// progress never trips it.
  static const _pumpWarningPaints = 30;

  int? _totalCount;

  /// Whether this model has focus.
  @override
  bool focused;

  /// Key bindings for table actions.
  late final KeyBinding<TableViewAction> keyBinding;

  /// Creates a TableViewModel.
  ///
  /// Pass [rows] for a table over data already in memory: they seed the window
  /// as whole pages and, unless [totalCount] says otherwise, they are taken to
  /// be all of it. Pass [totalCount] alongside them to seed a first page of
  /// something larger, or on its own when a count fetch answered before the
  /// first page did. A table that loads everything can pass neither and learn
  /// where the data ends from the first short page.
  TableViewModel({
    required this.keyField,
    required this.columns,
    List<Map<String, Object?>>? rows,
    int? totalCount,
    String? id,
    this.pageSize = 50,
    this.keepPages = 4,
    this.loadThreshold = 10,
    this.maxConcurrentLoads = 3,
    this.stickyHeader = true,
    this.showCrosshair = false,
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
    _window = PageWindow<Map<String, Object?>>(pageSize: pageSize, keepPages: keepPages);
    if (rows != null) _window.seed(rows);
    this.totalCount = totalCount ?? rows?.length;
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
    final row = _window.rowAt(_cursorRow);
    if (row == null) return null;
    final key = row[keyField];
    return key?.toString();
  }

  /// Field name of current column.
  String get cursorColField => _visibleColumns[_cursorCol].field;

  /// Value at cursor cell.
  Object? get cursorCellValue => _window.rowAt(_cursorRow)?[cursorColField];

  /// Full row data at cursor.
  Map<String, Object?>? get cursorRowData => _window.rowAt(_cursorRow);

  // ─────────────────────────────────────────────
  // Getters - Selection
  // ─────────────────────────────────────────────

  /// Unordered set of selected row keys.
  Set<String> getSelectedKeys() => Set.unmodifiable(_selected);

  /// Check if row at index is selected.
  bool isSelected(int rowIndex) {
    final row = _window.rowAt(rowIndex);
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

  /// First visible row, aliasing [scrollRow] for the shared scroll surface.
  @override
  int get scrollOffset => _scrollRow;

  /// Rows the viewport shows, as last pushed in by the renderer.
  @override
  int get visibleCount => _visibleRows;

  /// Moves the viewport by [rows], clamped to [rowLimit] so the wheel never
  /// scrolls past where the data can reach. Returns rows actually moved (see
  /// [ScrollableModel.scrollBy]).
  @override
  int scrollBy(int rows) {
    final maxOffset = rowLimit - _visibleRows;
    final before = _scrollRow;
    _scrollRow = (_scrollRow + rows).clamp(0, maxOffset < 0 ? 0 : maxOffset);
    return _scrollRow - before;
  }

  // ─────────────────────────────────────────────
  // Getters - State
  // ─────────────────────────────────────────────

  /// Total row count, or null while it isn't known.
  ///
  /// Set it when a count fetch lands: the model uses it to bound navigation and
  /// to know which pages exist, so a table with a count can jump straight to the
  /// end and fetch the page it landed on.
  int? get totalCount => _totalCount;

  set totalCount(int? value) {
    _totalCount = value;
    if (value != null) _window.endAt(value <= 0 ? -1 : (value - 1) ~/ pageSize);
  }

  /// One past the last row the table can address: the total count when known,
  /// and never less than the last row actually held.
  ///
  /// Navigation, the wheel and the renderer's row loop all stop here. Without a
  /// count it reaches to the end of the loaded rows and of any page still on its
  /// way — so the rows a pending page will fill can paint their placeholders,
  /// while a table whose size nothing has revealed still cannot scroll into a
  /// void.
  int get rowLimit {
    var limit = 0;
    final pages = _window.present;
    if (pages.isNotEmpty) {
      limit = pages.last * pageSize + (_window.pageAt(pages.last)?.length ?? 0);
    }
    final known = knownRowCount;
    if (known != null) return known > limit ? known : limit;
    for (final page in _inFlight) {
      final end = (page + 1) * pageSize;
      if (end > limit) limit = end;
    }
    return limit;
  }

  /// How many rows exist, when that is known — from a total count, or from a
  /// short page that showed where the data ends. Null while it is unknown.
  int? get knownRowCount {
    if (_totalCount != null) return _totalCount;
    final last = _window.lastPage;
    if (last == null) return null;
    if (last < 0) return 0;
    final rows = _window.pageAt(last);
    return rows == null ? (last + 1) * pageSize : last * pageSize + rows.length;
  }

  /// Number of rows in the window.
  int get cachedRowCount => _window.rowCount;

  /// The pages currently held, ascending.
  List<int> get cachedPages => _window.present;

  /// Visible columns (filtered by visible flag).
  List<TableColumn> get _visibleColumns => columns.where((c) => c.visible).toList();

  /// Number of visible rows (set by widget).
  int get visibleRows => _visibleRows;

  /// Number of visible columns (set by widget).
  int get visibleCols => _visibleCols;

  // ─────────────────────────────────────────────
  // Load lifecycle
  // ─────────────────────────────────────────────

  /// Whether a page fetch is in flight — for [key] if given, otherwise for any
  /// page.
  bool isLoading([TablePageKey? key]) => key == null ? _inFlight.isNotEmpty : _inFlight.contains(key.page);

  /// The error from a failed load for [key], or null if it didn't fail.
  Object? errorFor(TablePageKey key) => _loads.errorFor(key);

  /// What the rows the table is about to paint amount to: all here, filling in,
  /// failed, or missing with nothing coming.
  ///
  /// Only pages that can exist count — rows past the end of the data are absent
  /// by definition, not missing.
  ///
  /// [SliceStatus.stalled] is the one worth watching. It names every way rows go
  /// permanently unpainted, so a test can assert it only ever happens while some
  /// other fetch is outstanding: a stall with nothing at all in flight is the
  /// stuck state, and a stall behind a fetch drains itself when that fetch lands
  /// and re-arms demand.
  SliceStatus get viewportStatus => _statusOf(_visibleSpan.pages.where(_window.exists));

  /// Whether a page above the viewport is being fetched — the fact a spinner
  /// over the top edge is driven from.
  bool get isLoadingAbove {
    final top = _window.pageOf(_scrollRow);
    return _statusOf(_demandSpan.pages.where((page) => page < top)) == SliceStatus.filling;
  }

  /// Whether a page below the viewport is being fetched — the fact a spinner
  /// under the bottom edge is driven from.
  bool get isLoadingBelow {
    final bottom = _window.pageOf(_scrollRow + (_visibleRows > 0 ? _visibleRows - 1 : 0));
    return _statusOf(_demandSpan.pages.where((page) => page > bottom)) == SliceStatus.filling;
  }

  /// The first row of the nearest run of [count] rows the window holds whole, or
  /// null when it holds no such run.
  ///
  /// This is what the table paints while a fetch is in flight instead of
  /// blanking: the closest complete stretch of rows to where the viewport is
  /// heading. Its own position is reported by [getScrollState], so the chrome
  /// stays honest about where the cursor actually is.
  int? nearestHeldStart(int count) {
    if (count <= 0) return null;
    final pages = _window.present;
    if (pages.isEmpty) return null;

    int? best;
    var runStart = pages.first;
    for (var i = 0; i < pages.length; i++) {
      final isLast = i == pages.length - 1;
      if (!isLast && pages[i + 1] == pages[i] + 1) continue;
      // pages[runStart..pages[i]] is a run of consecutive held pages.
      final firstRow = runStart * pageSize;
      final lastRow = pages[i] * pageSize + (_window.pageAt(pages[i])?.length ?? 0);
      if (lastRow - firstRow >= count) {
        final candidate = _scrollRow.clamp(firstRow, lastRow - count);
        if (best == null || (candidate - _scrollRow).abs() < (best - _scrollRow).abs()) best = candidate;
      }
      if (!isLast) runStart = pages[i + 1];
    }
    return best;
  }

  /// A read-only view over the cached rows.
  ///
  /// [DataView.length] is the total row count (null until known), and
  /// [DataView.hasMore] reports whether any page is still missing. Only rows in
  /// pages the window holds are readable: [DataView.itemAt] throws for a row in
  /// an absent page, so the widget reads through [getRow] to render holes as
  /// placeholders.
  DataView<Map<String, Object?>> get dataView => _dataView;
  late final _dataView = _TableDataView(this);

  /// Starts the initial page load: marks page 0 loading and returns the
  /// [LoadRequest] for the app to fetch.
  ///
  /// The app calls this once (e.g. on init), fetches the page named by the
  /// request's [TablePageKey], and installs the result via [applyLoad]. Every
  /// page after this one is asked for by [demand].
  LoadRequest loadFirstPage() {
    _beginLoad(0);
    return LoadRequest(id, key: const TablePageKey(0));
  }

  /// Asks for the pages the viewport needs and does not have.
  ///
  /// Returns a [LoadRequest] for one missing page, a [Batch] of them for
  /// several, or null when nothing is missing. Demand is presence over the whole
  /// window — the pages the viewport covers, reaching [loadThreshold] rows past
  /// each edge — rather than a step past whichever edge was last extended. That
  /// is what sends a long jump straight to its destination page, and what
  /// re-requests a page missing in the middle of the window instead of leaving
  /// it a permanent hole.
  ///
  /// The model calls this itself on every message that moves the viewport. An
  /// app calls it when its own state changes what it is willing to fetch — after
  /// a policy gate that was refusing requests lifts, say — since a refusal
  /// deliberately never re-triggers demand on its own.
  Cmd? demand() {
    _demandDirty = false;
    _paintsWhileDirty = 0;
    final budget = maxConcurrentLoads - _inFlight.length;
    if (budget <= 0) return null;
    final pages = _window.missing(_demandSpan, pending: _inFlight.contains, limit: budget);
    if (pages.isEmpty) return null;
    final requests = <Cmd>[];
    for (final page in pages) {
      _beginLoad(page);
      requests.add(LoadRequest(id, key: TablePageKey(page)));
    }
    return requests.length == 1 ? requests.first : Batch(requests);
  }

  /// Runs a [demand] pass only if something has changed what is missing, and
  /// returns whatever it asks for.
  ///
  /// This is the app's frame-tick arm: `FrameTickMsg() => (model, model.table
  /// .demandIfDirty())`. Three things arm it — the visible row count changing
  /// (a resize, which reaches the model through the paint path where no command
  /// can be returned), a page installing successfully (which frees a slot the
  /// in-flight cap may have truncated), and [markDemandDirty]. A refused or
  /// failed request arms nothing, which is what keeps a standing refusal from
  /// becoming a request every frame.
  Cmd? demandIfDirty() => _demandDirty ? demand() : null;

  /// Arms the next [demandIfDirty] pass.
  ///
  /// Call it from wherever an app's own gate lifts — a sync finishing, a filter
  /// clearing — when the pages it was refusing should now be fetched. It is the
  /// same recovery as calling [demand] directly, without a command to thread out
  /// of wherever that state lives.
  void markDemandDirty() => _demandDirty = true;

  /// Installs the outcome of a page load and clears (or fails) its slot.
  ///
  /// This is the app's single entry point for delivering a fetched page, keyed by
  /// page number ([TablePageKey]). A result for another model (by id), a non-page
  /// key, or a page that is no longer in flight (e.g. after a [reset]) is dropped
  /// rather than corrupting the window.
  ///
  /// On success the rows install as that page — a short page recording where the
  /// data ends — and pages the viewport no longer needs are evicted. A refusal
  /// clears the slot and installs nothing, so the page keeps its placeholders and
  /// is asked for again by the next demand pass. A failure records the error, and
  /// a later demand pass retries the page.
  @override
  void applyLoad(LoadResult<Object?> result) {
    if (result.id != id) return;
    final key = result.key;
    if (key is! TablePageKey) return;
    final page = key.page;
    // Staleness guard: only a page still in flight accepts a result.
    if (!_inFlight.contains(page)) return;
    if (result.cancelled) {
      _finishLoad(page);
      return;
    }
    if (result.ok) {
      // A page arrives either as plain rows or as the PageResult a PageSource
      // returns, which may also carry a count or an outright end-of-data.
      final data = result.data;
      final rows = switch (data) {
        PageResult<Map<String, Object?>>(:final items) => items,
        final List<Map<String, Object?>> list => list,
        _ => const <Map<String, Object?>>[],
      };
      _window.install(page, rows, demand: _demandSpan);
      if (data is PageResult<Map<String, Object?>>) {
        if (data.hasMore == false) _window.endAt(page);
        if (data.totalCount != null) totalCount = data.totalCount;
      }
      _finishLoad(page);
      // Progress: a slot is free and the window changed, so re-derive what is
      // still missing on the next tick. This is what drains a demand window the
      // in-flight cap truncated, with no input at all.
      markDemandDirty();
    } else {
      _finishLoad(page, error: result.error);
    }
  }

  // ─────────────────────────────────────────────
  // Setters for widget
  // ─────────────────────────────────────────────

  /// Called by widget during render to update visible dimensions.
  ///
  /// A change in the visible row count arms demand: a taller terminal reveals
  /// rows nobody has asked for, and this is where the model finds out — during
  /// paint, where it cannot return a command. The app's frame-tick arm picks it
  /// up on the next frame. If demand stays armed across many paints, the model
  /// says once, in the log, that the arm is probably missing.
  void setVisibleDimensions(int rows, int cols) {
    if (rows != _visibleRows) _demandDirty = true;
    _visibleRows = rows;
    _visibleCols = cols;
    if (!_demandDirty) {
      _paintsWhileDirty = 0;
      return;
    }
    _paintsWhileDirty++;
    if (_paintsWhileDirty > _pumpWarningPaints && !_pumpWarned) {
      _pumpWarned = true;
      Log.warn(
        'TableView "$id" has had pages to demand for $_paintsWhileDirty frames '
        'without a demand pass. Add the frame-tick arm to your update: '
        'FrameTickMsg() => (model, table.demandIfDirty())',
      );
    }
  }

  // ─────────────────────────────────────────────
  // Data management
  // ─────────────────────────────────────────────

  /// Installs [rows] into the window as whole pages, starting at [pageNum].
  ///
  /// This is the seeding path for rows an app already holds — a static table, or
  /// a first page fetched before the model existed. Rows are split at the page
  /// size, and nothing is evicted: a caller handing over data it already has
  /// means to keep it. Pages that arrive from a [LoadRequest] go through
  /// [applyLoad] instead, which is what evicts.
  void insertRows(List<Map<String, Object?>> rows, int pageNum) => _window.seed(rows, firstPage: pageNum);

  /// Get row at index from the window, or null if its page isn't held.
  Map<String, Object?>? getRow(int index) => _window.rowAt(index);

  /// Clear the window and reset state.
  void reset() {
    _window.clear();
    _cursorRow = 0;
    _cursorCol = 0;
    _scrollRow = 0;
    _scrollCol = 0;
    _selected.clear();
    for (final page in _inFlight) {
      _loads.complete(TablePageKey(page));
    }
    _inFlight.clear();
    _demandDirty = false;
    _paintsWhileDirty = 0;
    // A cleared window forgets where the data ends; a known total still says.
    totalCount = _totalCount;
  }

  /// The pages the viewport is painting right now, with no threshold reach.
  PageSpan get _visibleSpan => _window.spanFor(firstRow: _scrollRow, rowCount: _visibleRows);

  /// What [pages] amount to, as the shared load machinery sees them.
  SliceStatus _statusOf(Iterable<int> pages) =>
      statusFor(pages.map(TablePageKey.new), _loads, (key) => _window.has(key.page));

  /// The pages the viewport is asking for right now.
  PageSpan get _demandSpan => _window.spanFor(firstRow: _scrollRow, rowCount: _visibleRows, threshold: loadThreshold);

  void _beginLoad(int page) {
    _inFlight.add(page);
    _loads.begin(TablePageKey(page));
  }

  void _finishLoad(int page, {Object? error}) {
    _inFlight.remove(page);
    if (error == null) {
      _loads.complete(TablePageKey(page));
    } else {
      _loads.fail(TablePageKey(page), error);
    }
  }

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  /// Handles keyboard and pointer messages. Returns [Handled] or [Declined].
  ///
  /// The pointer branch sits above the focus gate, so a wheel scrolls, a click
  /// selects, and a hover highlights whether or not the table is focused. A wheel
  /// notch scrolls the viewport without touching the cursor, and scrolling runs a
  /// demand pass exactly as cursor navigation does; a notch that moves nothing in
  /// that direction (already at the edge) is declined, so a nesting scroll
  /// ancestor gets the chance. A button-down on a data row moves the cursor there
  /// and activates it, exactly as Enter does; any other pointer only refreshes the
  /// hovered row. A pointer on the header or off the rows is declined so the app
  /// can offer it to the next widget. The keyboard path stays behind the gate.
  ///
  /// Navigation is never frozen by a load: pages load in their own slots, so the
  /// cursor keeps moving and any number of pages can be on their way at once.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      if (pointer.wheelDeltaY != 0) {
        final moved = scrollBy(wheelScrollLines * pointer.wheelDeltaY);
        // Nothing moved in that direction (already at the edge) — decline so a
        // nesting scroll ancestor gets the notch; consuming at the limit would
        // make nesting permanently dead.
        if (moved == 0) return const Declined();
        return Handled(demand());
      }
      if (pointer.isWheel) return const Declined(); // a horizontal wheel is not ours

      // The part under the pointer is resolved by the framework and carried on
      // the message. A data row activates like Enter.
      final region = pointer.region;
      if (region is RowScoped) {
        return handleRowPointer(
          pointer,
          region.index,
          setHover: (r) => hoverRow = r,
          moveCursorTo: (r) {
            _cursorRow = r;
            _adjustScrollToCursor();
          },
          activate: () => TableActionCmd(id, 'primary'),
        );
      }
      if (region is TableHeaderRegion) {
        // Marked from day one so a future column sort hangs off the region
        // instead of new geometry. For now a press declines and bubbles,
        // exactly as before regions existed, and any pointer clears the hover.
        hoverRow = null;
        return pointer.isDown ? const Declined() : const Handled();
      }
      // No marked part — the empty-state line or the blank tail. A press
      // bubbles; a move clears the hover.
      if (pointer.isDown) return const Declined();
      hoverRow = null;
      return const Handled();
    }
    if (msg is PointerLeaveMsg) {
      hoverRow = null;
      return const Handled();
    }
    if (msg is PointerCancelMsg) return const Declined();

    if (!focused) return const Declined();

    if (msg case KeyMsg()) {
      final action = keyBinding.resolve(msg);
      if (action == null) return const Declined();

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
          _cursorRow = 0;
          _adjustScrollToCursor();
        case TableViewAction.end:
          _cursorRow = (rowLimit - 1).clamp(0, rowLimit);
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
          return Handled(TableActionCmd(id, 'primary'));
      }

      return Handled(demand());
    }

    return const Declined();
  }

  // ─────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────

  void _moveCursorRow(int delta) {
    final maxRow = (rowLimit - 1).clamp(0, 999999);
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
}

/// Read-only [DataView] over a table model's windowed row cache.
class _TableDataView implements DataView<Map<String, Object?>> {
  _TableDataView(this._model);

  final TableViewModel _model;

  @override
  int? get length => _model.totalCount;

  @override
  bool get hasMore {
    final last = _model._window.lastPage;
    if (last == null) return true;
    return _model._window.pageCount < last + 1;
  }

  @override
  Map<String, Object?> itemAt(int index) {
    final row = _model._window.rowAt(index);
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
