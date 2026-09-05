import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../../load/viewport_changed.dart';
import '../row_region.dart';
import 'list_view_model.dart';
import 'types.dart';

/// A ListView as a view — the plume-native view for [ListViewModel].
///
/// This is the scrolling body on its own, with no frame around it: a custom node
/// that windows the model's visible rows and paints them through the plume paint
/// protocol. [itemBuilder] returns the lines of each row (one per row of
/// `model.itemHeight`; a shorter list leaves the remaining rows blank), with an
/// optional [separatorBuilder] between items and an [emptyPlaceholder] line when
/// there are no items. An item whose page has not arrived paints as a dim run,
/// or through [loadingItemBuilder] when given. Row backgrounds come from the item's honest state
/// (selected / cursor / disabled) painted through [style]'s [ListViewStyle]
/// anatomy — each `null` slot deriving from the theme's tones — and overridable
/// per state with [styleOverrides]. Wrap it in a [Container] for a border or edge
/// titles. The node is stamped with the model id so a click routes back through
/// [HitMap.hitId], and its viewport report carries that same hit path.
final class ListView<T, K> implements View {
  /// Creates a list view over [model], styled by [theme] and built row by row
  /// through [itemBuilder].
  const ListView({
    required this.model,
    required this.theme,
    required this.itemBuilder,
    this.style = const ListViewStyle(),
    this.styleOverrides,
    this.separatorBuilder,
    this.emptyPlaceholder,
    this.loadingItemBuilder,
  });

  /// The model whose rows, cursor, and selection this view renders.
  final ListViewModel<T, K> model;

  /// The theme that resolves row styles.
  final Theme theme;

  /// Builds the lines of the row for [model]'s item at a given index and state.
  final List<Line> Function(T item, int index, ItemState state) itemBuilder;

  /// Builds the lines shown for an item whose page has not arrived, called
  /// with the item's absolute index. `null` paints the built-in dim run.
  final List<Line> Function(int index)? loadingItemBuilder;

  /// Row anatomy overrides. See [ListViewStyle].
  final ListViewStyle style;

  /// Per-state style overrides applied on top of the theme's row styles.
  final Map<WidgetState, Style>? styleOverrides;

  /// Builds the separator line drawn between items, or `null` for none.
  final Line Function()? separatorBuilder;

  /// The line shown when the list has no items, or `null` for a blank body.
  final Line? emptyPlaceholder;

  @override
  Node build() => _ListViewport<T, K>(
    model: model,
    theme: theme,
    itemBuilder: itemBuilder,
    style: style,
    styleOverrides: styleOverrides,
    separatorBuilder: separatorBuilder,
    emptyPlaceholder: emptyPlaceholder,
    loadingItemBuilder: loadingItemBuilder,
  )..tag = IdTag(model.id);
}

/// The self-painting body of a [ListView]: fills the space the box gives it and
/// paints the model's visible window of rows through the plume `Surface`.
class _ListViewport<T, K> extends Node {
  _ListViewport({
    required this.model,
    required this.theme,
    required this.itemBuilder,
    required this.style,
    this.styleOverrides,
    this.separatorBuilder,
    this.emptyPlaceholder,
    this.loadingItemBuilder,
  });

