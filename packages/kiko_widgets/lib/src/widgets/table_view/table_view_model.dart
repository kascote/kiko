import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../../load/page_loader.dart';
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
/// [PageKey], so several pages can be in flight at once, a result places
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

  /// Rows per page. Fixed for the life of the model: page boundaries are index
  /// arithmetic, so every page except the last must contain exactly this many
  /// rows. A source that cannot promise that must re-chunk before answering
  /// (`PageSource.cursor` does).
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
  late final PageLoader<Map<String, Object?>> _loader;
  int _visibleRows = 0;
  int _visibleCols = 0;

  /// The data row the pointer is hovering, or null when it is over the header or
  /// no row.
  ///
  /// Set from any pointer message the table receives and cleared when the pointer
  /// leaves. The renderer folds it into the hovered row's style as the weakest
  /// state, so a hovered selected or cursor row still reads selected or cursor.
  int? hoverRow;

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
    _loader = PageLoader<Map<String, Object?>>(
      id: this.id,
      widgetName: 'TableView',
      firstRow: () => _scrollRow,
      visibleRows: () => _visibleRows,
      pageSize: pageSize,
      keepPages: keepPages,
      loadThreshold: loadThreshold,
      maxConcurrentLoads: maxConcurrentLoads,
    );
    if (rows != null) _loader.seed(rows);
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
    final row = _loader.rowAt(_cursorRow);
    if (row == null) return null;
    final key = row[keyField];
    return key?.toString();
  }

  /// Field name of current column.
  String get cursorColField => _visibleColumns[_cursorCol].field;

  /// Value at cursor cell.
  Object? get cursorCellValue => _loader.rowAt(_cursorRow)?[cursorColField];

  /// Full row data at cursor.
  Map<String, Object?>? get cursorRowData => _loader.rowAt(_cursorRow);

  // ─────────────────────────────────────────────
  // Getters - Selection
  // ─────────────────────────────────────────────

  /// Unordered set of selected row keys.
  Set<String> getSelectedKeys() => Set.unmodifiable(_selected);

  /// Check if row at index is selected.
  bool isSelected(int rowIndex) {
    final row = _loader.rowAt(rowIndex);
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
  int? get totalCount => _loader.totalCount;

  set totalCount(int? value) {
    _loader.totalCount = value;
    _clampToKnownEnd();
  }

  /// One past the last row the table can address: the total count when known,
  /// and never less than the last row actually held.
  ///
  /// Navigation, the wheel and the renderer's row loop all stop here. Without a
  /// count it reaches to the end of the loaded rows and of any page still on its
  /// way — so the rows a pending page will fill can paint their placeholders,
  /// while a table whose size nothing has revealed still cannot scroll into a
  /// void.
  int get rowLimit => _loader.rowLimit;

  /// How many rows exist, when that is known — from a total count, or from a
  /// short page that showed where the data ends. Null while it is unknown.
  int? get knownRowCount => _loader.knownRowCount;

  /// Number of rows in the window.
  int get cachedRowCount => _loader.cachedRowCount;

  /// The pages currently held, ascending.
  List<int> get cachedPages => _loader.cachedPages;

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
  bool isLoading([PageKey? key]) => _loader.isLoading(key);

  /// The error from a failed load for [key], or null if it didn't fail.
  Object? errorFor(PageKey key) => _loader.errorFor(key);

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
  SliceStatus get viewportStatus => _loader.viewportStatus;

  /// Whether a page above the viewport is being fetched — the fact a spinner
  /// over the top edge is driven from.
  bool get isLoadingAbove => _loader.isLoadingAbove;

  /// Whether a page below the viewport is being fetched — the fact a spinner
  /// under the bottom edge is driven from.
  bool get isLoadingBelow => _loader.isLoadingBelow;

  /// The first row of the nearest run of [count] rows the window holds whole, or
  /// null when it holds no such run.
  ///
  /// This is what the table paints while a fetch is in flight instead of
  /// blanking: the closest complete stretch of rows to where the viewport is
  /// heading. Its own position is reported by [getScrollState], so the chrome
  /// stays honest about where the cursor actually is.
  int? nearestHeldStart(int count) => _loader.nearestHeldStart(count);

  /// Starts the initial page load: marks page 0 loading and returns the
  /// [LoadRequest] for the app to fetch.
  ///
  /// The app calls this once (e.g. on init), fetches the page named by the
  /// request's [PageKey], and installs the result via [applyLoad]. Every
  /// page after this one is asked for by [demand].
  LoadRequest loadFirstPage() => _loader.loadFirstPage();

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
  Cmd? demand() => _loader.demand();

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
  Cmd? demandIfDirty() => _loader.demandIfDirty();

  /// Arms the next [demandIfDirty] pass.
  ///
  /// Call it from wherever an app's own gate lifts — a sync finishing, a filter
  /// clearing — when the pages it was refusing should now be fetched. It is the
  /// same recovery as calling [demand] directly, without a command to thread out
  /// of wherever that state lives.
  void markDemandDirty() => _loader.markDemandDirty();

  /// Installs the outcome of a page load and clears (or fails) its slot.
  ///
  /// This is the app's single entry point for delivering a fetched page, keyed by
  /// page number ([PageKey]). A result for another model (by id), a non-page
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
    if (_loader.apply(result)) _clampToKnownEnd();
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
    _visibleRows = rows;
    _visibleCols = cols;
    _loader.notePaint();
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
  void insertRows(List<Map<String, Object?>> rows, int pageNum) => _loader.seed(rows, firstPage: pageNum);

  /// Get row at index from the window, or null if its page isn't held.
  Map<String, Object?>? getRow(int index) => _loader.rowAt(index);

  /// Clear the window and reset state.
  void reset() {
    _cursorRow = 0;
    _cursorCol = 0;
    _scrollRow = 0;
    _scrollCol = 0;
    _selected.clear();
    _loader.reset();
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
  /// Confirming a row the window does not hold is consumed and emits nothing —
  /// the table understands the key and has nothing to act on.
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
          // A row the window does not hold cannot be activated: the cursor
          // still moves, the press stays consumed, and no command is emitted.
          activate: () => cursorRowData == null ? null : TableActionCmd(id, 'primary'),
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
          // A row the window does not hold cannot be confirmed: the key is
          // consumed — a declined confirm would fire the app's fallback
          // bindings — and no command is emitted.
          if (cursorRowData == null) return const Handled();
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

  /// Pulls the cursor and the viewport back when the end of the data lands
  /// closer than navigation had reached.
  ///
  /// Navigation may run ahead into pages still on their way. When the end then
  /// lands — a short page, or a total count — the rows past it stop existing,
  /// so the cursor clamps to the last row and the viewport clamps so that row
  /// sits on the bottom line. Only a known end clamps: a limit that shrank
  /// because a refusal resolved an in-flight page says nothing about which
  /// rows exist.
  void _clampToKnownEnd() {
    final known = knownRowCount;
    if (known == null) return;
    final maxRow = known - 1;
    if (_cursorRow > maxRow) _cursorRow = maxRow < 0 ? 0 : maxRow;
    final maxOffset = known - _visibleRows;
    if (_scrollRow > maxOffset) _scrollRow = maxOffset < 0 ? 0 : maxOffset;
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
