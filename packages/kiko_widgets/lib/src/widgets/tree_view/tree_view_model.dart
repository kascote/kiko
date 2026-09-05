import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../../load/viewport_changed.dart';
import '../row_region.dart';
import '../scrollable_model.dart';
import 'tree_node.dart';
import 'types.dart';

/// Model for TreeView state and behavior.
///
/// Holds expansion state, cursor position, and the load state of each pending
/// fetch. Implements [Component] (stable [id] + [update]) for addressing and
/// focus; a [LoadResult] addressed to the tree installs fetched data through
/// the same [update].
///
/// The model performs no I/O. The app owns the data source and drives every
/// fetch: it calls [loadRoots] once to start, and [expand]'s events include a
/// [LoadRequest] when a node's children aren't loaded yet. The app turns each
/// request into a runtime `Task` whose outcome is a [LoadResult] carrying the
/// tree's id, and the router delivers it to [update].
///
/// ```dart
/// final tree = TreeViewModel<FileInfo>(focused: true);
/// // app, on init:   final req = tree.loadRoots();  // → fetch getRoots()
/// // the fetch ends: LoadResult(tree.id, key: req.key, data: roots) → tree.update
/// ```
class TreeViewModel<T> with ScrollableModel implements Component {
  /// Stable address for this model, carried by value in the widget→app events
  /// it emits ([TreeExpandEvent], [TreeCollapseEvent], [TreeActivateEvent], [LoadRequest]).
  ///
  /// Auto-generated when omitted; pass an explicit id to match against a literal
  /// or to disambiguate multiple instances.
  @override
  final String id;

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  final Set<String> _expanded = {};
  final _loads = LoadTracker<TreeLoadKey>();
  final Map<String, List<TreeNode<T>>> _childrenCache = {};
  List<TreeNode<T>> _flatNodes = [];
  List<TreeNode<T>>? _roots;
  int _cursor = 0;
  int _scrollOffset = 0;
  int _visibleCount = 0;
  bool _rootsLoaded = false;

  /// The flattened node row the pointer is hovering, or null when it is over no
  /// node.
  ///
  /// Set from any pointer message the tree receives and cleared when the pointer
  /// leaves. The view folds it into the hovered row's style as the weakest state,
  /// so a hovered cursor node still reads cursor.
  int? hoverRow;

  /// Whether the tree is focused.
  @override
  bool focused;

  // ─────────────────────────────────────────────
  // Config
  // ─────────────────────────────────────────────

  /// Character for expanded node indicator.
  final String expandedChar;

  /// Character for collapsed node indicator.
  final String collapsedChar;

  /// Character for loading node indicator.
  final String loadingChar;

  /// Whether nodes display icons.
  final bool showIcons;

  /// Key bindings for tree actions.
  late final KeyBinding<TreeViewAction> keyBinding;

  /// Creates a TreeViewModel.
  TreeViewModel({
    String? id,
    this.expandedChar = '▼',
    this.collapsedChar = '▶',
    this.loadingChar = '◌',
    this.showIcons = false,
    this.focused = false,
    KeyBinding<TreeViewAction>? keyBinding,
  }) : id = id ?? autoId('treeview') {
    this.keyBinding = keyBinding ?? defaultTreeViewBindings.copy();
  }

  /// Spaces per indent level (calculated based on showIcons).
  int get indentWidth => showIcons ? 3 : 2;

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  /// Flattened list of visible nodes (expanded only).
  List<TreeNode<T>> get flatNodes => _flatNodes;

  /// Current cursor index in flatNodes.
  int get cursor => _cursor;

  /// Current scroll offset.
  @override
  int get scrollOffset => _scrollOffset;

  /// Rows the viewport shows, as the view last reported them.
  @override
  int get visibleCount => _visibleCount;

