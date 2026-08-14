import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../../load/page_loader.dart';
import '../row_region.dart';
import '../scrollable_model.dart';
import 'types.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for ListView state and behavior.
///
/// Holds cursor position, selection state, scroll offset, and paged items held
/// in a sliding window over large data sets. Implements [Component] (stable
/// [id] + [update]) for addressing and focus, and [Loadable] so the app can
/// install fetched pages with [applyLoad].
///
/// The page is the unit of loading: each page gets its own load slot named by a
/// [PageKey], so several pages can be in flight at once, a result places
/// itself, and a page is never asked for twice while it is on its way. The
/// model performs no I/O — anything that moves the viewport runs a [demand]
/// pass, which returns a [LoadRequest] (or a [Batch] of them) for the pages the
/// viewport needs and does not have. The app fetches and hands each page back
/// through [applyLoad].
///
/// Two obligations sit on the app, and both are one line:
///
/// - Answer **every** request — with items, with an error, or with a refusal
///   built by `declineLoad`. A request left unanswered leaves its page painting
///   a placeholder forever, because the model will not ask again while it
///   believes the page is loading.
/// - Pump demand on the frame tick: `FrameTickMsg() => (model, model.list
///   .demandIfDirty())`. A terminal resize reveals items through the paint
///   path, where a widget cannot return a command, so without that arm the
///   items a taller terminal reveals are demanded by nobody. The model says so
///   in the log if it notices the arm missing.
///
/// A list over items already in memory is one constructor call, and never meets
/// any of the loading machinery:
///
/// ```dart
/// final listModel = ListViewModel<String, String>(
///   items: ['Apple', 'Banana', 'Cherry'],
///   focused: true,
/// );
/// ```
///
/// A list that loads passes no items at all — it asks for its first page and
/// fills from there:
///
/// ```dart
/// final listModel = ListViewModel<User, String>(
///   itemKey: (u) => u.id,
///   pageSize: 20,
///   focused: true,
/// );
/// ```
class ListViewModel<T, K> with ScrollableModel implements Component, Loadable {
  /// Stable address for this model, carried by value in the widget→app commands
  /// it emits ([ListActionCmd]) and the [LoadRequest]s it returns when pages
  /// are needed.
  ///
  /// Auto-generated when omitted; pass an explicit id to match against a literal
  /// or to disambiguate multiple instances.
  @override
  final String id;

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  int _cursor = 0;
  final Set<K> _selectedKeys = {};
  int _scrollOffset = 0;
  int? _selectionAnchor;
  int _visibleCount = 0;
  late final PageLoader<T> _loader;

  /// The item row the pointer is hovering, or null when it is over no row.
  ///
  /// Set from any pointer message the list receives and cleared when the pointer
  /// leaves. The view folds it into the hovered row's style as the weakest state,
  /// so a hovered selected or cursor row still reads selected or cursor.
  int? hoverRow;

  /// Whether the list is focused.
  @override
  bool focused;

  // ─────────────────────────────────────────────
  // Config
  // ─────────────────────────────────────────────

  /// Lines per item (1, 2, 3...), excludes separator.
  final int itemHeight;

  /// Whether multiple items can be selected.
  final bool multiSelect;

  /// How far past the viewport, in items, the list asks for pages.
  final int loadThreshold;

  /// Anatomy overrides. Mutable so an app can swap in a custom look at runtime,
  /// the way it flips [focused].
  ListViewStyle styles;

  /// Items per page. Fixed for the life of the model: page boundaries are index
  /// arithmetic, so every page except the last must contain exactly this many
  /// items. A source that cannot promise that must re-chunk before answering
  /// (`PageSource.cursor` does).
  final int pageSize;

  /// How many pages beyond the ones the viewport needs stay in memory.
  ///
  /// Retention is relative: the pages the viewport is asking for are always
  /// kept, and this many more survive on each side of them. Zero is legal and
  /// means "keep what is on screen, re-fetch anything scrolled back to".
  final int keepPages;

  /// How many page fetches the list will have outstanding at once.
  ///
  /// Only the widget's own requests are bounded; how the app schedules the I/O
  /// is its business. Every demand pass re-derives what is missing, so a pass
  /// truncated here is picked up by the next one.
  final int maxConcurrentLoads;

  /// Returns true if item at index is disabled (can't be selected).
  final bool Function(int index)? isDisabled;

