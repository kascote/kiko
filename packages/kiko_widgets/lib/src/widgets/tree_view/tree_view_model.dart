import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import 'tree_node.dart';
import 'types.dart';

/// Model for TreeView state and behavior.
///
/// Holds expansion state, cursor position, and the load state of each pending
/// fetch. Implements [Component] (stable [id] + [update]) for addressing and
/// focus, and [Loadable] so the app can install fetched data with [applyLoad].
///
/// The model performs no I/O. The app owns the data source and drives every
/// fetch: it calls [loadRoots] once to start, and [expand] returns a
/// [LoadRequest] when a node's children aren't loaded yet. The app turns each
/// request into a runtime `Task` and hands the outcome back through [applyLoad].
///
/// ```dart
/// final tree = TreeViewModel<FileInfo>(focused: true);
/// // app, on init:   final req = tree.loadRoots();  // → fetch getRoots()
/// // app, on result: tree.applyLoad(LoadResult(tree.id, key: req.key, data: roots));
/// ```
class TreeViewModel<T> implements Component, Loadable {
  /// Stable address for this model, carried by value in the widget→app commands
  /// it emits ([TreeExpandCmd], [TreeCollapseCmd], [TreeActionCmd], [LoadRequest]).
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

  /// Style for expand/collapse/loading indicators.
  final Style? indicatorStyle;

  /// Whether nodes display icons.
  final bool showIcons;

  /// Placeholder shown beneath a node while its children load.
  final Line loadingIndicator;

  /// Placeholder shown beneath a node whose child load failed.
  final Line errorIndicator;

  /// Anatomy overrides. Mutable so an app can swap in a custom look at runtime,
  /// the way it flips [focused].
  TreeViewStyle styles;

  /// Key bindings for tree actions.
  late final KeyBinding<TreeViewAction> keyBinding;

