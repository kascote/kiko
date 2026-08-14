import 'package:kiko/kiko.dart';
import 'package:kiko_log/kiko_log.dart';

import 'load.dart';
import 'page_source.dart';
import 'page_window.dart';

// ═══════════════════════════════════════════════════════════
// PAGE LOADER
// ═══════════════════════════════════════════════════════════

/// The loading half of a windowed widget: a [PageWindow], a load slot per
/// page, and the demand pass that asks for the pages the viewport needs.
///
/// A widget model holds one and delegates to it. The loader performs no I/O:
/// [demand] returns [LoadRequest]s for the app to fetch, and [apply] installs
/// the [LoadResult]s that come home. Two callbacks given at construction read
/// the owner's scroll offset and visible row count, so every pass measures the
/// viewport the owner is actually showing.
///
/// The page is the unit of loading: each page gets its own slot named by a
/// [PageKey], so several pages can be in flight at once, a result places
/// itself, and a page is never asked for twice while it is on its way.
class PageLoader<T> {
  /// Creates a loader for the widget addressed by [id].
  ///
  /// [firstRow] and [visibleRows] read the owner's scroll offset and visible
  /// row count. [widgetName] names the owner's type in the log, nothing more.
  PageLoader({
    required this.id,
    required this.widgetName,
    required int Function() firstRow,
    required int Function() visibleRows,
    required this.pageSize,
    this.keepPages = 4,
    this.loadThreshold = 10,
    this.maxConcurrentLoads = 3,
  }) : _firstRow = firstRow,
       _visibleRows = visibleRows,
       _window = PageWindow<T>(pageSize: pageSize, keepPages: keepPages);

  /// The owning widget's stable address, carried by every [LoadRequest] the
  /// loader returns.
  final String id;

  /// The owning widget's type name, used when the loader writes to the log.
  final String widgetName;

  /// Rows per page. Fixed for the life of the loader: page boundaries are
  /// index arithmetic, so every page except the last must contain exactly
  /// this many rows. A source that cannot promise that must re-chunk before
  /// answering ([PageSource.cursor] does).
  final int pageSize;

  /// How many pages beyond the ones the viewport needs stay in memory.
  ///
  /// Retention is relative: the pages the viewport is asking for are always
  /// kept, and this many more survive on each side of them. That is what makes
  /// a load-evict-reload livelock unrepresentable — there is no absolute budget
  /// to accidentally set below what the screen needs. Zero is legal and means
  /// "keep what is on screen, re-fetch anything scrolled back to".
  final int keepPages;

  /// How far past the viewport, in rows, the demand pass asks for pages.
  final int loadThreshold;

  /// How many page fetches the loader will have outstanding at once.
  ///
  /// Only the widget's own requests are bounded; how the app schedules the I/O
  /// is its business. Correctness never depends on this value: every demand
  /// pass re-derives what is missing, so a pass truncated here is picked up by
  /// the next one. Lower it for a metered source, raise it for a fast local
  /// one.
  final int maxConcurrentLoads;

  final int Function() _firstRow;
  final int Function() _visibleRows;
  final PageWindow<T> _window;
  final _loads = LoadTracker<PageKey>();

  /// The pages whose fetches are outstanding. The tracker holds their state;
  /// this says which slots to count against [maxConcurrentLoads] and which to
  /// clear on a [reset].
  final Set<int> _inFlight = {};

  bool _demandDirty = false;
  int _paintsWhileDirty = 0;
  bool _pumpWarned = false;
  int _lastPaintedRows = 0;

  /// Paints with demand outstanding before the loader suspects the app is
  /// missing its frame-tick arm. Half a second at 60fps — long enough that a
  /// fetch in progress never trips it.
  static const _pumpWarningPaints = 30;

  int? _totalCount;

  // ─────────────────────────────────────────────
  // Reading
  // ─────────────────────────────────────────────