  /// Extracts identity key from item for selection tracking.
  ///
  /// Defaults to identity function (item is its own key).
  /// For simple lists (strings, ints), default works fine.
  /// For complex objects, provide a function returning unique ID.
  final K Function(T item) itemKey;

  /// Key bindings for list actions.
  late final KeyBinding<ListViewAction> keyBinding;

  /// Creates a ListViewModel.
  ///
  /// Pass [items] for a list over data already in memory: they seed the window
  /// as whole pages and, unless [totalCount] says otherwise, they are taken to
  /// be all of it. Pass [totalCount] alongside them to seed a first page of
  /// something larger, or on its own when a count fetch answered before the
  /// first page did. A list that loads everything can pass neither and learn
  /// where the data ends from the first short page.
  ///
  /// Pass a custom [keyBinding] to override default key bindings.
  ListViewModel({
    List<T>? items,
    int? totalCount,
    String? id,
    K Function(T item)? itemKey,
    this.itemHeight = 1,
    this.multiSelect = false,
    this.loadThreshold = 5,
    this.pageSize = 20,
    this.keepPages = 4,
    this.maxConcurrentLoads = 3,
    this.focused = false,
    this.isDisabled,
    this.styles = const ListViewStyle(),
    KeyBinding<ListViewAction>? keyBinding,
  }) : id = id ?? autoId('listview'),
       itemKey = itemKey ?? _castItemKey {
    this.keyBinding = keyBinding ?? defaultListViewBindings.copy();
    _loader = PageLoader<T>(
      id: this.id,
      widgetName: 'ListView',
      firstRow: () => _scrollOffset,
      visibleRows: () => _visibleCount,
      pageSize: pageSize,
      keepPages: keepPages,
      loadThreshold: loadThreshold,
      maxConcurrentLoads: maxConcurrentLoads,
    );
    if (items != null) _loader.seed(items);
    this.totalCount = totalCount ?? items?.length;
  }

  /// Default itemKey: identity function (T must be assignable to K).
  static K _castItemKey<T, K>(T item) => item as K;

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  /// Current cursor position.
  int get cursor => _cursor;

  /// Set of selected item keys (unmodifiable).
  ///
  /// Only populated when [multiSelect] is true. Items are selected/unselected
  /// via Space key (toggleSelect action) or Shift+arrow (range select).
  /// Returns empty set when multiSelect is false.
  Set<K> getSelectedKeys() => Set.unmodifiable(_selectedKeys);

  /// Current scroll offset.
  @override
  int get scrollOffset => _scrollOffset;

  /// Rows the viewport shows, as last pushed in by the view.
  @override
  int get visibleCount => _visibleCount;

  /// Moves the viewport by [rows], clamped to [itemLimit] so the wheel never
  /// scrolls past where the data can reach. Returns rows actually moved (see
  /// [ScrollableModel.scrollBy]).
  @override
  int scrollBy(int rows) {
    final maxOffset = itemLimit - _visibleCount;
    final before = _scrollOffset;
    _scrollOffset = (_scrollOffset + rows).clamp(0, maxOffset < 0 ? 0 : maxOffset);
    return _scrollOffset - before;
  }

  /// Item at cursor, or null if the window does not hold it.
  T? get cursorItem => _loader.rowAt(_cursor);

  /// The item at [index], or null if its page isn't held (or the index is past
  /// the end of the data).
  T? getItem(int index) => _loader.rowAt(index);

  /// Check if item at index is checked (multi-select only).
  ///
  /// Always returns false when [multiSelect] is false.
  bool isSelected(int index) {
    final item = getItem(index);
    return item != null && _selectedKeys.contains(itemKey(item));
  }

  /// Called by widget during render to update visible count.
  ///
  /// A change arms demand: a taller terminal reveals items nobody has asked
  /// for, and this is where the model finds out — during paint, where it cannot
  /// return a command. The app's frame-tick arm picks it up on the next frame.
  void setVisibleCount(int count) {
    _visibleCount = count;
    _loader.notePaint();
  }

  /// Scroll position info for external scrollbar.
  ScrollState getScrollState() => ScrollState(
    offset: _scrollOffset,
    visible: _visibleCount,
    total: knownItemCount,
  );

  /// One past the last item the list can address: the total count when known,
  /// and never less than the last item actually held.
  ///
  /// Navigation, the wheel and the view's row loop all stop here. Without a
  /// count it reaches to the end of the loaded items and of any page still on
  /// its way — so the items a pending page will fill can paint their
  /// placeholders, while a list whose size nothing has revealed still cannot
  /// scroll into a void.
  int get itemLimit => _loader.rowLimit;