  /// Moves the viewport by [rows], clamped to the flattened visible range.
  /// Returns rows actually moved (see [ScrollableModel.scrollBy]).
  @override
  int scrollBy(int rows) {
    final maxOffset = _flatNodes.length - _visibleCount;
    final before = _scrollOffset;
    _scrollOffset = (_scrollOffset + rows).clamp(0, maxOffset < 0 ? 0 : maxOffset);
    return _scrollOffset - before;
  }

  /// Node at cursor, or null if empty.
  TreeNode<T>? get cursorNode => _cursor >= 0 && _cursor < _flatNodes.length ? _flatNodes[_cursor] : null;

  /// Whether roots have been loaded.
  bool get isLoaded => _rootsLoaded;

  /// Whether a fetch is in flight — for [key] if given, otherwise for any slot
  /// (the roots or any node's children). Pass `const RootsKey()` for the roots
  /// load specifically.
  bool isLoading([TreeLoadKey? key]) => _loads.isLoading(key);

  /// Whether the node at [path] is loading its children.
  bool isPathLoading(String path) => _loads.isLoading(PathKey(path));

  /// The error from a failed load for [key], or null if it didn't fail.
  Object? errorFor(TreeLoadKey key) => _loads.errorFor(key);

  /// The status of the children under the node at [path]: [SliceStatus.ready]
  /// when they are cached, [SliceStatus.filling] while their fetch is in
  /// flight, [SliceStatus.failed] after it failed, [SliceStatus.stalled] when
  /// nothing is cached and nothing is coming — a refused load, or a branch
  /// never expanded.
  ///
  /// The placeholder beneath an expanded branch paints from this, so a test
  /// asserts on the status instead of inspecting placeholder rows.
  SliceStatus branchStatus(String path) => statusFor([PathKey(path)], _loads, _hasData);

  bool _hasData(TreeLoadKey key) => switch (key) {
    RootsKey() => _rootsLoaded,
    PathKey(:final path) => _childrenCache.containsKey(path),
  };

  /// Whether a node is expanded.
  bool isExpanded(String path) => _expanded.contains(path);

  /// Scroll state for external scrollbar.
  TreeScrollState getScrollState() => TreeScrollState(
    offset: _scrollOffset,
    visible: _visibleCount,
    total: _flatNodes.length,
  );

  // ─────────────────────────────────────────────
  // Public API - Programmatic control
  // ─────────────────────────────────────────────

  /// Starts the initial root load: marks the roots slot loading and returns the
  /// [LoadRequest] for the app to fetch.
  ///
  /// The app calls this once (e.g. on init) and turns the request into a
  /// `getRoots` fetch whose [LoadResult] comes back through [update]. Until
  /// then, `isLoading(const RootsKey())` is true.
  LoadRequest loadRoots() {
    _loads.begin(const RootsKey());
    return LoadRequest(id, key: const RootsKey());
  }

  /// Installs the outcome of a load and clears (or fails) its slot.
  ///
  /// A result whose id's leaf is not this tree's id is declined: it is not a
  /// message this tree understands. Every result that is the tree's own is
  /// consumed, keyed by [LoadResult.key]: [RootsKey] installs roots, [PathKey]
  /// installs one node's children, and an unknown key installs nothing.
  ///
  /// Child results are guarded: only a node whose load is still in flight accepts
  /// one, so a late reply for a collapsed or already-loaded node is dropped rather
  /// than corrupting the tree. Roots have no such guard — they load once.
  ///
  /// A successful result must carry a `List<TreeNode<T>>`. Any other payload,
  /// null included, fails the slot with a [PayloadMismatch] and installs no
  /// nodes, so the branch shows the wiring error where a fetch failure would
  /// show.
  UpdateResult _applyLoad(LoadResult<Object?> result) {
    if (HitTag.leafOf(result.id) != id) return const Declined();
    switch (result.key) {
      case RootsKey():
        _installRoots(result);
      case PathKey(:final path):
        _installChildren(path, result);
      default:
        // Unknown key — nothing to install.
        break;
    }
    return const Handled();
  }

