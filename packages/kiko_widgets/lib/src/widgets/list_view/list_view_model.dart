import 'package:kiko/kiko.dart';

import '../../load/data_view.dart';
import '../../load/load.dart';
import '../row_region.dart';
import '../scrollable_model.dart';
import 'types.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for ListView state and behavior.
///
/// Holds cursor position, selection state, scroll offset, and the load state of
/// its one pending fetch. Implements [Component] (stable [id] + [update]) for
/// addressing and focus, and [Loadable] so the app can install fetched pages
/// with [applyLoad].
///
/// The model performs no I/O. It renders through a read-only [DataView]; when the
/// cursor nears the end and more data can be loaded, [update] returns a
/// [LoadRequest] instead of fetching anything itself. The app turns the request
/// into a runtime `Task` and hands the page back through [applyLoad], which
/// appends it to the buffer.
///
/// ```dart
/// // Static list — synchronous, never loads:
/// final listModel = ListViewModel<String, String>(
///   dataView: DataView.fromList(['Apple', 'Banana', 'Cherry']),
///   focused: true,
/// );
///
/// // Paginated — app calls loadFirstPage() on init, then feeds applyLoad:
/// final listModel = ListViewModel<User, String>(
///   dataView: DataBuffer<User>(),
///   itemKey: (u) => u.id,
///   pageSize: 20,
///   focused: true,
/// );
/// ```
class ListViewModel<T, K> with ScrollableModel implements Component, Loadable {
  /// Stable address for this model, carried by value in the widget→app commands
  /// it emits ([ListActionCmd]) and the [LoadRequest] it returns when more data
  /// is needed.
  ///
  /// Auto-generated when omitted; pass an explicit id to match against a literal
  /// or to disambiguate multiple instances.
  @override
  final String id;

  /// The items this list renders.
  ///
  /// Read-only by contract: the model renders through it and grows it only
  /// through [applyLoad]. For a paginated list this is a [DataBuffer] the model
  /// appends pages to; a static [DataView.fromList] never loads. Reassign it to
  /// swap the whole backing (e.g. a client-side filter rebuilding its results).
  DataView<T> dataView;

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  int _cursor = 0;
  final Set<K> _selectedKeys = {};
  int _scrollOffset = 0;
  int? _selectionAnchor;
  int _visibleCount = 0;

  /// The item row the pointer is hovering, or null when it is over no row.
  ///
  /// Set from any pointer message the list receives and cleared when the pointer
  /// leaves. The view folds it into the hovered row's style as the weakest state,
  /// so a hovered selected or cursor row still reads selected or cursor.
  int? hoverRow;

  final _loads = LoadTracker<ListLoadKey>();

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

  /// Return a [LoadRequest] when the cursor is within this many items of the end.
  final int loadMoreThreshold;

  /// Anatomy overrides. Mutable so an app can swap in a custom look at runtime,
  /// the way it flips [focused].
  ListViewStyle styles;

