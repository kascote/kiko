import 'package:kiko/kiko.dart';

import 'tree_node.dart';
import 'tree_view_model.dart';
import 'types.dart';

/// A TreeView as a view — the plume-native view for [TreeViewModel].
///
/// A [Box] owns the outer frame: an optional [border] with [borderStyle] and
/// edge titles. The scrolling body is a custom node that windows the model's
/// flat, visible nodes and paints them through the plume paint protocol — each
/// row indented by its depth, drawn by [nodeBuilder] or a default builder
/// showing the expand indicator, icon, and label, with an [emptyPlaceholder]
/// until the roots load. Row backgrounds come from the node's state (focused /
/// loading) via the theme, overridable with [styleOverrides]. The built subtree
/// is stamped with the model id so a click routes back through [Frame.hitId].
final class TreeView<T> implements View {
  /// Creates a tree view over [model], styled by [theme] and built row by row
  /// through [nodeBuilder].
  const TreeView({
    required this.model,
    required this.theme,
    this.nodeBuilder,
    this.styleOverrides,
    this.emptyPlaceholder,
    this.border = BorderType.none,
    this.borderStyle = const Style(),
    this.topTitles = const <Line>[],
    this.bottomTitles = const <Line>[],
  });

  /// The model whose visible nodes, cursor, and expansion this view renders.
  final TreeViewModel<T> model;

  /// The theme that resolves row and border styles.
  final Theme theme;

  /// Builds the line for a node at a given depth and state, or `null` to use the
  /// default row (expand indicator, icon, and label).
  final Line Function(TreeNode<T> node, int depth, NodeState state)? nodeBuilder;

  /// Per-state style overrides applied on top of the theme's row styles.
  final Map<WidgetState, Style>? styleOverrides;

  /// The line shown until the roots load, or `null` for a blank body.
  final Line? emptyPlaceholder;

  /// The border drawn around the tree, or [BorderType.none] for no border.
  final BorderType border;

  /// The colour and modifiers of the border glyphs.
  final Style borderStyle;

  /// The titles riding on the top edge of the border.
  final List<Line> topTitles;

  /// The titles riding on the bottom edge of the border.
  final List<Line> bottomTitles;

  @override
  Node build() => Box(
    border: border,
    borderStyle: borderStyle,
    topTitles: topTitles,
    bottomTitles: bottomTitles,
    child: NodeView(
      _TreeViewport<T>(
        model: model,
        theme: theme,
        nodeBuilder: nodeBuilder,
        styleOverrides: styleOverrides,
        emptyPlaceholder: emptyPlaceholder,
      ),
    ),
  ).build()..tag = model.id;
}

/// The self-painting body of a [TreeView]: fills the space the box gives it and
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