  /// Takes the viewport the view painted.
  ///
  /// A report whose id's leaf is not this tree's id is declined. The count is
  /// stored and nothing is requested: a tree pages children in on expand, not
  /// on what the viewport shows.
  UpdateResult _applyViewport(ViewportChanged report) {
    if (HitTag.leafOf(report.id) != id) return const Declined();
    _visibleCount = report.rows;
    return const Handled();
  }

  /// Installs fetched root [roots]. Typed shorthand for delivering a
  /// [LoadResult] with a [RootsKey] through [update].
  void applyRoots(List<TreeNode<T>> roots) =>
      update(LoadResult<List<TreeNode<T>>>(id, key: const RootsKey(), data: roots));

  /// Installs fetched [children] for [path]. Typed shorthand for delivering a
  /// [LoadResult] with a [PathKey] through [update].
  ///
  /// Subject to the staleness guard: the node's load must be in flight (started
  /// by [expand]); a result for a collapsed or idle path is dropped.
  void applyChildren(String path, List<TreeNode<T>> children) =>
      update(LoadResult<List<TreeNode<T>>>(id, key: PathKey(path), data: children));

  void _installRoots(LoadResult<Object?> result) {
    // A refusal resolves the slot and installs nothing: the roots stay unloaded
    // and a later expand asks for them again.
    if (result.cancelled) {
      _loads.complete(const RootsKey());
      return;
    }
    final nodes = _nodesOf(result, const RootsKey());
    if (nodes != null) {
      _roots = nodes;
      _rootsLoaded = true;
    }
    _rebuildFlatNodes();
  }

  void _installChildren(String path, LoadResult<Object?> result) {
    // Staleness guard: drop results for nodes that are no longer loading
    // (collapsed, already loaded, or never requested).
    if (!_loads.stateFor(PathKey(path)).isLoading) return;
    if (result.cancelled) {
      _loads.complete(PathKey(path));
      _rebuildFlatNodes();
      return;
    }
    final nodes = _nodesOf(result, PathKey(path));
    if (nodes != null) _childrenCache[path] = nodes;
    _rebuildFlatNodes();
  }

  /// The nodes a non-refused [result] carries, resolving [key]'s slot on the
  /// way: complete on a well-shaped success, failed on a fetch error or a
  /// payload of any other shape. Returns null when nothing installs.
  List<TreeNode<T>>? _nodesOf(LoadResult<Object?> result, TreeLoadKey key) {
    if (!result.ok) {
      _loads.fail(key, result.error!);
      return null;
    }
    final mismatch = payloadMismatch(
      result,
      widget: 'TreeView',
      expected: 'List<TreeNode<$T>>',
      accepts: (data) => data is List<TreeNode<T>>,
    );
    if (mismatch != null) {
      _loads.fail(key, mismatch);
      return null;
    }
    _loads.complete(key);
    return result.data! as List<TreeNode<T>>;
  }

  /// Expand a node.
  ///
  /// Returns an empty list if the node can't expand (leaf, missing, or
  /// already open). Otherwise the list holds a [TreeExpandEvent] for every
  /// expansion, plus a [LoadRequest] when the node's children aren't loaded
  /// yet; the app drives that fetch, and its [LoadResult] comes back through
  /// [update]. The widget never performs I/O.
  List<WidgetEvent> expand(String path) {
    if (_expanded.contains(path)) return const [];

    final node = _findNode(path);
    if (node == null || node.isLeaf) return const [];

    _expanded.add(path);
    final event = TreeExpandEvent<T>(id, path, node);

    // Children already cached, or a load already in flight: just the event.
    if (_childrenCache.containsKey(path) || _loads.isLoading(PathKey(path))) {
      _rebuildFlatNodes();
      return [event];
    }

    // Children not loaded: event + load request; mark the slot so we don't ask
    // twice.
    _loads.begin(PathKey(path));
    _rebuildFlatNodes();
    return [event, LoadRequest(id, key: PathKey(path))];
  }

