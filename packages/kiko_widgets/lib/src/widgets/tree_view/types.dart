import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import 'tree_node.dart';

// ═══════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════

/// Actions for TreeView key bindings.
enum TreeViewAction {
  /// Move cursor up one node.
  up,

  /// Move cursor down one node.
  down,

  /// Move cursor to first visible node.
  first,

  /// Move cursor to last visible node.
  last,

  /// Move cursor up one page.
  pageUp,

  /// Move cursor down one page.
  pageDown,

  /// Expand current node (or move to first child if already expanded).
  expand,

  /// Collapse current node (or move to parent if already collapsed).
  collapse,

  /// Toggle expand/collapse.
  toggle,

  /// Confirm/activate current node.
  confirm,
}

// ═══════════════════════════════════════════════════════════
// SCROLL STATE
// ═══════════════════════════════════════════════════════════

/// Scroll position info for external scrollbar.
class TreeScrollState {
  /// Scroll offset (first visible row index).
  final int offset;

  /// Number of visible rows.
  final int visible;

  /// Total visible node count.
  final int total;

  /// Creates a TreeScrollState.
  const TreeScrollState({
    required this.offset,
    required this.visible,
    required this.total,
  });

  /// Scroll progress 0.0-1.0.
  double? get progress {
    if (total <= visible) return null;
    return offset / (total - visible);
  }

  /// Thumb size as fraction 0.0-1.0.
  double? get thumbSize {
    if (total == 0) return null;
    return (visible / total).clamp(0.1, 1.0);
  }
}

// ═══════════════════════════════════════════════════════════
// NODE STATE
// ═══════════════════════════════════════════════════════════

/// State passed to nodeBuilder for each node.
typedef NodeState = ({
  bool focused,
  bool expanded,
  bool loading,
});

// ═══════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════

/// Emitted when a node is expanded.
///
/// Equality is by [id] + [path] — the canonical address of the expansion.
/// [node] is a carried handle to the node at [path] and is excluded (it is
/// identity-compared, so folding it into value equality would defeat it).
@immutable
class TreeExpandCmd<T> extends Cmd {
  /// Id of the tree view model.
  final String id;

  /// Path of the expanded node.
  final String path;

  /// The expanded node.
  final TreeNode<T> node;

  /// Creates a TreeExpandCmd.
  const TreeExpandCmd(this.id, this.path, this.node);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreeExpandCmd<T> && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'TreeExpandCmd($id, $path)';
}

/// Emitted when a node is collapsed.
///
/// Equality is by [id] + [path]; see [TreeExpandCmd] for why [node] is excluded.
@immutable
class TreeCollapseCmd<T> extends Cmd {
  /// Id of the tree view model.
  final String id;

  /// Path of the collapsed node.
  final String path;

  /// The collapsed node.
  final TreeNode<T> node;

  /// Creates a TreeCollapseCmd.
  const TreeCollapseCmd(this.id, this.path, this.node);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreeCollapseCmd<T> && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'TreeCollapseCmd($id, $path)';
}

/// Emitted when execute an action in the current item
///
/// Equality is by [id] + [path]; see [TreeExpandCmd] for why [node] is excluded.
@immutable
class TreeActionCmd<T> extends Cmd {
  /// Id of the tree view model.
  final String id;

  /// Path of the confirmed node.
  final String path;

  /// The confirmed node.
  final TreeNode<T> node;

  /// Creates a TreeActionCmd.
  const TreeActionCmd(this.id, this.path, this.node);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreeActionCmd<T> && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'TreeActionCmd($id, $path)';
}