  /// The row at absolute [index], or null if the window does not hold it.
  T? rowAt(int index) => _window.rowAt(index);

  /// Total row count, or null while it isn't known.
  ///
  /// Set it when a count fetch lands: the loader uses it to bound navigation
  /// and to know which pages exist, so a widget with a count can jump straight
  /// to the end and fetch the page it landed on.
  int? get totalCount => _totalCount;

  set totalCount(int? value) {
    _totalCount = value;
    if (value != null) _window.endAt(value <= 0 ? -1 : (value - 1) ~/ pageSize);
  }

  /// One past the last row the owner can address: the total count when known,
  /// and never less than the last row actually held.
  ///
  /// Navigation, the wheel and the row loop of a renderer all stop here.
  /// Without a count it reaches to the end of the loaded rows and of any page
  /// still on its way — so the rows a pending page will fill can paint their
  /// placeholders, while a widget whose size nothing has revealed still cannot
  /// scroll into a void.
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

  /// Number of rows the window holds.
  int get cachedRowCount => _window.rowCount;

  /// The pages currently held, ascending.
  List<int> get cachedPages => _window.present;

  // ─────────────────────────────────────────────
  // Load state
  // ─────────────────────────────────────────────

  /// Whether a page fetch is in flight — for [key] if given, otherwise for any
  /// page.
  bool isLoading([PageKey? key]) => key == null ? _inFlight.isNotEmpty : _inFlight.contains(key.page);

  /// The error from a failed load for [key], or null if it didn't fail.
  Object? errorFor(PageKey key) => _loads.errorFor(key);

  /// What the rows the owner is about to paint amount to: all here, filling
  /// in, failed, or missing with nothing coming.
  ///
  /// Only pages that can exist count — rows past the end of the data are
  /// absent by definition, not missing.
  ///
  /// [SliceStatus.stalled] is the one worth watching. It names every way rows
  /// go permanently unpainted, so a test can assert it only ever happens while
  /// some other fetch is outstanding: a stall with nothing at all in flight is
  /// the stuck state, and a stall behind a fetch drains itself when that fetch
  /// lands and re-arms demand.
  SliceStatus get viewportStatus => _statusOf(_visibleSpan.pages.where(_window.exists));

  /// Whether a page above the viewport is being fetched — the fact a spinner
  /// over the top edge is driven from.
  bool get isLoadingAbove {
    final top = _window.pageOf(_firstRow());
    return _statusOf(_demandSpan.pages.where((page) => page < top)) == SliceStatus.filling;
  }

  /// Whether a page below the viewport is being fetched — the fact a spinner
  /// under the bottom edge is driven from.
  bool get isLoadingBelow {
    final rows = _visibleRows();
    final bottom = _window.pageOf(_firstRow() + (rows > 0 ? rows - 1 : 0));
    return _statusOf(_demandSpan.pages.where((page) => page > bottom)) == SliceStatus.filling;
  }

  /// The first row of the nearest run of [count] rows the window holds whole,
  /// or null when it holds no such run.
  ///
  /// This is what a renderer paints while a fetch is in flight instead of
  /// blanking: the closest complete stretch of rows to where the viewport is
  /// heading. The owner keeps reporting its true scroll position, so external
  /// chrome stays honest about where the cursor actually is.
  int? nearestHeldStart(int count) {
    if (count <= 0) return null;
    final pages = _window.present;
    if (pages.isEmpty) return null;

    final firstRow = _firstRow();
    int? best;
    var runStart = pages.first;
    for (var i = 0; i < pages.length; i++) {
      final isLast = i == pages.length - 1;
      if (!isLast && pages[i + 1] == pages[i] + 1) continue;
      // pages[runStart..pages[i]] is a run of consecutive held pages.
      final runFirst = runStart * pageSize;
      final runLast = pages[i] * pageSize + (_window.pageAt(pages[i])?.length ?? 0);
      if (runLast - runFirst >= count) {
        final candidate = firstRow.clamp(runFirst, runLast - count);
        if (best == null || (candidate - firstRow).abs() < (best - firstRow).abs()) best = candidate;
      }
      if (!isLast) runStart = pages[i + 1];
    }
    return best;
  }

