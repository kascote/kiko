import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import '../row_region.dart';
import 'tree_node.dart';

// ═══════════════════════════════════════════════════════════
// HIT REGIONS
// ═══════════════════════════════════════════════════════════

/// A node's expand/collapse indicator, marked only when the default node
/// builder actually paints one.
///
/// It is [RowScoped] because it lives on a node's row: a press on it toggles
/// the branch, but a mere hover over it still highlights the node's row, the
/// same as a hover anywhere else on the row. With a custom node builder no
/// indicator is painted, so no indicator region exists — a press in the indent
/// then resolves to the plain [RowRegion] and activates the node, instead of
/// toggling a branch on geometry the builder never drew.
@immutable
class TreeIndicatorRegion implements RowScoped {
  /// Names the indicator on the node at row [index].
  const TreeIndicatorRegion(this.index);

  @override
  final int index;

  @override
  bool operator ==(Object other) => other is TreeIndicatorRegion && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'TreeIndicatorRegion($index)';
}

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
///
/// - `cursor`: true if the keyboard cursor is on this node (the current node)
/// - `hover`: true if the pointer sits over this node
/// - `loading`: true if the node's children are being fetched
/// - `expanded`: true if the node is open
typedef NodeState = ({
  bool cursor,
  bool hover,
  bool loading,
  bool expanded,
});

// ═══════════════════════════════════════════════════════════
// STYLES
// ═══════════════════════════════════════════════════════════

/// TreeView's anatomy: one nullable style slot per part.
///
/// A `null` slot is derived from the resolver's tones by the rule below. A
/// non-null slot is the caller's exact style: it replaces that state's
/// built-in effect. See [StyleResolver.resolve].
///
/// | slot          | derived default                | resolver call          |
/// | ------------- | ------------------------------ | ---------------------- |
/// | `item`        | none (inherits the pane's ground) | row, fill           |
/// | `cursorItem`  | the row lifted one step        | row, `cursor` slot     |
/// | `indicator`   | none (inherits the row)        | glyph, ink             |
/// | `placeholder` | `resolver.ink(muted)`          | label, ink             |
///
/// A row is one [StyleResolver.resolve] call, always a fill, over the `item`
/// base. The cursor row marks `cursor`, and `focused` too while the tree owns
/// focus. A cursor step is one state step in OKLab lightness away from the
/// row's own background, or from the ground the resolver is bound to when the
/// row is bare. A focused tree adds bold. Hover is half a step in the same
/// direction. The tree has no selection set, so no `selectedItem`. The
/// `indicator` glyph is its own call: a node whose children are being fetched
/// marks `loading` on it, a warning ink with a slow blink, never on the row.
/// A failed placeholder row resolves `error` over the `placeholder` base.
class TreeViewStyle {
  /// Base row style (usually left null to inherit the pane's own fill).
  final Style? item;

  /// The current node — the keyboard cursor position.
  final Style? cursorItem;

  /// The expand, collapse, and loading glyph.
  final Style? indicator;

  /// The empty-state line shown until the roots load.
  final Style? placeholder;

  /// Creates a TreeViewStyle.
  const TreeViewStyle({
    this.item,
    this.cursorItem,
    this.indicator,
    this.placeholder,
  });
}

// ═══════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════

/// Emitted when a node is expanded.
///
/// Equality is by [id] + [path] — the canonical address of the expansion.
/// [node] is a carried handle to the node at [path] and is excluded (it is
/// identity-compared, so folding it into value equality would defeat it).
@immutable
class TreeExpandEvent<T> extends WidgetEvent {
  /// Id of the tree view model.
  @override
  final String id;

  /// Path of the expanded node.
  final String path;

  /// The expanded node.
  final TreeNode<T> node;

  /// Creates a TreeExpandEvent.
  const TreeExpandEvent(this.id, this.path, this.node);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreeExpandEvent<T> && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'TreeExpandEvent($id, $path)';
}

/// Emitted when a node is collapsed.
///
/// Equality is by [id] + [path]; see [TreeExpandEvent] for why [node] is excluded.
@immutable
class TreeCollapseEvent<T> extends WidgetEvent {
  /// Id of the tree view model.
  @override
  final String id;

  /// Path of the collapsed node.
  final String path;

  /// The collapsed node.
  final TreeNode<T> node;

  /// Creates a TreeCollapseEvent.
  const TreeCollapseEvent(this.id, this.path, this.node);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreeCollapseEvent<T> && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'TreeCollapseEvent($id, $path)';
}

/// Emitted when execute an action in the current item
///
/// Equality is by [id] + [path]; see [TreeExpandEvent] for why [node] is excluded.
@immutable
class TreeActivateEvent<T> extends WidgetEvent {
  /// Id of the tree view model.
  @override
  final String id;

  /// Path of the confirmed node.
  final String path;

  /// The confirmed node.
  final TreeNode<T> node;

  /// Creates a TreeActivateEvent.
  const TreeActivateEvent(this.id, this.path, this.node);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreeActivateEvent<T> && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'TreeActivateEvent($id, $path)';
}