  /// How many items exist, when that is known — from a total count, or from a
  /// short page that showed where the data ends. Null while it is unknown.
  int? get knownItemCount => _loader.knownRowCount;

  /// Total item count, or null while it isn't known.
  ///
  /// Set it when a count fetch lands: the model uses it to bound navigation and
  /// to know which pages exist, so a list with a count can jump straight to the
  /// end and fetch the page it landed on.
  ///
  /// The count is current best knowledge, not the last value set. A page that
  /// ends the data earlier tightens it to match. Setting it again overwrites
  /// the tightened value and re-opens the data.
  int? get totalCount => _loader.totalCount;

  set totalCount(int? value) {
    _loader.totalCount = value;
    _clampToKnownEnd();
  }

  /// Number of items the window holds.
  int get cachedItemCount => _loader.cachedRowCount;

  /// The pages currently held, ascending.
  List<int> get cachedPages => _loader.cachedPages;

  // ─────────────────────────────────────────────
  // Load lifecycle
  // ─────────────────────────────────────────────

  /// Whether a page fetch is in flight — for [key] if given, otherwise for any
  /// page.
  bool isLoading([PageKey? key]) => _loader.isLoading(key);

  /// The error from a failed load for [key], or null if it didn't fail.
  Object? errorFor(PageKey key) => _loader.errorFor(key);

  /// What the items the list is about to paint amount to: all here, filling in,
  /// failed, or missing with nothing coming.
  ///
  /// Only pages that can exist count — items past the end of the data are
  /// absent by definition, not missing.
  SliceStatus get viewportStatus => _loader.viewportStatus;

  /// Whether a page above the viewport is being fetched — the fact a spinner
  /// over the top edge is driven from.
  bool get isLoadingAbove => _loader.isLoadingAbove;

  /// Whether a page below the viewport is being fetched — the fact a spinner
  /// under the bottom edge is driven from.
  bool get isLoadingBelow => _loader.isLoadingBelow;

  /// The first item of the nearest run of [count] items the window holds whole,
  /// or null when it holds no such run.
  ///
  /// This is what the view paints while a fetch is in flight and the cursor is
  /// off screen, instead of a screen of placeholders. Its own position is
  /// reported by [getScrollState], so external chrome stays honest.
  int? nearestHeldStart(int count) => _loader.nearestHeldStart(count);

  /// Starts the initial page load: marks page 0 loading and returns the
  /// [LoadRequest] for the app to fetch.
  ///
  /// The app calls this once (e.g. on init), fetches the page named by the
  /// request's [PageKey], and installs the result via [applyLoad]. Every page
  /// after this one is asked for by [demand].
  LoadRequest loadFirstPage() => _loader.loadFirstPage();

  /// Asks for the pages the viewport needs and does not have.
  ///
  /// Returns a [LoadRequest] for one missing page, a [Batch] of them for
  /// several, or null when nothing is missing. Demand is presence over the
  /// whole window — the pages the viewport covers, reaching [loadThreshold]
  /// items past each edge — so a long jump fetches its destination first, and a
  /// hole in the middle of the window is re-requested like any other absence.
  ///
  /// The model calls this itself on every message that moves the viewport. An
  /// app calls it when its own state changes what it is willing to fetch, since
  /// a refusal deliberately never re-triggers demand on its own.
  Cmd? demand() => _loader.demand();

  /// Runs a [demand] pass only if something has changed what is missing, and
  /// returns whatever it asks for.
  ///
  /// This is the app's frame-tick arm: `FrameTickMsg() => (model, model.list
  /// .demandIfDirty())`. Three things arm it — the visible item count changing,
  /// a page installing successfully, and [markDemandDirty]. A refused or failed
  /// request arms nothing, which is what keeps a standing refusal from becoming
  /// a request every frame.
  Cmd? demandIfDirty() => _loader.demandIfDirty();

  /// Arms the next [demandIfDirty] pass.
  ///
  /// Call it from wherever an app's own gate lifts — a sync finishing, a filter
  /// clearing — when the pages it was refusing should now be fetched.
  void markDemandDirty() => _loader.markDemandDirty();

