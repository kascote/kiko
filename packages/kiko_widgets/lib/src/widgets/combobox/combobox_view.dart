import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../list_view/list_view_model.dart';
import '../list_view/list_view_view.dart';
import '../list_view/types.dart';
import '../popup/popup_view.dart';
import '../text_input_view.dart';
import 'combobox_model.dart';
import 'types.dart';

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
    this.loadingLabel,
    this.errorLabel,
    this.stalledLabel,
    this.popupBorder = BorderType.none,
    this.popupBorderStyle,
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

  /// The line shown when the standing answer holds no options — an installed
  /// empty answer, or an in-memory filter no option matches.
  ///
  /// Null shows 'No matches'; pass `Line('')` for a blank body.
  final Line? emptyPlaceholder;

  /// The toggle's glyph while the popup is closed.
  final String closedGlyph;

  /// The toggle's glyph while the popup is open.
  final String openGlyph;

  /// The popup's status row while the newest remote query is in flight.
  ///
  /// Null shows 'Loading…'. A given line's own styling wins over the themed
  /// base ([ComboboxStyle.loadingRow], or the theme's muted ink).
  final Line? loadingLabel;

  /// The popup's status row after the newest remote query's answer failed.
  ///
  /// Null shows 'Failed to load'; styling as for [loadingLabel], based on
  /// [ComboboxStyle.errorRow].
  final Line? errorLabel;

  /// The popup's status row after the newest remote query was refused:
  /// resolved, nothing installed, nothing coming.
  ///
  /// Null shows 'Not loaded'; styling as for [loadingLabel], based on
  /// [ComboboxStyle.stalledRow].
  final Line? stalledLabel;

  /// The border drawn around the popup, or [BorderType.none] for none.
  ///
  /// The popup box grows by the border's two rows, so the visible match
  /// rows stay [ComboboxModel.maxVisibleRows].
  final BorderType popupBorder;

  /// The colour and modifiers of the popup's border glyphs.
  ///
  /// Null derives the border ink from the theme.
  final Style? popupBorderStyle;

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
    final resolver = StyleResolver(theme);
    final fill = model.styles.popupGround ?? resolver.ground(resolver.tones.surface);
    final rowBuilder = itemBuilder ?? _defaultItemBuilder;

    model.placement = renderAnchoredPopup(
      frame,
      anchorPath: model.anchorPath,
      requestedHeight: model.maxVisibleRows + _chromeRows,
      width: width,
      decision: model.placement,
      popupBuilder: (height) => _popup(list: list, fill: fill, rowBuilder: rowBuilder, height: height),
    );
  }

  /// The rows [popupBorder] adds to the popup box: its top and bottom edges.
  int get _chromeRows => popupBorder == BorderType.none ? 0 : 2;

  /// Builds one open popup's node at [height]: the combobox's scope hugging
  /// exactly the rows the list (or its status row) occupies, painted over a
  /// full-height background fill.
  ///
  /// The list is bounded to its match count rather than to [height] — as
  /// many rows as it has matches, up to [height] — so a short result leaves
  /// the rows past it as the scope's own untagged, background-filled cells
  /// rather than the list's. A press there then resolves to the bare scope
  /// path, never to the list. A status row ([_statusLine]) owns the popup
  /// outright — every ask clears the list, so matches and status rows never
  /// coexist — and it is chrome this method paints itself, never a row of
  /// the embedded list, so it can never hold the list's cursor. A
  /// [popupBorder] frames the box; its cells resolve to the bare scope path
  /// too.
  Node _popup({
    required ListViewModel<T, T> list,
    required Style fill,
    required List<Line> Function(T item, int index, ItemState state) rowBuilder,
    required int height,
  }) {
    // The rows left for content once the border, when there is one, takes
    // its two. A placement squeezed below the chrome rows leaves zero.
    final innerHeight = (height - _chromeRows).clamp(0, height);
    final status = _statusLine();
    final int contentHeight;
    if (status != null) {
      contentHeight = 0; // the list is empty while a status row shows
    } else {
      final rows = list.itemLimit == 0 ? 1 : list.itemLimit;
      contentHeight = rows.clamp(0, innerHeight);
    }
    list.setVisibleCount(contentHeight);

    return Tagged.scope(
      model.id,
      Container(
        ground: fill,
        border: popupBorder,
        borderStyle: popupBorderStyle ?? StyleResolver(theme).border(const {}),
        child: Column(
          children: [
            ConstrainedBox(
              additionalConstraints: BoxConstraints(maxH: contentHeight),
              child: ListView<T, T>(
                model: list,
                theme: theme,
                itemBuilder: rowBuilder,
                emptyPlaceholder: emptyPlaceholder ?? Line('No matches'),
              ),
            ),
            if (status != null && innerHeight > 0) status,
          ],
        ),
      ),
    ).build();
  }

  /// The popup's status row: a loading line while the newest remote query is
  /// in flight, an error line after its answer failed, a stalled line after
  /// a refusal, or null while an answer stands — always, for an in-memory
  /// [model].
  Line? _statusLine() => switch (model.queryStatus) {
    SliceStatus.filling => _statusRow(loadingLabel, 'Loading…', model.styles.loadingRow),
    SliceStatus.failed => _statusRow(errorLabel, 'Failed to load', model.styles.errorRow),
    SliceStatus.stalled => _statusRow(stalledLabel, 'Not loaded', model.styles.stalledRow),
    SliceStatus.ready => null,
  };

  /// Materializes one status row: [label] with its own styling patched over
  /// the themed base, or [fallback] in the base style alone.
  Line _statusRow(Line? label, String fallback, Style? slot) {
    final base = slot ?? theme.muted.ink;
    if (label == null) return Line(fallback, style: base);
    return Line.fromTexts(label.texts.toList(), style: base.patch(label.style));
  }

  List<Line> _defaultItemBuilder(T item, int index, ItemState state) => [Line(model.label(item))];
}
