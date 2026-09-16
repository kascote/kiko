import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../../load/viewport_changed.dart';
import '../row_region.dart';
import 'tree_node.dart';
import 'tree_view_model.dart';
import 'types.dart';

/// A TreeView as a view — the plume-native view for [TreeViewModel].
///
/// This is the scrolling body on its own, with no frame around it: a custom node
/// that windows the model's flat, visible nodes and paints them through the plume
/// paint protocol — each row indented by its depth, drawn by [nodeBuilder] or a
/// default builder showing the expand indicator, icon, and label, with an
/// [emptyPlaceholder] until the roots load. Beneath an expanded node whose
/// children are missing, the view paints a placeholder row itself, labeled by
/// [loadingLabel], [errorLabel], or [stalledLabel]; it never passes that row
/// to [nodeBuilder]. Row
/// backgrounds come from the node's honest state (cursor / loading) painted
/// through [style]'s [TreeViewStyle] anatomy, each `null` slot deriving from
/// the theme's tones. A per-instance state look is a theme variant passed to
/// [theme]. Wrap it in a [Container] for a border or edge titles. The node is
/// stamped with the model id so a click routes back through [HitMap.hitId].
final class TreeView<T> implements View {
  /// Creates a tree view over [model], styled by [theme] and built row by row
  /// through [nodeBuilder].
  const TreeView({
    required this.model,
    required this.theme,
    this.nodeBuilder,
    this.style = const TreeViewStyle(),
    this.emptyPlaceholder,
    this.loadingLabel,
    this.errorLabel,
    this.stalledLabel,
  });

  /// The model whose visible nodes, cursor, and expansion this view renders.
  final TreeViewModel<T> model;

  /// The theme that resolves row styles.
  final Theme theme;

  /// Builds the line for a node at a given depth and state, or `null` to use the
  /// default row (expand indicator, icon, and label).
  final Line Function(TreeNode<T> node, int depth, NodeState state)? nodeBuilder;

  /// Row anatomy overrides. See [TreeViewStyle].
  final TreeViewStyle style;

  /// The line shown until the roots load, or `null` for a blank body.
  final Line? emptyPlaceholder;

  /// The placeholder row shown beneath a node while its children load.
  ///
  /// Null shows 'Loading…'. A given line's own styling wins over the themed
  /// base ([TreeViewStyle.placeholder], or the theme's muted ink).
  final Line? loadingLabel;

  /// The placeholder row shown beneath a node whose child load failed.
  ///
  /// Null shows 'Failed to load'; styling as for [loadingLabel], patched over
  /// the error tone.
  final Line? errorLabel;

  /// The placeholder row shown beneath an expanded node whose children are
  /// missing with nothing on the way — a refused load ([SliceStatus.stalled]).
  ///
  /// Null shows 'Not loaded'; styling as for [loadingLabel].
  final Line? stalledLabel;

  @override
  Node build() => _TreeViewport<T>(
    model: model,
    theme: theme,
    nodeBuilder: nodeBuilder,
    style: style,
    emptyPlaceholder: emptyPlaceholder,
    loadingLabel: loadingLabel,
    errorLabel: errorLabel,
    stalledLabel: stalledLabel,
  )..tag = IdTag(model.id);
}

/// The self-painting body of a [TreeView]: fills the space the box gives it and
/// paints the model's visible window of tree rows through the plume `Surface`.
class _TreeViewport<T> extends Node {
  _TreeViewport({
    required this.model,
    required this.theme,
    required this.style,
    this.nodeBuilder,
    this.emptyPlaceholder,
    this.loadingLabel,
    this.errorLabel,
    this.stalledLabel,
  });

  final TreeViewModel<T> model;
  final Theme theme;
  final Line Function(TreeNode<T> node, int depth, NodeState state)? nodeBuilder;
  final TreeViewStyle style;
  final Line? emptyPlaceholder;
  final Line? loadingLabel;
  final Line? errorLabel;
  final Line? stalledLabel;