  // ─────────────────────────────────────────────
  // Demand
  // ─────────────────────────────────────────────

  /// Starts the initial page load: marks page 0 loading and returns the
  /// [LoadRequest] for the app to fetch.
  ///
  /// The owner exposes this for the app to call once (e.g. on init). Every
  /// page after this one is asked for by [demand].
  LoadRequest loadFirstPage() {
    _beginLoad(0);
    return LoadRequest(id, key: const PageKey(0));
  }

  /// Asks for the pages the viewport needs and does not have.
  ///
  /// Returns a [LoadRequest] for one missing page, a [Batch] of them for
  /// several, or null when nothing is missing. Demand is presence over the
  /// whole window — the pages the viewport covers, reaching [loadThreshold]
  /// rows past each edge — rather than a step past whichever edge was last
  /// extended. That is what sends a long jump straight to its destination
  /// page, and what re-requests a page missing in the middle of the window
  /// instead of leaving it a permanent hole.
  ///
  /// The owner calls this on every message that moves its viewport. An app
  /// calls it when its own state changes what it is willing to fetch — after a
  /// policy gate that was refusing requests lifts, say — since a refusal
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
      requests.add(LoadRequest(id, key: PageKey(page)));
    }
    return requests.length == 1 ? requests.first : Batch(requests);
  }

  /// Runs a [demand] pass only if something has changed what is missing, and
  /// returns whatever it asks for.
  ///
  /// This backs the app's frame-tick arm. Three things arm it — the visible
  /// row count changing (a resize, which reaches the owner through the paint
  /// path where no command can be returned), a page installing successfully
  /// (which frees a slot the in-flight cap may have truncated), and
  /// [markDemandDirty]. A refused or failed request arms nothing, which is
  /// what keeps a standing refusal from becoming a request every frame.
  Cmd? demandIfDirty() => _demandDirty ? demand() : null;

  /// Arms the next [demandIfDirty] pass.
  ///
  /// Call it from wherever an app's own gate lifts — a sync finishing, a
  /// filter clearing — when the pages it was refusing should now be fetched.
  /// It is the same recovery as calling [demand] directly, without a command
  /// to thread out of wherever that state lives.
  void markDemandDirty() => _demandDirty = true;

  /// Notes that the owner painted; call it once per paint, after the owner has
  /// updated its visible row count.
  ///
  /// A change in the visible row count arms demand: a taller terminal reveals
  /// rows nobody has asked for, and the paint path — where a widget cannot
  /// return a command — is where the owner finds out. The app's frame-tick arm
  /// picks it up on the next frame. If demand stays armed across many paints
  /// while a page is actually requestable, the loader says once, in the log,
  /// that the arm is probably missing. A widget with nothing to request — a
  /// static one, or one whose fetches are all in flight — never counts toward
  /// the warning.
  void notePaint() {
    final rows = _visibleRows();
    if (rows != _lastPaintedRows) _demandDirty = true;
    _lastPaintedRows = rows;
    if (!_demandDirty || !_hasDemandableWork) {
      _paintsWhileDirty = 0;
      return;
    }
    _paintsWhileDirty++;
    if (_paintsWhileDirty > _pumpWarningPaints && !_pumpWarned) {
      _pumpWarned = true;
      Log.warn(
        '$widgetName "$id" has had pages to demand for $_paintsWhileDirty frames '
        'without a demand pass. Add the frame-tick arm to your update: '
        'FrameTickMsg() => (model, model.demandIfDirty())',
      );
    }
  }

  // ─────────────────────────────────────────────
  // Writing
  // ─────────────────────────────────────────────

  /// Installs the outcome of a page load and clears (or fails) its slot.
  /// Returns true only when rows were installed.
  ///
  /// This backs the owner's `applyLoad`, keyed by page number ([PageKey]). A
  /// result for another widget (by id), a non-page key, or a page that is no
  /// longer in flight (e.g. after a [reset]) is dropped rather than corrupting
  /// the window.
  ///
  /// On success the rows install as that page — a short page recording where
  /// the data ends — and pages the viewport no longer needs are evicted. A
  /// refusal clears the slot and installs nothing, so the page keeps its
  /// placeholders and is asked for again by the next demand pass. A failure
  /// records the error, and a later demand pass retries the page.
  bool apply(LoadResult<Object?> result) {
    if (result.id != id) return false;
    final key = result.key;
    if (key is! PageKey) return false;
    final page = key.page;
    // Staleness guard: only a page still in flight accepts a result.
    if (!_inFlight.contains(page)) return false;
    if (result.cancelled) {
      _finishLoad(page);
      return false;
    }
    if (!result.ok) {
      _finishLoad(page, error: result.error);
      return false;
    }
    // A page arrives either as plain rows or as the PageResult a PageSource
    // returns, which may also carry a count or an outright end-of-data.
    final data = result.data;
    final rows = switch (data) {
      PageResult<T>(:final items) => items,
      final List<T> list => list,
      _ => <T>[],
    };
    _window.install(page, rows, demand: _demandSpan);
    if (data is PageResult<T>) {
      if (data.hasMore == false) _window.endAt(page);
      if (data.totalCount != null) totalCount = data.totalCount;
    }
    _finishLoad(page);
    // Progress: a slot is free and the window changed, so re-derive what is
    // still missing on the next tick. This is what drains a demand window the
    // in-flight cap truncated, with no input at all.
    markDemandDirty();
    return true;
  }

  /// Installs [rows] into the window as whole pages, starting at [firstPage].
  ///
  /// This is the seeding path for rows an app already holds — a static widget,
  /// or a first page fetched before the model existed. Rows are split at the
  /// page size, and nothing is evicted: a caller handing over data it already
  /// has means to keep it. Pages that arrive from a [LoadRequest] go through
  /// [apply] instead, which is what evicts.
  void seed(List<T> rows, {int firstPage = 0}) => _window.seed(rows, firstPage: firstPage);

  /// Drops every page, resolves every slot, and forgets where the data ended —
  /// a known [totalCount] still says.
  void reset() {
    _window.clear();
    for (final page in _inFlight) {
      _loads.complete(PageKey(page));
    }
    _inFlight.clear();
    _demandDirty = false;
    _paintsWhileDirty = 0;
    // A cleared window forgets where the data ends; a known total still says.
    totalCount = _totalCount;
  }

  // ─────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────

  /// The pages the viewport is painting right now, with no threshold reach.
  PageSpan get _visibleSpan => _window.spanFor(firstRow: _firstRow(), rowCount: _visibleRows());

  /// The pages the viewport is asking for right now.
  PageSpan get _demandSpan =>
      _window.spanFor(firstRow: _firstRow(), rowCount: _visibleRows(), threshold: loadThreshold);

  /// Whether a demand pass right now would request at least one page.
  bool get _hasDemandableWork =>
      _inFlight.length < maxConcurrentLoads &&
      _window.missing(_demandSpan, pending: _inFlight.contains, limit: 1).isNotEmpty;

  /// What [pages] amount to, as the shared load machinery sees them.
  SliceStatus _statusOf(Iterable<int> pages) =>
      statusFor(pages.map(PageKey.new), _loads, (key) => _window.has(key.page));

  void _beginLoad(int page) {
    _inFlight.add(page);
    _loads.begin(PageKey(page));
  }

  void _finishLoad(int page, {Object? error}) {
    _inFlight.remove(page);
    if (error == null) {
      _loads.complete(PageKey(page));
    } else {
      _loads.fail(PageKey(page), error);
    }
  }
}
