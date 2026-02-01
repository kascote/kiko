import 'package:kiko/kiko.dart';

import 'data_source.dart';
import 'types.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for ListView state and behavior.
///
/// Holds cursor position, selection state, and scroll offset.
/// Implements [Focusable] for focus management.
///
/// ```dart
/// final listModel = ListViewModel<String, String>(
///   dataSource: ListDataSource.fromList(['Apple', 'Banana', 'Cherry']),
///   focused: true,
/// );
/// ```
class ListViewModel<T, K> implements Focusable {
  /// The data source providing items.
  ListDataSource<T> dataSource;

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  int _cursor = 0;
  final Set<K> _selectedKeys = {};
  int _scrollOffset = 0;
  int? _selectionAnchor;
  int _visibleCount = 0;

  /// Whether data is currently loading (user manages this externally).
  bool isLoading = false;

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

  /// Emit [ListLoadMoreCmd] when cursor is within this many items from end.
  final int loadMoreThreshold;

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
    required this.dataSource,
    K Function(T item)? itemKey,
    this.itemHeight = 1,
    this.multiSelect = false,
    this.loadMoreThreshold = 5,
    this.focused = false,
    this.isDisabled,
    KeyBinding<ListViewAction>? keyBinding,
  }) : itemKey = itemKey ?? _castItemKey {
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
  int get scrollOffset => _scrollOffset;

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
    total: dataSource.length,
  );

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  /// Handles keyboard messages. Returns command or [Unhandled].
  Cmd? update(Msg msg) {
    if (!focused) return const Unhandled();

    if (msg case KeyMsg()) {
      final action = keyBinding.resolve(msg);
      if (action == null) return const Unhandled();

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
          final len = dataSource.length;
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
          return ListActionCmd<T, K>(this);
        case ListViewAction.selectUp:
          if (multiSelect) _rangeSelect(-1);
        case ListViewAction.selectDown:
          if (multiSelect) _rangeSelect(1);
      }

      // Check if need to load more
      final len = dataSource.length;
      if (dataSource.hasMore && len != null) {
        if (_cursor >= len - loadMoreThreshold) {
          return ListLoadMoreCmd<T, K>(this);
        }
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  T? _safeItemAt(int index) {
    if (index < 0) return null;
    final len = dataSource.length;
    if (len != null && index >= len) return null;
    return dataSource.itemAt(index);
  }

  void _moveCursor(int delta) {
    final len = dataSource.length;
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
