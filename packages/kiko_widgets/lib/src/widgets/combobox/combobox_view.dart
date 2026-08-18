import 'package:kiko/kiko.dart';

import '../list_view/list_view_model.dart';
import '../list_view/list_view_view.dart';
import '../list_view/types.dart';
import '../popup/popup_view.dart';
import '../text_input_view.dart';
import 'combobox_model.dart';

/// A combobox as a view — the plume-native view for [ComboboxModel].
///
/// [build] returns the base row: the embedded [TextInput] field, expanded to
/// fill the space, plus a one-cell toggle at its right edge showing
/// [closedGlyph] or [openGlyph]. Call [renderPopup] as a second render pass,
/// after the base tree has painted, whenever [ComboboxModel.isOpen] — the
/// same two-pass shape `renderModalOverlay` uses to layer a dialog over an
/// already-painted frame. Like a bare [TextInput], the row fills whatever
/// height its caller gives it; bound it to one row.
final class Combobox<T> implements View {
  /// Creates a combobox view over [model], styled by [theme].
  const Combobox({
    required this.model,
    required this.theme,
    this.itemBuilder,
    this.emptyPlaceholder,
    this.closedGlyph = '▾',
    this.openGlyph = '▴',
    this.styleOverrides,
  });

  /// The model whose field, toggle, and popup this view renders.
  final ComboboxModel<T> model;

  /// The theme that resolves the field, toggle and popup styles.
  final Theme theme;

  /// Builds the lines of a popup row for an item at a given index and state.
  ///
  /// Defaults to a single line of [ComboboxModel.label].
  final List<Line> Function(T item, int index, ItemState state)? itemBuilder;

  /// The line shown in the popup when no option matches, or `null` for a
  /// blank body.
  final Line? emptyPlaceholder;

  /// The toggle's glyph while the popup is closed.
  final String closedGlyph;

  /// The toggle's glyph while the popup is open.
  final String openGlyph;

  /// Per-state style overrides applied on top of the theme's derived styles.
  final Map<WidgetState, Style>? styleOverrides;

  @override
  Node build() => Tagged.scope(
    model.id,
    Row(
      children: [
        Expanded(
          child: TextInput(model: model.field, theme: theme),
        ),
        _toggle(),
      ],
    ),
  ).build();

  /// Builds the one-cell toggle, tagged with [ComboboxModel.toggleId] under
  /// the combobox's own scope.
  View _toggle() {
    final resolver = StyleResolver(theme);
    final glyph = model.isOpen ? openGlyph : closedGlyph;
    final style =
        model.styles.toggle ??
        resolver.resolve(
          Style(fg: theme.background.on),
          {if (model.focused) WidgetState.focused},
          cls: PaintClass.ink,
          overrides: styleOverrides,
        );
    return Tagged(model.toggleId, Container(width: 1, child: Line(glyph, style: style)));
  }

  /// Paints the popup as a second render pass over the already-painted
  /// [frame], while [ComboboxModel.isOpen].
  ///
  /// Call this after the base tree carrying this combobox has rendered. It
  /// anchors on [ComboboxModel.anchorPath] and sizes to the union of the
  /// field's and the toggle's painted rects, read from [Frame.hits], so the
  /// popup never ends narrower than the toggle it sits under — the one place
  /// that union is computed. A frame where the field has not painted this
  /// tick leaves the model's held placement untouched and paints nothing,
  /// exactly as `renderAnchoredPopup` does for a missing anchor.
  void renderPopup(Frame frame) {
    if (!model.isOpen) return;

    final fieldRect = frame.hits.rectOf(model.anchorPath);
    if (fieldRect == null) return;
    final toggleRect = frame.hits.rectOf(model.togglePath);
    final width = toggleRect == null ? fieldRect.width : fieldRect.union(toggleRect).width;

    final list = model.internalList;
    final fill = model.styles.popupBackground ?? theme.surface.fill;
    final rowBuilder = itemBuilder ?? _defaultItemBuilder;

    model.placement = renderAnchoredPopup(
      frame,
      anchorPath: model.anchorPath,
      requestedHeight: model.maxVisibleRows,
      width: width,
      decision: model.placement,
      popupBuilder: (height) => _popup(list: list, fill: fill, rowBuilder: rowBuilder, height: height),
    );
  }

  /// Builds one open popup's node at [height]: the combobox's scope hugging
  /// exactly the rows the list occupies, painted over a full-height
  /// background fill.
  ///
  /// The list is bounded to its match count rather than to [height] — as
  /// many rows as it has matches, up to [height] — so a short result leaves
  /// the rows past it as the scope's own untagged, background-filled cells
  /// rather than the list's. A press there then resolves to the bare scope
  /// path, never to the list.
  Node _popup({
    required ListViewModel<T, T> list,
    required Style fill,
    required List<Line> Function(T item, int index, ItemState state) rowBuilder,
    required int height,
  }) {
    final rows = list.itemLimit == 0 ? 1 : list.itemLimit;
    final contentHeight = rows.clamp(0, height);
    model.setVisibleCount(contentHeight);

    return Tagged.scope(
      model.id,
      Container(
        background: fill,
        child: Column(
          children: [
            ConstrainedBox(
              additionalConstraints: BoxConstraints(maxH: contentHeight),
              child: ListView<T, T>(
                model: list,
                theme: theme,
                itemBuilder: rowBuilder,
                emptyPlaceholder: emptyPlaceholder,
              ),
            ),
          ],
        ),
      ),
    ).build();
  }

  List<Line> _defaultItemBuilder(T item, int index, ItemState state) => [Line(model.label(item))];
}
