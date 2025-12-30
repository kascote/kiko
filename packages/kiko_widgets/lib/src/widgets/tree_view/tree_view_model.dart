import 'dart:async';

import 'package:kiko/kiko.dart';

import 'tree_data_source.dart';
import 'tree_node.dart';
import 'types.dart';

/// Model for TreeView state and behavior.
///
/// Holds expansion state, selection state, and cursor position.
/// Implements [Focusable] for focus management.
///
/// ```dart
/// final treeModel = TreeViewModel<FileInfo>(
///   dataSource: myFileSource,
///   selectionMode: SelectionMode.leafOnly,
/// );
/// ```
class TreeViewModel<T> implements Focusable {
  /// The data source providing nodes.
  final TreeDataSource<T> dataSource;

  // ─────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────

  final Set<String> _expanded = {};
  final Set<String> _loading = {};
  final Map<String, List<TreeNode<T>>> _childrenCache = {};
  List<TreeNode<T>> _flatNodes = [];
  List<TreeNode<T>>? _roots;
  int _cursorIndex = 0;
  int _scrollOffset = 0;
  int _visibleCount = 0;
  bool _rootsLoaded = false;
  bool _rootsLoading = false;

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

  /// Loading indicator label.
  final Line loadingIndicator;

  /// Key bindings for tree actions.
  late final KeyBinding<TreeViewAction> keyBinding;

  /// Creates a TreeViewModel.
  TreeViewModel({
    required this.dataSource,
    this.expandedChar = '▼',
    this.collapsedChar = '▶',
    this.loadingChar = '◌',
    this.indicatorStyle,
    this.showIcons = false,
    Line? loadingIndicator,
    this.focused = false,
    KeyBinding<TreeViewAction>? keyBinding,
  }) : loadingIndicator = loadingIndicator ?? Line('Loading...') {
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
  int get cursorIndex => _cursorIndex;

  /// Current scroll offset.
  int get scrollOffset => _scrollOffset;

  /// Node at cursor, or null if empty.
  TreeNode<T>? get cursorNode =>
      _cursorIndex >= 0 && _cursorIndex < _flatNodes.length ? _flatNodes[_cursorIndex] : null;

  /// Whether roots have been loaded.
  bool get isLoaded => _rootsLoaded;

  /// Whether roots are currently loading.
  bool get isLoading => _rootsLoading;

  /// Whether a specific path is loading children.
  bool isPathLoading(String path) => _loading.contains(path);

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

  /// Load root nodes. Call this to initialize the tree.
  Future<void> loadRoots() async {
    if (_rootsLoaded || _rootsLoading) return;
    _rootsLoading = true;

    try {
      _roots = await dataSource.getRoots();
      _rootsLoaded = true;
      _rebuildFlatNodes();
    } finally {
      _rootsLoading = false;
    }
  }

  /// Expand a node, loading children if needed.
  Future<Cmd?> expand(String path) async {
    if (_expanded.contains(path)) return null;

    final node = _findNode(path);
    if (node == null || node.isLeaf) return null;

    // Check if children are cached
    if (!_childrenCache.containsKey(path)) {
      // Load children
      _loading.add(path);
      _expanded.add(path); // Show loading state
      _rebuildFlatNodes();

      try {
        final children = await dataSource.getChildren(path);
        _childrenCache[path] = children;
      } finally {
        _loading.remove(path);
      }
    } else {
      _expanded.add(path);
    }

    _rebuildFlatNodes();
    return TreeExpandCmd<T>(this, path, node);
  }

  /// Collapse a node.
  Cmd? collapse(String path) {
    if (!_expanded.contains(path)) return null;

    final node = _findNode(path);
    if (node == null) return null;

    _expanded.remove(path);
    _rebuildFlatNodes();

    // Adjust cursor if it was in collapsed subtree
    if (_cursorIndex >= _flatNodes.length) {
      _cursorIndex = _flatNodes.isEmpty ? 0 : _flatNodes.length - 1;
    }

    return TreeCollapseCmd<T>(this, path, node);
  }

  /// Toggle expand/collapse.
  Future<Cmd?> toggle(String path) async {
    if (_expanded.contains(path)) {
      return collapse(path);
    } else {
      return expand(path);
    }
  }

  /// Expand all ancestors to make a node visible, then scroll to it.
  Future<void> expandPath(String path) async {
    // Build list of ancestors
    final ancestors = <String>[];
    var current = path;
    while (true) {
      final lastSlash = current.lastIndexOf('/');
      if (lastSlash <= 0) break;
      current = current.substring(0, lastSlash);
      ancestors.insert(0, current);
    }

    // Expand each ancestor
    for (final ancestor in ancestors) {
      await expand(ancestor);
    }

    // Scroll to the node
    final index = _flatNodes.indexWhere((n) => n.path == path);
    if (index >= 0) {
      _cursorIndex = index;
      _adjustScrollToCursor();
    }
  }

  /// Collapse all expanded nodes.
  void collapseAll() {
    _expanded.clear();
    _rebuildFlatNodes();
    _cursorIndex = 0;
    _scrollOffset = 0;
  }

  /// Search loaded nodes for matching label text.
  List<TreeNode<T>> search(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    final results = <TreeNode<T>>[];

    void searchNodes(List<TreeNode<T>> nodes) {
      for (final node in nodes) {
        // Check if label contains query (simplified - checks raw spans)
        final labelText = node.label.spans.map((s) => s.content).join();
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
          _cursorIndex = 0;
          _adjustScrollToCursor();
        case TreeViewAction.last:
          if (_flatNodes.isNotEmpty) {
            _cursorIndex = _flatNodes.length - 1;
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

        if (_expanded.contains(node.path)) {
          if (_loading.contains(node.path)) {
            // Show loading placeholder
            _flatNodes.add(
              TreeNode<T>(
                path: '${node.path}/_loading',
                label: loadingIndicator,
                isLeaf: true,
              ),
            );
          } else {
            final children = _childrenCache[node.path];
            if (children != null) {
              addNodes(children);
            }
          }
        }
      }
    }

    addNodes(_roots!);
  }

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
    _cursorIndex = (_cursorIndex + delta).clamp(0, _flatNodes.length - 1);
    _adjustScrollToCursor();
  }

  void _adjustScrollToCursor() {
    if (_visibleCount <= 0) return;

    if (_cursorIndex < _scrollOffset) {
      _scrollOffset = _cursorIndex;
    } else if (_cursorIndex >= _scrollOffset + _visibleCount) {
      _scrollOffset = _cursorIndex - _visibleCount + 1;
    }
  }

  Cmd? _handleExpand() {
    final node = cursorNode;
    if (node == null) return null;

    if (node.isLeaf) return null;

    if (_expanded.contains(node.path)) {
      // Already expanded - move to first child
      if (_cursorIndex + 1 < _flatNodes.length) {
        final nextNode = _flatNodes[_cursorIndex + 1];
        // Check if next node is a child
        if (nextNode.path.startsWith('${node.path}/')) {
          _cursorIndex++;
          _adjustScrollToCursor();
        }
      }
      return null;
    }

    // Trigger async expand - this needs to be handled specially
    // Return a command that the runtime can handle
    _triggerExpand(node.path);
    return null;
  }

  void _triggerExpand(String path) {
    // Fire and forget - will update state when done
    unawaited(expand(path));
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
          _cursorIndex = parentIndex;
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
    } else {
      _triggerExpand(node.path);
      return null;
    }
  }

  Cmd? _handleConfirm() {
    final node = cursorNode;
    if (node == null) return null;
    return TreeConfirmCmd<T>(this, node.path, node);
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