  /// Installs the outcome of a page load and clears (or fails) its slot.
  ///
  /// This is the app's single entry point for delivering a fetched page, keyed
  /// by page number ([PageKey]). A result for another model (by id), a non-page
  /// key, or a page that is no longer in flight (e.g. after a [reset]) is
  /// dropped rather than corrupting the window.
  ///
  /// On success the items install as that page — a short page recording where
  /// the data ends — and pages the viewport no longer needs are evicted. While
  /// a range anchor is active, the installed items that fall inside the
  /// anchor-to-cursor span join the selection, so a range swept over items
  /// still being fetched completes itself when they arrive. A refusal clears
  /// the slot and installs nothing, so the page keeps its placeholders and is
  /// asked for again by the next demand pass. A failure records the error, and
  /// a later demand pass retries the page.
  @override
  void applyLoad(LoadResult<Object?> result) {
    if (!_loader.apply(result)) return;
    _clampToKnownEnd();
    if (result.key case final PageKey key) _completeRangeFor(key.page);
  }

  // ─────────────────────────────────────────────
  // Data management
  // ─────────────────────────────────────────────

  /// Installs [items] into the window as whole pages, starting at [pageNum].
  ///
  /// This is the seeding path for items an app already holds — a static list,
  /// or a first page fetched before the model existed. Items are split at the
  /// page size, and nothing is evicted: a caller handing over data it already
  /// has means to keep it. Pages that arrive from a [LoadRequest] go through
  /// [applyLoad] instead, which is what evicts.
  ///
  /// To replace the data wholesale — a search box swapping its results — call
  /// [reset], then this, then set [totalCount] to the new length.
  void insertItems(List<T> items, int pageNum) => _loader.seed(items, firstPage: pageNum);

  /// Clear the window and reset state.
  void reset() {
    _cursor = 0;
    _scrollOffset = 0;
    _selectedKeys.clear();
    _selectionAnchor = null;
    hoverRow = null;
    _loader.reset();
  }

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  /// Handles keyboard and pointer messages. Returns [Handled] or [Declined].
  ///
  /// The pointer branch sits above the focus gate, so a wheel scrolls, a click
  /// selects, and a hover highlights whether or not the list is focused. A
  /// wheel notch scrolls the viewport without touching the cursor, and
  /// scrolling runs a demand pass exactly as cursor navigation does; a notch
  /// that moves nothing in that direction (already at the edge) is declined, so
  /// a nesting scroll ancestor gets the chance — this stays above the region
  /// logic, so a notch over an unmarked separator still scrolls. A button-down
  /// on an item's row region moves the cursor there and activates it, exactly
  /// as Enter does; any other pointer on it only refreshes the hovered row. A
  /// pointer over no marked part — a separator, the blank tail — declines a
  /// press so the app can bubble it, and clears the hover on a move. The
  /// keyboard path stays behind the gate.
  ///
  /// Navigation is never frozen by a load: pages load in their own slots, so
  /// the cursor keeps moving and any number of pages can be on their way at
  /// once. Confirming an item the window does not hold is consumed and emits
  /// nothing — the list understands the key and has nothing to act on.
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