  // Captured from the layout context so paint measures text the way the frame
  // does — a cjk frame reaches the rows, not just the box chrome.
  TextMeasurer _measurer = const TermUnicodeMeasurer();

  /// Resolves the anatomy slots that derive from theme tones + state.
  late final _resolver = StyleResolver(theme);

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    _measurer = context.measurer;
    return constraints.constrain(Size(constraints.maxW ?? 0, constraints.maxH ?? 0));
  }

  @override
  void paintSelf(Surface surface) {
    final clip = surface.clipRect;
    if (clip == null || clip.isEmpty) return;
    // Anchor at the placement rect, not the (possibly narrower) clip: a
    // clipping ancestor trims which cells actually draw, but the row
    // windowing must stay keyed to the widget's own laid-out size, or a
    // partially scrolled-off tree pins its content to the viewport edge.
    final area = Rect.create(x: rect.x, y: rect.y, width: rect.width, height: rect.height);
    _paint(area, surface);
  }

  void _paint(Rect area, Surface surface) {
    final m = model;
    final nodes = m.flatNodes;

    if (!m.isLoaded || nodes.isEmpty) {
      _paintEmpty(area, surface);
      return;
    }

    final visibleCount = area.height;
    if (visibleCount <= 0) return;
    // Report the count only while the model does not hold it.
    if (surface is BufferSurface && visibleCount != m.visibleCount) {
      surface.report(ViewportChanged(HitTag.join(surface.scopePath, m.id), rows: visibleCount));
    }

    final startIndex = m.scrollOffset;
    final endIndex = (startIndex + visibleCount).clamp(0, nodes.length);

    var y = area.y;
    for (var i = startIndex; i < endIndex; i++) {
      final rowArea = Rect.create(x: area.x, y: y, width: area.width, height: 1);
      if (rowArea.isEmpty) break;

      // Mark the whole node row first, so a pointer anywhere on it resolves to
      // the node.
      markRegion(RowRegion(i), rowArea.toPlume());
      _paintRow(surface, rowArea, i, nodes[i]);
      y++;
    }
  }

  /// Paints the empty-state line, when there is one.
  void _paintEmpty(Rect area, Surface surface) {
    final placeholder = emptyPlaceholder;
    if (placeholder == null) return;
    paintLine(
      surface,
      placeholder,
      x: area.x,
      y: area.y,
      width: area.width,
      base: _placeholderStyle(),
      measurer: _measurer,
    );
  }

  /// Paints [node], the row at [index], into [rowArea]: its state fill first,
  /// then its line at the node's indent, then the expand indicator's region.
  void _paintRow(Surface surface, Rect rowArea, int index, TreeNode<T> node) {
    final m = model;
    final isCursor = index == m.cursor;
    final isHover = m.hoverRow == index;
    final styled = style.item != null || isCursor || isHover;
    if (styled) {
      final rowStyle = _rowStyle(isCursor: isCursor, isHover: isHover);
      fillRow(surface, x: rowArea.x, y: rowArea.y, width: rowArea.width, style: rowStyle);
    }

    final state = (
      cursor: isCursor,
      hover: isHover,
      loading: m.isPathLoading(node.path),
      expanded: m.isExpanded(node.path),
    );
    final nodeLine = _nodeLine(node, state);
    final indent = node.depth * m.indentWidth;
    final contentWidth = (rowArea.width - indent).clamp(0, rowArea.width);
    if (contentWidth > 0) {
      paintLine(surface, nodeLine, x: rowArea.x + indent, y: rowArea.y, width: contentWidth, measurer: _measurer);
    }

    // The default builder draws a two-cell expand indicator at the indent for
    // a non-leaf node. Mark it — on top of the row, so a click on it wins the
    // overlap — only when it is actually painted: a custom nodeBuilder draws
    // no indicator, so none exists to hit, and a press there falls through to
    // the row and activates instead of toggling geometry that was never drawn.
    if (nodeBuilder == null && !node.isLeaf) {
      final indicator = Rect.create(x: rowArea.x + indent, y: rowArea.y, width: 2, height: 1).intersection(rowArea);
      if (!indicator.isEmpty) {
        markRegion(TreeIndicatorRegion(index), indicator.toPlume());
      }
    }
  }

  /// Resolves the row base through its cursor and hover states.
  ///
  /// The row base goes to the resolver with its active states, so the
  /// resolver — not this widget — decides how a state lands on it. The cursor
  /// paints as a fill when the tree owns focus and as a wash when it does not;
  /// a colored base lifts either way instead of one state's fill replacing
  /// another's. Hover applies last, inside the resolver, in its own call. The
  /// loading state paints the indicator glyph alone, never the row.
  Style _rowStyle({required bool isCursor, required bool isHover}) {
    final rowStyle = _resolver.resolve(
      style.item ?? const Style(),
      {if (isCursor) WidgetState.cursor},
      cls: model.focused ? PaintClass.fill : PaintClass.wash,
      slots: {if (style.cursorItem != null) WidgetState.cursor: style.cursorItem!},
    );
    return _resolver.resolve(rowStyle, {if (isHover) WidgetState.hover}, cls: PaintClass.fill);
  }

  /// The line for [node]: a placeholder row's label, the caller's builder, or
  /// the default node.
  Line _nodeLine(TreeNode<T> node, NodeState state) {
    final placeholder = node.placeholder;
    if (placeholder != null) return _placeholderLine(placeholder);
    if (nodeBuilder case final build?) return build(node, node.depth, state);
    return _defaultNode(node, state, model);
  }

  Line _defaultNode(TreeNode<T> node, NodeState state, TreeViewModel<T> m) {
    final texts = <Text>[];
    if (node.isLeaf) {
      texts.add(const Text('  '));
    } else {
      final char = state.loading
          ? m.loadingChar
          : state.expanded
          ? m.expandedChar
          : m.collapsedChar;
      texts.add(Text('$char ', style: _indicatorStyle(state.loading)));
    }
    if (m.showIcons && node.icon != null) {
      texts.add(Text('${node.icon!} '));
    }
    texts.addAll(node.label.texts);
    return Line.fromTexts(texts, style: node.label.style);
  }

  /// Builds the row for a placeholder node: no expand glyph — a blank run the
  /// width of one, the same as a leaf gets — then the matching label over the
  /// [_placeholderStyle] base, with an `error` × `ink` patch first on a failed
  /// row.
  Line _placeholderLine(SliceStatus status) {
    var base = _placeholderStyle();
    if (status == SliceStatus.failed) {
      base = base.patch(_resolver.resolve(null, const {WidgetState.error}, cls: PaintClass.ink));
    }
    final label = switch (status) {
      SliceStatus.filling => loadingLabel ?? Line('Loading…'),
      SliceStatus.failed => errorLabel ?? Line('Failed to load'),
      SliceStatus.stalled => stalledLabel ?? Line('Not loaded'),
      SliceStatus.ready => throw StateError('a placeholder node is never SliceStatus.ready'),
    };
    return Line.fromTexts([const Text('  '), ...label.texts], style: label.style).over(base);
  }

  // ─────────────────────────────────────────────
  // Anatomy — derived defaults, overridable per instance or per theme
  // ─────────────────────────────────────────────

  /// The expand, collapse, and loading glyph — `indicator`, patched with the
  /// `loading` state (warning ink + slow blink) while [loading] is true.
  Style _indicatorStyle(bool loading) =>
      _resolver.resolve(style.indicator, {if (loading) WidgetState.loading}, cls: PaintClass.ink);

  /// The empty-state line shown until the roots load, and the base a
  /// placeholder row patches its label over.
  Style _placeholderStyle() => style.placeholder ?? _resolver.ink(_resolver.tones.muted);
}
