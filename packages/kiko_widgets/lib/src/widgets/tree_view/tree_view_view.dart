import 'package:kiko/kiko.dart';

import 'tree_node.dart';
import 'tree_view_model.dart';
import 'types.dart';

/// Builds a TreeView as a plume node — the plume-native view for
/// [TreeViewModel].
///
/// plume owns the outer frame: an optional [border] with [borderStyle] and edge
/// titles. The scrolling body is a custom node that windows the model's flat,
/// visible nodes and paints them through the plume paint protocol — each row
/// indented by its depth, drawn by [nodeBuilder] or a default builder showing
/// the expand indicator, icon, and label, with an [emptyPlaceholder] until the
/// roots load. Row backgrounds come from the node's state (focused / loading)
/// via the theme, overridable with [styleOverrides]. The subtree root is stamped
/// with the model id so a click routes back through [Frame.hitId].
Node treeView<T>({
  required TreeViewModel<T> model,
  required Theme theme,
  Line Function(TreeNode<T> node, int depth, NodeState state)? nodeBuilder,
  Map<WidgetState, Style>? styleOverrides,
  Line? emptyPlaceholder,
  BorderType border = BorderType.none,
  Style borderStyle = const Style(),
  List<Line> topTitles = const <Line>[],
  List<Line> bottomTitles = const <Line>[],
}) {
  return box(
    border: border,
    borderStyle: borderStyle,
    topTitles: topTitles,
    bottomTitles: bottomTitles,
    child: _TreeViewport<T>(
      model: model,
      theme: theme,
      nodeBuilder: nodeBuilder,
      styleOverrides: styleOverrides,
      emptyPlaceholder: emptyPlaceholder,
    ),
  )..tag = model.id;
}

/// The self-painting body of a [treeView]: fills the space the box gives it and
/// paints the model's visible window of tree rows through the plume `Surface`.
class _TreeViewport<T> extends Node {
  _TreeViewport({
    required this.model,
    required this.theme,
    this.nodeBuilder,
    this.styleOverrides,
    this.emptyPlaceholder,
  });

  final TreeViewModel<T> model;
  final Theme theme;
  final Line Function(TreeNode<T> node, int depth, NodeState state)? nodeBuilder;
  final Map<WidgetState, Style>? styleOverrides;
  final Line? emptyPlaceholder;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) =>
      constraints.constrain(Size(constraints.maxW ?? 0, constraints.maxH ?? 0));

  @override
  void paintSelf(Surface surface) {
    final clip = surface.clipRect ?? rect;
    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    if (area.isEmpty) return;
    _paint(area, surface);
  }

  void _paint(Rect area, Surface surface) {
    final m = model;
    final nodes = m.flatNodes;

    if (!m.isLoaded || nodes.isEmpty) {
      final placeholder = emptyPlaceholder;
      if (placeholder != null) {
        paintLine(surface, placeholder, x: area.x, y: area.y, width: area.width);
      }
      return;
    }

    final visibleCount = area.height;
    if (visibleCount <= 0) return;
    m.setVisibleCount(visibleCount);

    final startIndex = m.scrollOffset;
    final endIndex = (startIndex + visibleCount).clamp(0, nodes.length);

    var y = area.y;
    for (var i = startIndex; i < endIndex; i++) {
      final node = nodes[i];
      final isFocused = i == m.cursor;
      final isExpanded = m.isExpanded(node.path);
      final isLoading = m.isPathLoading(node.path);

      final rowArea = Rect.create(x: area.x, y: y, width: area.width, height: 1);
      if (rowArea.isEmpty) break;

      final states = <WidgetState>{
        if (isFocused) WidgetState.focused,
        if (isLoading) WidgetState.loading,
      };
      if (states.isNotEmpty) {
        final rowStyle = StyleResolver(theme).resolve(null, states, overrides: styleOverrides);
        fillRow(surface, x: rowArea.x, y: rowArea.y, width: rowArea.width, style: rowStyle);
      }

      final state = (focused: isFocused, expanded: isExpanded, loading: isLoading);
      final nodeLine = nodeBuilder != null ? nodeBuilder!(node, node.depth, state) : _defaultNode(node, state, m);

      final indent = node.depth * m.indentWidth;
      final contentWidth = (area.width - indent).clamp(0, area.width);
      if (contentWidth > 0) {
        paintLine(surface, nodeLine, x: area.x + indent, y: y, width: contentWidth);
      }

      y++;
    }
  }

  Line _defaultNode(TreeNode<T> node, NodeState state, TreeViewModel<T> m) {
    final spans = <Text>[];
    if (node.isLeaf) {
      spans.add(const Text('  '));
    } else {
      final char = state.loading
          ? m.loadingChar
          : state.expanded
          ? m.expandedChar
          : m.collapsedChar;
      spans.add(Text('$char ', style: m.indicatorStyle));
    }
    if (m.showIcons && node.icon != null) {
      spans.add(Text('${node.icon!} '));
    }
    spans.addAll(node.label.spans);
    return Line.fromSpans(spans, style: node.label.style);
  }
}