  final ListViewModel<T, K> model;
  final Theme theme;
  final List<Line> Function(T item, int index, ItemState state) itemBuilder;
  final ListViewStyle style;
  final Map<WidgetState, Style>? styleOverrides;
  final Line Function()? separatorBuilder;
  final Line? emptyPlaceholder;
  final List<Line> Function(int index)? loadingItemBuilder;

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
    // partially scrolled-off list pins its content to the viewport edge.
    final area = Rect.create(x: rect.x, y: rect.y, width: rect.width, height: rect.height);
    _paint(area, surface);
  }

  void _paint(Rect area, Surface surface) {
    final m = model;

    final hasSeparator = separatorBuilder != null;
    final effectiveRowHeight = m.itemHeight + (hasSeparator ? 1 : 0);
    // The last item needs no trailing separator, so one more can fit.
    final visibleCount = hasSeparator ? (area.height + 1) ~/ effectiveRowHeight : area.height ~/ effectiveRowHeight;
    if (visibleCount <= 0) return;
    // Report the count only while the model does not hold it, so the frame
    // the report causes has nothing more to say.
    if (surface is BufferSurface && visibleCount != m.visibleCount) {
      surface.report(ViewportChanged(HitTag.join(surface.scopePath, m.id), rows: visibleCount));
    }

    // Empty state — the data itself is empty, not merely unloaded. A list that
    // knows its size (or has a page on its way) has items to draw, even before
    // any of them arrive: they paint as placeholders below.
    final itemLimit = m.itemLimit;
    if (itemLimit == 0) {
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

    // While a fetch is in flight and the cursor is off screen, the nearest run
    // of items the window holds whole reads better than a screen of
    // placeholders. With the cursor on screen the true position paints instead:
    // the cursor is where selection acts, so nothing may stand in for the items
    // it sits over. Any other incomplete status also paints the true position,
    // so a fetch that never lands stops the view showing older items on its own
    // — no timer decides when.
    final cursorVisible = m.cursor >= m.scrollOffset && m.cursor < m.scrollOffset + visibleCount;
    final startIndex = m.viewportStatus == SliceStatus.filling && !cursorVisible
        ? m.nearestHeldStart(visibleCount) ?? m.scrollOffset
        : m.scrollOffset;
    final endIndex = (startIndex + visibleCount).clamp(0, itemLimit);

    var y = area.y;
    for (var i = startIndex; i < endIndex; i++) {
      final item = m.getItem(i);
      final isCursor = i == m.cursor;
      final isChecked = m.isSelected(i);
      final isDisabled = m.isDisabled?.call(i) ?? false;

      final itemArea = Rect.create(x: area.x, y: y, width: area.width, height: m.itemHeight).intersection(area);
      if (itemArea.isEmpty) break;

      // Mark this item's painted rect — itemHeight lines tall — as its row
      // region, in the same loop that paints it, so a pointer anywhere on the
      // item resolves to it — a placeholder too, carrying its real index.
      // Separator lines and the blank tail stay unmarked.
      markRegion(RowRegion(i), itemArea.toPlume());

      // Honest anatomy, not borrowed states: the base item style, then the
      // hover wash (weakest, so selection/cursor read over it), then the
      // selection fill, then the cursor fill (so the cursor stays visible over
      // a selected run), then the disabled dim — each layer patches the last.
      // A placeholder row layers the same way, so the cursor stays visible
      // over items still filling in.
      var rowStyle = style.item ?? const Style();
      var styled = style.item != null;
      if (m.hoverRow == i) {
        rowStyle = rowStyle.patch(_hoverItemStyle());
        styled = true;
      }
      if (isChecked) {
        rowStyle = rowStyle.patch(_selectedItemStyle());
        styled = true;
      }
      if (isCursor) {
        rowStyle = rowStyle.patch(_cursorItemStyle());
        styled = true;
      }
      if (isDisabled) {
        rowStyle = rowStyle.patch(_disabledStyle());
        styled = true;
      }
      if (styled) {
        for (var dy = 0; dy < itemArea.height; dy++) {
          fillRow(surface, x: itemArea.x, y: itemArea.y + dy, width: itemArea.width, style: rowStyle);
        }
      }

      if (item == null && loadingItemBuilder == null) {
        // An item whose page isn't held: the item builder cannot run without
        // an item, so a dim run stands in on each of its lines. Short of the
        // full width, so the run reads as content pending, not content.
        final runWidth = itemArea.width <= 2 ? itemArea.width : (itemArea.width * 3) ~/ 4;
        final run = Line('░' * runWidth).patchStyle(_loadingItemStyle());
        for (var li = 0; li < itemArea.height; li++) {
          paintLine(surface, run, x: itemArea.x, y: itemArea.y + li, width: itemArea.width, measurer: _measurer);
        }
      } else {
        // A held item builds its rows; an unheld one builds the caller's
        // placeholder from the index alone. Both paint the same way, over the
        // same state fill.
        final lines = item != null
            ? itemBuilder(item, i, (checked: isChecked, cursor: isCursor, disabled: isDisabled))
            : loadingItemBuilder!(i);
        for (var li = 0; li < lines.length && li < itemArea.height; li++) {
          paintLine(surface, lines[li], x: itemArea.x, y: itemArea.y + li, width: itemArea.width, measurer: _measurer);
        }
      }
      y += m.itemHeight;

      if (hasSeparator && i < endIndex - 1) {
        paintLine(surface, separatorBuilder!(), x: area.x, y: y, width: area.width, measurer: _measurer);
        y += 1;
      }
    }
  }

  // ─────────────────────────────────────────────
  // Anatomy — derived defaults, overridable per instance or per theme
  // ─────────────────────────────────────────────

  /// The hovered row — `hover` × `wash`. A bg-only wash (hover resolves for no
  /// other paint class), so it tints the row without clobbering its foreground.
  /// No anatomy slot: hover is a generic state, not a ListView-specific part.
  Style _hoverItemStyle() =>
      _resolver.resolve(null, const {WidgetState.hover}, cls: PaintClass.wash, overrides: styleOverrides);

  /// Rows in the selection set — `selected` × `fill`.
  Style _selectedItemStyle() =>
      style.selectedItem ?? _resolver.resolve(null, const {WidgetState.selected}, overrides: styleOverrides);

  /// The current item — `cursor` × `fill`.
  Style _cursorItemStyle() =>
      style.cursorItem ?? _resolver.resolve(null, const {WidgetState.cursor}, overrides: styleOverrides);

  /// Disabled rows — `disabled` × `fill` (dim). No anatomy slot: disabled is a
  /// generic state, not a ListView-specific part.
  Style _disabledStyle() => _resolver.resolve(null, const {WidgetState.disabled}, overrides: styleOverrides);

  /// The built-in dim run for items whose page isn't held.
  Style _loadingItemStyle() => style.loadingItem ?? _resolver.ink(_resolver.tones.muted);

  /// The empty-state line.
  Style _placeholderStyle() => style.placeholder ?? _resolver.ink(_resolver.tones.muted);
}