  /// Collapse a node.
  ///
  /// Returns an empty list if the node can't collapse (missing, or already
  /// closed); otherwise a list holding the one [TreeCollapseEvent].
  List<WidgetEvent> collapse(String path) {
    if (!_expanded.contains(path)) return const [];

    final node = _findNode(path);
    if (node == null) return const [];

    _expanded.remove(path);
    // Cancel any pending or failed load: a late result must not resurrect a
    // collapsed subtree, and re-expanding should retry from scratch.
    _loads.complete(PathKey(path));
    _rebuildFlatNodes();

    // Adjust cursor if it was in collapsed subtree
    if (_cursor >= _flatNodes.length) {
      _cursor = _flatNodes.isEmpty ? 0 : _flatNodes.length - 1;
    }

    return [TreeCollapseEvent<T>(id, path, node)];
  }

  /// Toggle expand/collapse.
  ///
  /// When expanding an uncached node, returns the event-plus-request list
  /// from [expand]; when collapsing, the list from [collapse]; otherwise the
  /// expand event alone.
  List<WidgetEvent> toggle(String path) {
    if (_expanded.contains(path)) {
      return collapse(path);
    }
    return expand(path);
  }

  /// Expand all cached ancestors of [path], then scroll to it if visible.
  ///
  /// Best-effort over already-loaded data: an ancestor whose children are not
  /// cached is left untouched, because revealing it needs a fetch and the
  /// widget performs no I/O. Load the needed subtree first (via [expand] and
  /// the [LoadResult] it leads to), then call this.
  void expandPath(String path) {
    // Build list of ancestors
    final ancestors = <String>[];
    var current = path;
    while (true) {
      final lastSlash = current.lastIndexOf('/');
      if (lastSlash <= 0) break;
      current = current.substring(0, lastSlash);
      ancestors.insert(0, current);
    }

    // Expand only ancestors whose children are cached. Expanding an uncached
    // one would mark its slot loading and drop the LoadRequest that resolves
    // it, sticking the branch on its loading placeholder.
    for (final ancestor in ancestors) {
      if (_childrenCache.containsKey(ancestor)) expand(ancestor);
    }

    // Scroll to the node
    final index = _flatNodes.indexWhere((n) => n.path == path);
    if (index >= 0) {
      _cursor = index;
      _adjustScrollToCursor();
    }
  }

  /// Collapse all expanded nodes.
  void collapseAll() {
    _expanded.clear();
    _rebuildFlatNodes();
    _cursor = 0;
    _scrollOffset = 0;
  }

  /// Search loaded nodes for matching label text.
  List<TreeNode<T>> search(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    final results = <TreeNode<T>>[];

    void searchNodes(List<TreeNode<T>> nodes) {
      for (final node in nodes) {
        // Check if label contains query (simplified - checks raw text runs)
        final labelText = node.label.texts.map((t) => t.content).join();
        if (labelText.toLowerCase().contains(lowerQuery)) {
          results.add(node);
        }
        // Search cached children
        final children = _childrenCache[node.path];
        if (children != null) {
          searchNodes(children);
        }
      }
    }

    if (_roots != null) {
      searchNodes(_roots!);
    }

    return results;
  }

