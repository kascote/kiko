import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

import 'list_view_model.dart';
import 'types.dart';

/// Builds a ListView as a plume node — the plume-native view for
/// [ListViewModel].
///
/// plume owns the outer frame: an optional [border] with [borderStyle] and edge
/// titles, laid out and placed by the engine. The scrolling body is a custom
/// node that windows the model's visible rows and paints them through the
/// plume paint protocol — [itemBuilder] returns the lines of each row (one
/// per row of `model.itemHeight`; a shorter list leaves the remaining rows
/// blank), with an optional [separatorBuilder] between items and an
/// [emptyPlaceholder] line when there are no items. Row backgrounds come from
/// the item's state (focused / selected / disabled) via the theme,
/// overridable per state with [styleOverrides]. The subtree root is stamped
/// with the model id so a click routes back through [Frame.hitId].
plume.RenderNode<PaintToken> listView<T, K>({
  required ListViewModel<T, K> model,
  required Theme theme,
  required List<Line> Function(T item, int index, ItemState state) itemBuilder,
  Map<WidgetState, Style>? styleOverrides,
  Line Function()? separatorBuilder,
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
    child: _ListViewport<T, K>(
      model: model,
      theme: theme,
      itemBuilder: itemBuilder,
      styleOverrides: styleOverrides,
      separatorBuilder: separatorBuilder,
      emptyPlaceholder: emptyPlaceholder,
    ),
  )..tag = model.id;
}

/// The self-painting body of a [listView]: fills the space the box gives it and
/// paints the model's visible window of rows through the plume `Surface`.
class _ListViewport<T, K> extends plume.RenderNode<PaintToken> {
  _ListViewport({
    required this.model,
    required this.theme,
    required this.itemBuilder,
    this.styleOverrides,
    this.separatorBuilder,
    this.emptyPlaceholder,
  });

  final ListViewModel<T, K> model;
  final Theme theme;
  final List<Line> Function(T item, int index, ItemState state) itemBuilder;
  final Map<WidgetState, Style>? styleOverrides;
  final Line Function()? separatorBuilder;
  final Line? emptyPlaceholder;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) =>
      constraints.constrain(plume.Size(constraints.maxW ?? 0, constraints.maxH ?? 0));

  @override
  void paintSelf(plume.Surface<PaintToken> surface) {
    final clip = surface.clipRect ?? rect;
    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    if (area.isEmpty) return;
    _paint(area, surface);
  }

  void _paint(Rect area, plume.Surface<PaintToken> surface) {
    final m = model;
    final dataView = m.dataView;
    final itemCount = dataView.length ?? 0;

    if (itemCount == 0) {
      final placeholder = emptyPlaceholder;
      if (placeholder != null) {
        paintLine(surface, placeholder, x: area.x, y: area.y, width: area.width);
      }
      return;
    }

    final hasSeparator = separatorBuilder != null;
    final effectiveRowHeight = m.itemHeight + (hasSeparator ? 1 : 0);
    // The last item needs no trailing separator, so one more can fit.
    final visibleCount = hasSeparator ? (area.height + 1) ~/ effectiveRowHeight : area.height ~/ effectiveRowHeight;
    if (visibleCount <= 0) return;
    m.setVisibleCount(visibleCount);

    final startIndex = m.scrollOffset;
    final endIndex = (startIndex + visibleCount).clamp(0, itemCount);

    var y = area.y;
    for (var i = startIndex; i < endIndex; i++) {
      final item = dataView.itemAt(i);
      final isFocused = i == m.cursor;
      final isChecked = m.isSelected(i);
      final isDisabled = m.isDisabled?.call(i) ?? false;

      final itemArea = Rect.create(x: area.x, y: y, width: area.width, height: m.itemHeight).intersection(area);
      if (itemArea.isEmpty) break;

      final states = <WidgetState>{
        if (isFocused) WidgetState.focused,
        if (isChecked) WidgetState.selected,
        if (isDisabled) WidgetState.disabled,
      };
      if (states.isNotEmpty) {
        final rowStyle = StyleResolver(theme).resolve(null, states, overrides: styleOverrides);
        for (var dy = 0; dy < itemArea.height; dy++) {
          fillRow(surface, x: itemArea.x, y: itemArea.y + dy, width: itemArea.width, style: rowStyle);
        }
      }

      final lines = itemBuilder(item, i, (checked: isChecked, focused: isFocused, disabled: isDisabled));
      for (var li = 0; li < lines.length && li < itemArea.height; li++) {
        paintLine(surface, lines[li], x: itemArea.x, y: itemArea.y + li, width: itemArea.width);
      }
      y += m.itemHeight;

      if (hasSeparator && i < endIndex - 1) {
        paintLine(surface, separatorBuilder!(), x: area.x, y: y, width: area.width);
        y += 1;
      }
    }
  }
}
