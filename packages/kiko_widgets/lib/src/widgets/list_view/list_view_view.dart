import 'package:kiko/kiko.dart';

import 'list_view_model.dart';
import 'types.dart';

/// A ListView as a view — the plume-native view for [ListViewModel].
///
/// A [Box] owns the outer frame: an optional [border] with [borderStyle] and
/// edge titles, laid out and placed by the engine. The scrolling body is a
/// custom node that windows the model's visible rows and paints them through the
/// plume paint protocol — [itemBuilder] returns the lines of each row (one
/// per row of `model.itemHeight`; a shorter list leaves the remaining rows
/// blank), with an optional [separatorBuilder] between items and an
/// [emptyPlaceholder] line when there are no items. Row backgrounds come from
/// the item's state (focused / selected / disabled) via the theme,
/// overridable per state with [styleOverrides]. The built subtree is stamped
/// with the model id so a click routes back through [Frame.hitId].
final class ListView<T, K> implements View {
  /// Creates a list view over [model], styled by [theme] and built row by row
  /// through [itemBuilder].
  const ListView({
    required this.model,
    required this.theme,
    required this.itemBuilder,
    this.styleOverrides,
    this.separatorBuilder,
    this.emptyPlaceholder,
    this.border = BorderType.none,
    this.borderStyle = const Style(),
    this.topTitles = const <Line>[],
    this.bottomTitles = const <Line>[],
  });

  /// The model whose rows, cursor, and selection this view renders.
  final ListViewModel<T, K> model;

  /// The theme that resolves row and border styles.
  final Theme theme;

  /// Builds the lines of the row for [model]'s item at a given index and state.
  final List<Line> Function(T item, int index, ItemState state) itemBuilder;

  /// Per-state style overrides applied on top of the theme's row styles.
  final Map<WidgetState, Style>? styleOverrides;

  /// Builds the separator line drawn between items, or `null` for none.
  final Line Function()? separatorBuilder;

  /// The line shown when the list has no items, or `null` for a blank body.
  final Line? emptyPlaceholder;

  /// The border drawn around the list, or [BorderType.none] for no border.
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
      _ListViewport<T, K>(
        model: model,
        theme: theme,
        itemBuilder: itemBuilder,
        styleOverrides: styleOverrides,
        separatorBuilder: separatorBuilder,
        emptyPlaceholder: emptyPlaceholder,
      ),
    ),
  ).build()..tag = model.id;
}

/// The self-painting body of a [ListView]: fills the space the box gives it and
/// paints the model's visible window of rows through the plume `Surface`.
class _ListViewport<T, K> extends Node {
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

  // Captured from the layout context so paint measures text the way the frame
  // does — a cjk frame reaches the rows, not just the box chrome.
  TextMeasurer _measurer = const TermUnicodeMeasurer();

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    _measurer = context.measurer;
    return constraints.constrain(Size(constraints.maxW ?? 0, constraints.maxH ?? 0));
  }

  @override
  void paintSelf(Surface surface) {
    final clip = surface.clipRect ?? rect;
    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    if (area.isEmpty) return;
    _paint(area, surface);
  }

  void _paint(Rect area, Surface surface) {
    final m = model;
    final dataView = m.dataView;
    final itemCount = dataView.length ?? 0;

    if (itemCount == 0) {
      final placeholder = emptyPlaceholder;
      if (placeholder != null) {
        paintLine(surface, placeholder, x: area.x, y: area.y, width: area.width, measurer: _measurer);
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
        paintLine(surface, lines[li], x: itemArea.x, y: itemArea.y + li, width: itemArea.width, measurer: _measurer);
      }
      y += m.itemHeight;

      if (hasSeparator && i < endIndex - 1) {
        paintLine(surface, separatorBuilder!(), x: area.x, y: y, width: area.width, measurer: _measurer);
        y += 1;
      }
    }
  }
}
