import 'package:kiko/kiko.dart';

import '../../load/load.dart';
import '../list_view/list_view_model.dart';
import '../list_view/list_view_view.dart';
import '../list_view/types.dart';
import '../popup/popup_placed.dart';
import '../popup/popup_view.dart';
import '../text_input/text_input_view.dart';
import 'combobox_model.dart';
import 'types.dart';

/// A combobox as a view — the plume-native view for [ComboboxModel].
///
/// [build] returns the base row: the embedded [TextInput] field, expanded to
/// fill the space, plus a one-cell toggle at its right edge showing
/// [closedGlyph] or [openGlyph]. Call [renderPopup] after the base tree has
/// painted, whenever [ComboboxModel.isOpen] — it paints the popup as a layer
/// on top of the frame, in its own clean slate. Like a bare [TextInput], the
/// row fills whatever height its caller gives it; bound it to one row.
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
    this.style = const ComboboxStyle(),
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
  /// base ([ComboboxStyle.placeholder], or the theme's muted ink).
  final Line? loadingLabel;

  /// The popup's status row after the newest remote query's answer failed.
  ///
  /// Null shows 'Failed to load'; styling as for [loadingLabel], patched over
  /// the error tone.
  final Line? errorLabel;

  /// The popup's status row after the newest remote query was refused:
  /// resolved, nothing installed, nothing coming.
  ///
  /// Null shows 'Not loaded'; styling as for [loadingLabel].
  final Line? stalledLabel;

  /// The border drawn around the popup, or [BorderType.none] for none.
  ///
  /// The popup box grows by the border's two rows, so the visible match
  /// rows stay [ComboboxModel.maxVisibleRows].
  final BorderType popupBorder;

  /// Anatomy overrides for the toggle, the popup, the field, and the popup's
  /// rows. See [ComboboxStyle].
  final ComboboxStyle style;

  /// Resolves the anatomy slots that derive from theme tones + state.
  StyleResolver get _resolver => StyleResolver(theme);

  @override
  Node build() => Tagged.scope(
    model.id,
    Row(
      children: [
        Expanded(
          child: TextInput(model: model.field, theme: theme, style: style.field),
        ),
        _toggle(),
      ],
    ),
  ).build();

  /// Builds the one-cell toggle, tagged with [ComboboxModel.toggleId] under
  /// the combobox's own scope.
  View _toggle() {
    final glyph = model.isOpen ? openGlyph : closedGlyph;
    final toggleStyle =
        style.toggle ?? _resolver.resolve(null, {if (model.focused) WidgetState.focused}, cls: PaintClass.ink);
    return Tagged(model.toggleId, Container(width: 1, child: Line(glyph, style: toggleStyle)));
  }

  /// Paints the popup as a layer on top of the already-painted [frame],
  /// while [ComboboxModel.isOpen].
  ///
  /// Call this after the base tree carrying this combobox has rendered. It
  /// anchors on [ComboboxModel.anchorPath] and sizes to the union of the
  /// field's and the toggle's painted rects, read from [Frame.hits], so the
  /// popup never ends narrower than the toggle it sits under — the one place
  /// that union is computed. A placement the popup was painted with that the
  /// model does not hold yet reaches [frame] as a [PopupPlaced] addressed to
  /// the model, which stores it for the next paint. A frame where the field
  /// has not painted paints nothing and reports nothing, exactly as
  /// `renderAnchoredPopup` does for a missing anchor.
  void renderPopup(Frame frame) {
    if (!model.isOpen) return;

    final fieldRect = frame.hits.rectOf(model.anchorPath);
    if (fieldRect == null) return;
    final toggleRect = frame.hits.rectOf(model.togglePath);
    final width = toggleRect == null ? fieldRect.width : fieldRect.union(toggleRect).width;

    final list = model.internalList;
    final resolver = _resolver;
    final fill = style.popupGround ?? resolver.ground(resolver.tones.surface);
    final rowBuilder = itemBuilder ?? _defaultItemBuilder;

    renderAnchoredPopup(
      frame,
      id: model.id,
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

    return Tagged.scope(
      model.id,
      Container(
        ground: fill,
        border: popupBorder,
        borderStyle: style.popupBorder ?? _resolver.border(const {}),
        child: Column(
          children: [
            ConstrainedBox(
              additionalConstraints: BoxConstraints(maxH: contentHeight),
              child: ListView<T, T>(
                model: list,
                theme: theme,
                itemBuilder: rowBuilder,
                style: style.list,
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
    SliceStatus.filling => _statusRow(loadingLabel, 'Loading…'),
    SliceStatus.failed => _statusRow(errorLabel, 'Failed to load', failed: true),
    SliceStatus.stalled => _statusRow(stalledLabel, 'Not loaded'),
    SliceStatus.ready => null,
  };

  /// Materializes one status row: [label] with its own styling patched over
  /// the themed base, or [fallback] in the base style alone. [failed] patches
  /// the error tone over the base first, since the popup knows the query
  /// failed.
  Line _statusRow(Line? label, String fallback, {bool failed = false}) {
    var base = style.placeholder ?? _resolver.ink(_resolver.tones.muted);
    if (failed) {
      base = base.patch(_resolver.resolve(null, const {WidgetState.error}, cls: PaintClass.ink));
    }
    if (label == null) return Line(fallback, style: base);
    return Line.fromTexts(label.texts.toList(), style: base.patch(label.style));
  }

  List<Line> _defaultItemBuilder(T item, int index, ItemState state) => [Line(model.label(item))];
}