      // The row under the pointer is resolved by the framework and carried on
      // the message — no cursor arithmetic here. A click activates like Enter;
      // any other pointer just refreshes the hover.
      if (pointer.region case final RowScoped row) {
        return handleRowPointer(
          pointer,
          row.index,
          setHover: (r) => hoverRow = r,
          moveCursorTo: (r) {
            _cursor = r;
            _adjustScrollToCursor();
          },
          // An item the window does not hold cannot be activated: the cursor
          // still moves, the press stays consumed, and no command is emitted.
          activate: () => cursorItem == null ? null : ListActionCmd(id),
        );
      }
      // No marked part under the pointer — a separator or the blank tail below
      // the last item. A press is not ours, so it bubbles; a move clears hover.
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
        case ListViewAction.up:
          _moveCursor(-1);
          _selectionAnchor = null;
        case ListViewAction.down:
          _moveCursor(1);
          _selectionAnchor = null;
        case ListViewAction.first:
          _cursor = 0;
          _adjustScrollToCursor();
          _selectionAnchor = null;
        case ListViewAction.last:
          if (itemLimit > 0) _cursor = itemLimit - 1;
          _adjustScrollToCursor();
          _selectionAnchor = null;
        case ListViewAction.pageUp:
          _moveCursor(-_visibleCount.clamp(1, 100));
          _selectionAnchor = null;
        case ListViewAction.pageDown:
          _moveCursor(_visibleCount.clamp(1, 100));
          _selectionAnchor = null;
        case ListViewAction.toggleSelect:
          _toggleSelectAtCursor();
        case ListViewAction.confirm:
          // An item the window does not hold cannot be confirmed: the key is
          // consumed — a declined confirm would fire the app's fallback
          // bindings — and no command is emitted.
          if (cursorItem == null) return const Handled();
          return Handled(ListActionCmd(id));
        case ListViewAction.selectUp:
          if (multiSelect) _rangeSelect(-1);
        case ListViewAction.selectDown:
          if (multiSelect) _rangeSelect(1);
      }

      return Handled(demand());
    }

    return const Declined();
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  void _moveCursor(int delta) {
    final maxIndex = itemLimit - 1;
    _cursor = (_cursor + delta).clamp(0, maxIndex < 0 ? 0 : maxIndex);
    _adjustScrollToCursor();
  }

  /// Pulls the cursor and the viewport back when the end of the data lands
  /// closer than navigation had reached.
  ///
  /// Navigation may run ahead into pages still on their way. When the end then
  /// lands — a short page, or a total count — the rows past it stop existing,
  /// so the cursor clamps to the last item and the viewport clamps so that
  /// item sits on the bottom row. Only a known end clamps: a limit that shrank
  /// because a refusal resolved an in-flight page says nothing about which
  /// rows exist.
  void _clampToKnownEnd() {
    final known = knownItemCount;
    if (known == null) return;
    final maxIndex = known - 1;
    if (_cursor > maxIndex) _cursor = maxIndex < 0 ? 0 : maxIndex;
    final maxOffset = known - _visibleCount;
    if (_scrollOffset > maxOffset) _scrollOffset = maxOffset < 0 ? 0 : maxOffset;
  }

  void _adjustScrollToCursor() {
    if (_visibleCount <= 0) return;

    // Cursor above visible area
    if (_cursor < _scrollOffset) {
      _scrollOffset = _cursor;
    }
    // Cursor below visible area
    else if (_cursor >= _scrollOffset + _visibleCount) {
      _scrollOffset = _cursor - _visibleCount + 1;
    }
  }

  void _toggleSelectAtCursor() {
    if (!multiSelect) return;
    if (isDisabled?.call(_cursor) ?? false) return;

    final item = cursorItem;
    if (item == null) return;

    final key = itemKey(item);
    if (_selectedKeys.contains(key)) {
      _selectedKeys.remove(key);
    } else {
      _selectedKeys.add(key);
    }
  }

  void _rangeSelect(int direction) {
    // Set anchor on first range select
    _selectionAnchor ??= _cursor;

    // Move cursor
    _moveCursor(direction);

    // Select range from anchor to cursor. An item whose page has not arrived
    // is skipped here and picked up when the page installs (_completeRangeFor)
    // or by the next keypress, which re-walks the whole span.
    _selectKeysIn(_selectionAnchor!, _cursor);
  }

  /// Adds the keys of the items a just-installed [page] contributes to an
  /// active range selection.
  ///
  /// Bounded by the page size, not the length of the range; it stops on its
  /// own once the anchor clears, which any plain navigation key does.
  void _completeRangeFor(int page) {
    final anchor = _selectionAnchor;
    if (!multiSelect || anchor == null) return;
    final first = page * pageSize;
    final last = first + pageSize - 1;
    final low = anchor < _cursor ? anchor : _cursor;
    final high = anchor < _cursor ? _cursor : anchor;
    _selectKeysIn(low > first ? low : first, high < last ? high : last);
  }

  void _selectKeysIn(int from, int to) {
    final low = from < to ? from : to;
    final high = from < to ? to : from;
    for (var i = low; i <= high; i++) {
      if (isDisabled?.call(i) ?? false) continue;
      final item = getItem(i);
      if (item != null) _selectedKeys.add(itemKey(item));
    }
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// Default key bindings for ListView.
final defaultListViewBindings = KeyBinding<ListViewAction>()
  ..map(['up', 'k'], ListViewAction.up)
  ..map(['down', 'j'], ListViewAction.down)
  ..map(['home'], ListViewAction.first)
  ..map(['end', 'G'], ListViewAction.last)
  ..map(['pageUp', 'ctrl+b'], ListViewAction.pageUp)
  ..map(['pageDown', 'ctrl+d'], ListViewAction.pageDown)
  ..map(['space'], ListViewAction.toggleSelect)
  ..map(['enter'], ListViewAction.confirm)
  ..map(['shift+up', 'shift+k'], ListViewAction.selectUp)
  ..map(['shift+down', 'shift+j'], ListViewAction.selectDown);
