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
      final placeholder = emptyPlaceholder;
      if (placeholder != null) {
        paintLine(
          surface,
          placeholder.patchStyle(_placeholderStyle()),
          x: area.x,
          y: area.y,
          width: area.width,
          measurer: _measurer,
        );
      }
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
      final node = nodes[i];
      final isCursor = i == m.cursor;
      final isExpanded = m.isExpanded(node.path);
      final isLoading = m.isPathLoading(node.path);

      final rowArea = Rect.create(x: area.x, y: y, width: area.width, height: 1);
      if (rowArea.isEmpty) break;

      // Mark the whole node row first, so a pointer anywhere on it resolves to
      // the node.
      markRegion(RowRegion(i), rowArea.toPlume());

      // Honest anatomy, not borrowed states: the base item style, then the
      // hover wash (weakest, so the cursor reads over it), then the cursor
      // fill — each layer patches the last. The loading state paints the
      // indicator glyph alone, never the row.
      var rowStyle = style.item ?? const Style();
      var styled = style.item != null;
      if (m.hoverRow == i) {
        rowStyle = rowStyle.patch(_hoverItemStyle());
        styled = true;
      }
      if (isCursor) {
        rowStyle = rowStyle.patch(_cursorItemStyle());
        styled = true;
      }
      if (styled) {
        fillRow(surface, x: rowArea.x, y: rowArea.y, width: rowArea.width, style: rowStyle);
      }

      final state = (cursor: isCursor, expanded: isExpanded, loading: isLoading);
      final placeholder = node.placeholder;
      final nodeLine = placeholder != null
          ? _placeholderLine(placeholder)
          : nodeBuilder != null
          ? nodeBuilder!(node, node.depth, state)
          : _defaultNode(node, state, m);

      final indent = node.depth * m.indentWidth;
      final contentWidth = (area.width - indent).clamp(0, area.width);
      if (contentWidth > 0) {
        paintLine(surface, nodeLine, x: area.x + indent, y: y, width: contentWidth, measurer: _measurer);
      }

      // The default builder draws a two-cell expand indicator at the indent for
      // a non-leaf node. Mark it — on top of the row, so a click on it wins the
      // overlap — only when it is actually painted: a custom nodeBuilder draws
      // no indicator, so none exists to hit, and a press there falls through to
      // the row and activates instead of toggling geometry that was never drawn.
      if (nodeBuilder == null && !node.isLeaf) {
        final indicator = Rect.create(x: area.x + indent, y: y, width: 2, height: 1).intersection(rowArea);
        if (!indicator.isEmpty) {
          markRegion(TreeIndicatorRegion(i), indicator.toPlume());
        }
      }

      y++;
    }
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
  /// width of one, the same as a leaf gets — then the matching label patched
  /// over the [_placeholderStyle] base, with an `error` × `ink` patch first on
  /// a failed row.
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
    return Line.fromTexts([const Text('  '), ...label.texts], style: base.patch(label.style));
  }

  // ─────────────────────────────────────────────
  // Anatomy — derived defaults, overridable per instance or per theme
  // ─────────────────────────────────────────────

  /// The hovered node. Hover is a transform, not a matrix cell: it lifts a
  /// background, or, on a row with none, patches the hover wash — the case
  /// here, since the base is always null. No anatomy slot: hover is a
  /// generic state, not a TreeView-specific part.
  Style _hoverItemStyle() => _resolver.resolve(null, const {WidgetState.hover}, cls: PaintClass.wash);

  /// The current node — `cursor` × `fill`.
  Style _cursorItemStyle() =>
      style.cursorItem ?? _resolver.resolve(null, const {WidgetState.cursor}, cls: PaintClass.fill);

  /// The expand, collapse, and loading glyph — `indicator`, patched with the
  /// `loading` state (warning ink + slow blink) while [loading] is true.
  Style _indicatorStyle(bool loading) =>
      _resolver.resolve(style.indicator, {if (loading) WidgetState.loading}, cls: PaintClass.ink);

  /// The empty-state line shown until the roots load, and the base a
  /// placeholder row patches its label over.
  Style _placeholderStyle() => style.placeholder ?? _resolver.ink(_resolver.tones.muted);
}