  /// Creates a TreeViewModel.
  TreeViewModel({
    String? id,
    this.expandedChar = '▼',
    this.collapsedChar = '▶',
    this.loadingChar = '◌',
    this.indicatorStyle,
    this.showIcons = false,
    Line? loadingIndicator,
    Line? errorIndicator,
    this.styles = const TreeViewStyle(),
    this.focused = false,
    KeyBinding<TreeViewAction>? keyBinding,
  }) : id = id ?? autoId('treeview'),
       loadingIndicator = loadingIndicator ?? Line('Loading...'),
       errorIndicator = errorIndicator ?? Line('Failed to load') {
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
  int get scrollOffset => _scrollOffset;

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

  /// Whether a node is expanded.
  bool isExpanded(String path) => _expanded.contains(path);

  /// Scroll state for external scrollbar.
  TreeScrollState getScrollState() => TreeScrollState(
    offset: _scrollOffset,
    visible: _visibleCount,
    total: _flatNodes.length,
  );

  /// Called by widget during render to update visible count.
  // ignore: use_setters_to_change_properties
  void setVisibleCount(int count) => _visibleCount = count;

  // ─────────────────────────────────────────────
  // Public API - Programmatic control
  // ─────────────────────────────────────────────

  /// Starts the initial root load: marks the roots slot loading and returns the
  /// [LoadRequest] for the app to fetch.
  ///
  /// The app calls this once (e.g. on init), turns the request into a `getRoots`
  /// fetch, and installs the result via [applyLoad]/[applyRoots]. Until then,
  /// `isLoading(const RootsKey())` is true.
  LoadRequest loadRoots() {
    _loads.begin(const RootsKey());
    return LoadRequest(id, key: const RootsKey());
  }

  /// Installs the outcome of a load and clears (or fails) its slot.
  ///
  /// This is the app's single entry point for delivering fetched data, keyed by
  /// [LoadResult.key]: [RootsKey] installs roots, [PathKey] installs one node's
  /// children. A result for another model (by id) or an unknown key is ignored.
  ///
  /// Child results are guarded: only a node whose load is still in flight accepts
  /// one, so a late reply for a collapsed or already-loaded node is dropped rather
  /// than corrupting the tree. Roots have no such guard — they load once.
  @override
  void applyLoad(LoadResult<Object?> result) {
    if (result.id != id) return;
    switch (result.key) {
      case RootsKey():
        _installRoots(result);
      case PathKey(:final path):
        _installChildren(path, result);
      default:
        // Unknown key — nothing to install.
        return;
    }
  }

  /// Installs fetched root [roots]. Typed shorthand for [applyLoad] with a
  /// [RootsKey].
  void applyRoots(List<TreeNode<T>> roots) =>
      applyLoad(LoadResult<List<TreeNode<T>>>(id, key: const RootsKey(), data: roots));

  /// Installs fetched [children] for [path]. Typed shorthand for [applyLoad] with
  /// a [PathKey].
  ///
  /// Subject to the staleness guard: the node's load must be in flight (started
  /// by [expand]); a result for a collapsed or idle path is dropped.
  void applyChildren(String path, List<TreeNode<T>> children) =>
      applyLoad(LoadResult<List<TreeNode<T>>>(id, key: PathKey(path), data: children));

  void _installRoots(LoadResult<Object?> result) {
    if (result.ok) {
      _roots = (result.data as List<TreeNode<T>>?) ?? <TreeNode<T>>[];
      _rootsLoaded = true;
      _loads.complete(const RootsKey());
    } else {
      _loads.fail(const RootsKey(), result.error!);
    }
    _rebuildFlatNodes();
  }

  void _installChildren(String path, LoadResult<Object?> result) {
    // Staleness guard: drop results for nodes that are no longer loading
    // (collapsed, already loaded, or never requested).
    if (!_loads.stateFor(PathKey(path)).isLoading) return;
    if (result.ok) {
      _childrenCache[path] = (result.data as List<TreeNode<T>>?) ?? <TreeNode<T>>[];
      _loads.complete(PathKey(path));
    } else {
      _loads.fail(PathKey(path), result.error!);
    }
    _rebuildFlatNodes();
  }

  /// Expand a node.
  ///
  /// Returns `null` if the node can't expand (leaf, missing, or already open).
  /// Otherwise emits a [TreeExpandCmd] event on every expansion. When the node's
  /// children aren't loaded yet, it also emits a [LoadRequest] (the two wrapped in
  /// a [Batch]) and shows a loading placeholder; the app drives the fetch and
  /// installs the result with [applyLoad]. The widget never performs I/O.
  Cmd? expand(String path) {
    if (_expanded.contains(path)) return null;

    final node = _findNode(path);
    if (node == null || node.isLeaf) return null;

    _expanded.add(path);
    final event = TreeExpandCmd<T>(id, path, node);

    // Children already cached, or a load already in flight: just the event.
    if (_childrenCache.containsKey(path) || _loads.isLoading(PathKey(path))) {
      _rebuildFlatNodes();
      return event;
    }

    // Children not loaded: event + load request; mark the slot so we don't ask
    // twice.
    _loads.begin(PathKey(path));
    _rebuildFlatNodes();
    return Batch([event, LoadRequest(id, key: PathKey(path))]);
  }

  /// Collapse a node.
  Cmd? collapse(String path) {
    if (!_expanded.contains(path)) return null;

    final node = _findNode(path);
    if (node == null) return null;

    _expanded.remove(path);
    // Cancel any pending or failed load: a late result must not resurrect a
    // collapsed subtree, and re-expanding should retry from scratch.
    _loads.complete(PathKey(path));
    _rebuildFlatNodes();

    // Adjust cursor if it was in collapsed subtree
    if (_cursor >= _flatNodes.length) {
      _cursor = _flatNodes.isEmpty ? 0 : _flatNodes.length - 1;
    }

    return TreeCollapseCmd<T>(id, path, node);
  }

  /// Toggle expand/collapse.
  ///
  /// When expanding an uncached node, returns the [Batch] load request from
  /// [expand]; when collapsing, a [TreeCollapseCmd]; otherwise the expand event.
  Cmd? toggle(String path) {
    if (_expanded.contains(path)) {
      return collapse(path);
    }
    return expand(path);
  }

  /// Expand all cached ancestors of [path], then scroll to it if visible.
  ///
  /// Best-effort over already-loaded data: ancestors whose children are not yet
  /// cached cannot be revealed here (the widget performs no I/O). Load the needed
  /// subtree first (via [expand] + [applyLoad]), then call this.
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

    // Expand each cached ancestor (load requests for uncached ones are dropped).
    ancestors.forEach(expand);

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

  /// Handles keyboard messages. Returns command or [Unhandled].
  @override
  Cmd? update(Msg msg) {
    if (!focused) return const Unhandled();

    if (msg case KeyMsg()) {
      final action = keyBinding.resolve(msg);
      if (action == null) return const Unhandled();

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
          return _handleExpand();
        case TreeViewAction.collapse:
          return _handleCollapse();
        case TreeViewAction.toggle:
          return _handleToggle();
        case TreeViewAction.confirm:
          return _handleConfirm();
      }
    }

    return null;
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

        final state = _loads.stateFor(PathKey(node.path));
        if (state.isLoading) {
          _flatNodes.add(_placeholder(node.path, '_loading', loadingIndicator));
        } else if (state.failed) {
          _flatNodes.add(_placeholder(node.path, '_error', errorIndicator));
        } else {
          final children = _childrenCache[node.path];
          if (children != null) addNodes(children);
        }
      }
    }

    addNodes(_roots!);
  }

  TreeNode<T> _placeholder(String parentPath, String suffix, Line label) =>
      TreeNode<T>(path: '$parentPath/$suffix', label: label, isLeaf: true);

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

  Cmd? _handleExpand() {
    final node = cursorNode;
    if (node == null) return null;

    if (node.isLeaf) return null;

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
      return null;
    }

    // Request expansion — returns a Batch (expand event + load request) when the
    // node's children aren't cached yet (the app drives the fetch).
    return expand(node.path);
  }

  Cmd? _handleCollapse() {
    final node = cursorNode;
    if (node == null) return null;

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
      return null;
    }
  }

  Cmd? _handleToggle() {
    final node = cursorNode;
    if (node == null || node.isLeaf) return null;

    if (_expanded.contains(node.path)) {
      return collapse(node.path);
    }
    return expand(node.path);
  }

  Cmd? _handleConfirm() {
    final node = cursorNode;
    if (node == null) return null;
    return TreeActionCmd<T>(id, node.path, node);
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
