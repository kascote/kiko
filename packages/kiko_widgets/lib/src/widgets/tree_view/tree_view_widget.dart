import 'package:kiko/kiko.dart';

import 'tree_node.dart';
import 'tree_view_model.dart';

/// State passed to nodeBuilder for each node.
typedef NodeState = ({
  bool focused,
  bool expanded,
  bool loading,
});

/// A hierarchical tree widget with expand/collapse.
///
/// Renders nodes from a [TreeViewModel] with indentation based on depth.
///
/// ```dart
/// TreeView<FileInfo>(
///   model: treeModel,
///   nodeBuilder: (node, depth, state) {
///     final prefix = state.focused ? '> ' : '  ';
///     final expandIcon = node.isLeaf ? '  ' : (state.expanded ? '▼ ' : '▶ ');
///     return Line('$prefix$expandIcon${node.icon ?? ''} ')
///         .addLine(node.label);
///   },
/// )
/// ```
class TreeView<T> extends Widget {
  /// The model containing tree state.
  final TreeViewModel<T> model;

  /// Builds widget for each node.
  ///
  /// Parameters:
  /// - `node`: The tree node
  /// - `depth`: Node depth (0 for roots)
  /// - `state`: Node state (focused, expanded, loading)
  final Widget Function(TreeNode<T> node, int depth, NodeState state)? nodeBuilder;

  /// Style for focused node row.
  final Style? focusedStyle;

  /// Style for unfocused node rows.
  final Style? unfocusedStyle;

  /// Shown when tree is empty (no roots loaded).
  final Widget? emptyPlaceholder;

  /// Creates a TreeView widget.
  TreeView({
    required this.model,
    this.nodeBuilder,
    this.focusedStyle,
    this.unfocusedStyle,
    this.emptyPlaceholder,
  });

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final renderArea = area.intersection(frame.buffer.area);
    if (renderArea.isEmpty) return;

    final m = model;
    final nodes = m.flatNodes;

    // 1. If not loaded or empty, render placeholder
    if (!m.isLoaded || nodes.isEmpty) {
      if (emptyPlaceholder != null) {
        emptyPlaceholder!.render(renderArea, frame);
      }
      return;
    }

    // 2. Calculate visible count
    final visibleCount = renderArea.height;
    if (visibleCount <= 0) return;

    // 3. Update model's visible count
    m.setVisibleCount(visibleCount);

    // 4. Get scroll offset
    final scrollOffset = m.scrollOffset;

    // 5. Calculate visible range
    final startIndex = scrollOffset;
    final endIndex = (startIndex + visibleCount).clamp(0, nodes.length);

    // 6. Render visible nodes
    var y = renderArea.y;

    for (var i = startIndex; i < endIndex; i++) {
      final node = nodes[i];
      final isFocused = i == m.cursorIndex;
      final isExpanded = m.isExpanded(node.path);
      final isLoading = m.isPathLoading(node.path);

      final rowArea = Rect.create(
        x: renderArea.x,
        y: y,
        width: renderArea.width,
        height: 1,
      );
      if (rowArea.isEmpty) break;

      // Apply row background style
      if (isFocused && focusedStyle != null) {
        frame.buffer.setStyle(rowArea, focusedStyle!);
      } else if (!isFocused && unfocusedStyle != null) {
        frame.buffer.setStyle(rowArea, unfocusedStyle!);
      }

      final state = (
        focused: isFocused,
        expanded: isExpanded,
        loading: isLoading,
      );

      // Build node widget
      final nodeWidget = nodeBuilder != null
          ? nodeBuilder!(node, node.depth, state)
          : _defaultNodeBuilder(node, state, m);

      // Calculate indent
      final indent = node.depth * m.indentWidth;
      final contentArea = Rect.create(
        x: renderArea.x + indent,
        y: y,
        width: (renderArea.width - indent).clamp(0, renderArea.width),
        height: 1,
      );

      if (contentArea.width > 0) {
        nodeWidget.render(contentArea, frame);
      }

      y++;
    }
  }

  Widget _defaultNodeBuilder(
    TreeNode<T> node,
    NodeState state,
    TreeViewModel<T> m,
  ) {
    final spans = <Span>[];

    // Expand/collapse indicator or leaf padding
    if (node.isLeaf) {
      // 2 spaces to match indicator width (char + space)
      spans.add(const Span('  '));
    } else {
      final char = state.loading
          ? m.loadingChar
          : state.expanded
              ? m.expandedChar
              : m.collapsedChar;
      spans.add(Span('$char ', style: m.indicatorStyle));
    }

    // Icon + space before label (only if showIcons enabled)
    if (m.showIcons && node.icon != null) {
      spans.add(Span('${node.icon!} '));
    }

    // Label spans (preserves styles)
    spans.addAll(node.label.spans);

    return Line.fromSpans(
      spans,
      style: node.label.style,
      alignment: node.label.alignment,
    );
  }
}