  /// Items expected per page, used to tell when the last page has arrived.
  ///
  /// After a page is applied, the list keeps [DataView.hasMore] true only while
  /// the page came back full; a short page means there is no more to load. Has no
  /// effect on a static list, which never loads.
  final int pageSize;

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
  /// Pass a custom [keyBinding] to override default key bindings.
  ListViewModel({
    required this.dataView,
    String? id,
    K Function(T item)? itemKey,
    this.itemHeight = 1,
    this.multiSelect = false,
    this.loadMoreThreshold = 5,
    this.pageSize = 20,
    this.focused = false,
    this.isDisabled,
    this.styles = const ListViewStyle(),
    KeyBinding<ListViewAction>? keyBinding,
  }) : id = id ?? autoId('listview'),
       itemKey = itemKey ?? _castItemKey {
    this.keyBinding = keyBinding ?? defaultListViewBindings.copy();
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

  /// Moves the viewport by [rows], clamped so it never leaves the loaded items.
  /// Returns rows actually moved (see [ScrollableModel.scrollBy]).
  @override
  int scrollBy(int rows) {
    final len = dataView.length;
    final maxOffset = len == null ? _scrollOffset + rows : (len - _visibleCount).clamp(0, len);
    final before = _scrollOffset;
    _scrollOffset = (_scrollOffset + rows).clamp(0, maxOffset < 0 ? 0 : maxOffset);
    return _scrollOffset - before;
  }

  /// Item at cursor, or null if out of bounds.
  T? get cursorItem => _safeItemAt(_cursor);

  /// Check if item at index is checked (multi-select only).
  ///
  /// Always returns false when [multiSelect] is false.
  bool isSelected(int index) {
    final item = _safeItemAt(index);
    return item != null && _selectedKeys.contains(itemKey(item));
  }

  /// Called by widget during render to update visible count.
  // ignore: use_setters_to_change_properties
  void setVisibleCount(int count) => _visibleCount = count;

  /// Scroll position info for external scrollbar.
  ScrollState getScrollState() => ScrollState(
    offset: _scrollOffset,
    visible: _visibleCount,
    total: dataView.length,
  );

  // ─────────────────────────────────────────────
  // Load lifecycle
  // ─────────────────────────────────────────────

  /// Whether the list's page fetch is in flight.
  ///
  /// Pass [ListLoadKey.self] or nothing — the list has a single load slot.
  bool isLoading([ListLoadKey? key]) => _loads.isLoading(key);

  /// The error from a failed load, or null if the last load didn't fail.
  Object? errorFor(ListLoadKey key) => _loads.errorFor(key);

  /// Starts the initial page load: marks the slot loading and returns the
  /// [LoadRequest] for the app to fetch.
  ///
  /// The app calls this once (e.g. on init), turns the request into a page fetch,
  /// and installs the result via [applyLoad]. Until then `isLoading()` is true.
  LoadRequest loadFirstPage() {
    _loads.begin(ListLoadKey.self);
    return LoadRequest(id, key: ListLoadKey.self);
  }

  /// Installs the outcome of a page load and clears (or fails) the slot.
  ///
  /// This is the app's single entry point for delivering a fetched page. A result
  /// for another model (by id), a non-list key, or a slot that is no longer
  /// loading (e.g. after the backing was swapped) is dropped rather than
  /// appending to the wrong list.
  ///
  /// On success the items are appended to the buffer, and [DataView.hasMore] is
  /// kept true only while the page came back full (a short page is the last). On
  /// failure the slot records the error; a later near-edge navigation retries it.
  @override
  void applyLoad(LoadResult<Object?> result) {
    if (result.id != id) return;
    if (result.key != ListLoadKey.self) return;
    // Staleness guard: only a slot still in flight accepts a result.
    if (!_loads.isLoading(ListLoadKey.self)) return;
    if (result.ok) {
      final items = (result.data as List<T>?) ?? <T>[];
      final buffer = dataView;
      if (buffer is DataBuffer<T>) {
        buffer
          ..append(items)
          ..hasMore = items.length >= pageSize;
      }
      _loads.complete(ListLoadKey.self);
    } else {
      _loads.fail(ListLoadKey.self, result.error!);
    }
  }

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  /// Handles keyboard and pointer messages. Returns [Handled] or [Declined].
  ///
  /// The pointer branch sits above the focus gate, so a wheel scrolls, a click
  /// selects, and a hover highlights whether or not the list is focused. A
  /// wheel notch scrolls the viewport without touching the cursor; a notch that
  /// moves nothing in that direction (already at the edge) is declined, so a
  /// nesting scroll ancestor gets the chance — this stays above the region
  /// logic, so a notch over an unmarked separator still scrolls. A button-down
  /// on an item's row region moves the cursor there and activates it, exactly as
  /// Enter does; any other pointer on it only refreshes the hovered row. A
  /// pointer over no marked part — a separator, the blank tail — declines a press
  /// so the app can bubble it, and clears the hover on a move. The keyboard path
  /// stays behind the gate.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      if (pointer.wheelDeltaY != 0) {
        final moved = scrollBy(wheelScrollLines * pointer.wheelDeltaY);
        // Nothing moved in that direction (already at the edge) — decline so a
        // nesting scroll ancestor gets the notch; consuming at the limit would
        // make nesting permanently dead.
        if (moved == 0) return const Declined();
        return Handled(_checkLoadThreshold());
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
          activate: () => ListActionCmd(id),
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
          final len = dataView.length;
          if (len != null && len > 0) _cursor = len - 1;
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
          return Handled(ListActionCmd(id));
        case ListViewAction.selectUp:
          if (multiSelect) _rangeSelect(-1);
        case ListViewAction.selectDown:
          if (multiSelect) _rangeSelect(1);
      }

      return Handled(_checkLoadThreshold());
    }

    return const Declined();
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  /// Returns a [LoadRequest] when the cursor nears the end and more data can be
  /// loaded, marking the slot loading so the same page isn't asked for twice.
  Cmd? _checkLoadThreshold() {
    final len = dataView.length;
    if (dataView.hasMore && len != null && !_loads.isLoading(ListLoadKey.self)) {
      // Key on the viewport's bottom edge, not the cursor: a wheel scroll pages
      // the next batch in without ever moving the cursor. Cursor navigation is
      // the special case where the edge tracks the cursor.
      final forwardEdge = _scrollOffset + _visibleCount - 1;
      if (forwardEdge >= len - loadMoreThreshold) {
        _loads.begin(ListLoadKey.self);
        return LoadRequest(id, key: ListLoadKey.self);
      }
    }
    return null;
  }

  T? _safeItemAt(int index) {
    if (index < 0) return null;
    final len = dataView.length;
    if (len != null && index >= len) return null;
    return dataView.itemAt(index);
  }

  void _moveCursor(int delta) {
    final len = dataView.length;
    final maxIndex = len != null ? len - 1 : _cursor + delta.abs();
    _cursor = (_cursor + delta).clamp(0, maxIndex.clamp(0, 999999));
    _adjustScrollToCursor();
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

    final item = _safeItemAt(_cursor);
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

    // Select range from anchor to cursor
    final start = _selectionAnchor!;
    final end = _cursor;
    final low = start < end ? start : end;
    final high = start < end ? end : start;

    for (var i = low; i <= high; i++) {
      if (isDisabled?.call(i) ?? false) continue;
      final item = _safeItemAt(i);
      if (item != null) {
        _selectedKeys.add(itemKey(item));
      }
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