  /// Find first node matching query, return its path.
  String? findFirst(String query) {
    final results = search(query);
    return results.isEmpty ? null : results.first.path;
  }

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  /// Handles keyboard and pointer messages. Returns [Handled] or [Declined].
  ///
  /// The pointer branch sits above the focus gate, so a wheel scrolls, a click
  /// selects or toggles, and a hover highlights whether or not the tree is
  /// focused. A wheel notch scrolls the viewport without touching the cursor (a
  /// tree pages children in on expand, not on a scroll edge, so a wheel never
  /// triggers a load); a notch that moves nothing in that direction (already at
  /// the edge) is declined, so a nesting scroll ancestor gets the chance. A
  /// button-down moves the cursor to the node, then toggles
  /// its expansion if it hit the expand indicator or activates it (as Enter does)
  /// if it hit the body; any other pointer only refreshes the hovered row. A
  /// pointer past the last node is declined so the app can offer it to the next
  /// widget.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      if (pointer.wheelDeltaY != 0) {
        final moved = scrollBy(wheelScrollLines * pointer.wheelDeltaY);
        // Nothing moved in that direction (already at the edge) — decline so a
        // nesting scroll ancestor gets the notch; consuming at the limit would
        // make nesting permanently dead. A tree never pages on a wheel (only on
        // expand), so there is no load-threshold check to run on the handled
        // path.
        return moved == 0 ? const Declined() : const Handled();
      }
      if (pointer.isWheel) return const Declined(); // a horizontal wheel is not ours

      // The part under the pointer is resolved by the framework and carried on
      // the message. A press on the expand indicator toggles the branch; every
      // other row part (including a hover over the indicator) goes through the
      // shared row handler, which moves the cursor and activates on a press.
      final region = pointer.region;
      if (region is TreeIndicatorRegion && pointer.isDown) {
        _cursor = region.index;
        _adjustScrollToCursor();
        return Handled(events: _handleToggle());
      }
      if (region is RowScoped) {
        return handleRowPointer(
          pointer,
          region.index,
          setHover: (r) => hoverRow = r,
          moveCursorTo: (r) {
            _cursor = r;
            _adjustScrollToCursor();
          },
          activate: _handleConfirm,
        );
      }
      // No marked part — the blank tail below the last node. A press bubbles;
      // a move clears the hover.
      if (pointer.isDown) return const Declined();
      hoverRow = null;
      return const Handled();
    }
    if (msg is PointerLeaveMsg) {
      hoverRow = null;
      return const Handled();
    }
    if (msg is PointerCancelMsg) return const Declined();
    if (msg case final LoadResult<Object?> result) return _applyLoad(result);
    if (msg case final ViewportChanged report) return _applyViewport(report);

    if (!focused) return const Declined();

    if (msg case KeyMsg()) {
      final action = keyBinding.resolve(msg);
      if (action == null) return const Declined();

      switch (action) {
        case TreeViewAction.up:
          _moveCursor(-1);
        case TreeViewAction.down:
          _moveCursor(1);
        case TreeViewAction.first:
          _cursor = 0;
          _adjustScrollToCursor();
        case TreeViewAction.last:
          if (_flatNodes.isNotEmpty) {
            _cursor = _flatNodes.length - 1;
          }
          _adjustScrollToCursor();
        case TreeViewAction.pageUp:
          _moveCursor(-_visibleCount.clamp(1, 100));
        case TreeViewAction.pageDown:
          _moveCursor(_visibleCount.clamp(1, 100));
        case TreeViewAction.expand:
          return Handled(events: _handleExpand());
        case TreeViewAction.collapse:
          return Handled(events: _handleCollapse());
        case TreeViewAction.toggle:
          return Handled(events: _handleToggle());
        case TreeViewAction.confirm:
          final event = _handleConfirm();
          return event == null ? const Handled() : Handled.event(event);
      }

      return const Handled();
    }

    return const Declined();
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  void _rebuildFlatNodes() {
    _flatNodes = [];
    if (_roots == null) return;

    void addNodes(List<TreeNode<T>> nodes) {
      for (final node in nodes) {
        _flatNodes.add(node);
        if (!_expanded.contains(node.path)) continue;

        switch (branchStatus(node.path)) {
          case SliceStatus.ready:
            addNodes(_childrenCache[node.path]!);
          case SliceStatus.filling:
            _flatNodes.add(_placeholder(node.path, '_loading', SliceStatus.filling));
          case SliceStatus.failed:
            _flatNodes.add(_placeholder(node.path, '_error', SliceStatus.failed));
          case SliceStatus.stalled:
            _flatNodes.add(_placeholder(node.path, '_stalled', SliceStatus.stalled));
        }
      }
    }

    addNodes(_roots!);
  }

  TreeNode<T> _placeholder(String parentPath, String suffix, SliceStatus status) =>
      TreeNode<T>(path: '$parentPath/$suffix', label: Line(''), isLeaf: true, placeholder: status);

  TreeNode<T>? _findNode(String path) {
    // Check flat nodes first
    for (final node in _flatNodes) {
      if (node.path == path) return node;
    }
    // Check roots
    if (_roots != null) {
      for (final node in _roots!) {
        if (node.path == path) return node;
      }
    }
    // Check cache
    for (final children in _childrenCache.values) {
      for (final node in children) {
        if (node.path == path) return node;
      }
    }
    return null;
  }

  void _moveCursor(int delta) {
    if (_flatNodes.isEmpty) return;
    _cursor = (_cursor + delta).clamp(0, _flatNodes.length - 1);
    _adjustScrollToCursor();
  }

  void _adjustScrollToCursor() {
    if (_visibleCount <= 0) return;

    if (_cursor < _scrollOffset) {
      _scrollOffset = _cursor;
    } else if (_cursor >= _scrollOffset + _visibleCount) {
      _scrollOffset = _cursor - _visibleCount + 1;
    }
  }

  List<WidgetEvent> _handleExpand() {
    final node = cursorNode;
    if (node == null) return const [];

    if (node.isLeaf) return const [];

    if (_expanded.contains(node.path)) {
      // Already expanded - move to first child
      if (_cursor + 1 < _flatNodes.length) {
        final nextNode = _flatNodes[_cursor + 1];
        // Check if next node is a child
        if (nextNode.path.startsWith('${node.path}/')) {
          _cursor++;
          _adjustScrollToCursor();
        }
      }
      return const [];
    }

    // Request expansion — returns the expand event plus a load request when
    // the node's children aren't cached yet (the app drives the fetch).
    return expand(node.path);
  }

  List<WidgetEvent> _handleCollapse() {
    final node = cursorNode;
    if (node == null) return const [];

    if (_expanded.contains(node.path)) {
      // Collapse this node
      return collapse(node.path);
    } else {
      // Move to parent
      final parentPath = node.parentPath;
      if (parentPath != null) {
        final parentIndex = _flatNodes.indexWhere((n) => n.path == parentPath);
        if (parentIndex >= 0) {
          _cursor = parentIndex;
          _adjustScrollToCursor();
        }
      }
      return const [];
    }
  }

  List<WidgetEvent> _handleToggle() {
    final node = cursorNode;
    if (node == null || node.isLeaf) return const [];

    if (_expanded.contains(node.path)) {
      return collapse(node.path);
    }
    return expand(node.path);
  }

  TreeActivateEvent<T>? _handleConfirm() {
    final node = cursorNode;
    if (node == null) return null;
    return TreeActivateEvent<T>(id, node.path, node);
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// Default key bindings for TreeView.
final defaultTreeViewBindings = KeyBinding<TreeViewAction>()
  ..map(['up', 'k'], TreeViewAction.up)
  ..map(['down', 'j'], TreeViewAction.down)
  ..map(['home'], TreeViewAction.first)
  ..map(['end', 'G'], TreeViewAction.last)
  ..map(['pageUp', 'ctrl+b'], TreeViewAction.pageUp)
  ..map(['pageDown', 'ctrl+d'], TreeViewAction.pageDown)
  ..map(['right', 'l'], TreeViewAction.expand)
  ..map(['left', 'h'], TreeViewAction.collapse)
  ..map(['o'], TreeViewAction.toggle)
  ..map(['enter'], TreeViewAction.confirm);
