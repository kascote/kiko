import 'package:kiko/kiko.dart';

import 'tree_node.dart';
import 'tree_view_model.dart';

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
// COMMANDS
// ═══════════════════════════════════════════════════════════

/// Emitted when a node is expanded.
class TreeExpandCmd<T> extends Cmd {
  /// The tree view model.
  final TreeViewModel<T> source;

  /// Path of the expanded node.
  final String path;

  /// The expanded node.
  final TreeNode<T> node;

  /// Creates a TreeExpandCmd.
  const TreeExpandCmd(this.source, this.path, this.node);
}

/// Emitted when a node is collapsed.
class TreeCollapseCmd<T> extends Cmd {
  /// The tree view model.
  final TreeViewModel<T> source;

  /// Path of the collapsed node.
  final String path;

  /// The collapsed node.
  final TreeNode<T> node;

  /// Creates a TreeCollapseCmd.
  const TreeCollapseCmd(this.source, this.path, this.node);
}

/// Emitted on Enter/confirm action.
class TreeConfirmCmd<T> extends Cmd {
  /// The tree view model.
  final TreeViewModel<T> source;

  /// Path of the confirmed node.
  final String path;

  /// The confirmed node.
  final TreeNode<T> node;

  /// Creates a TreeConfirmCmd.
  const TreeConfirmCmd(this.source, this.path, this.node);
}
