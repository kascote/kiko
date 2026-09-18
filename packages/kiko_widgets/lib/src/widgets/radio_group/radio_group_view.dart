import 'package:kiko/kiko.dart';

import '../checkbox/check_row.dart';
import '../checkbox/types.dart';
import '../row_region.dart';
import 'radio_group_model.dart';
import 'types.dart';

/// A radio group as a view — the plume-native view for [RadioGroupModel].
///
/// A radio group is a column of option rows ([Axis.vertical]) or a row of
/// them ([Axis.horizontal]). Each option paints as the checkbox's row: a box
/// (`open` `mark` `close`), one gap cell, and a label, in the order
/// [RadioGroupModel.labelFirst] picks. Every row sits under a [RegionMark]
/// carrying a [RowRegion], so a press anywhere on it resolves back to the
/// option's index through [HitMap.regionAt]. The built subtree is stamped
/// with the model's id, so it resolves back to the model through
/// [HitMap.hitId].
///
/// Styles come from [theme] and each option's state through [StyleResolver],
/// with [style] slots taken verbatim where set. Only the option at
/// [RadioGroupModel.cursor] shows focus, on its brackets and mark; error puts
/// error ink on every option's brackets; disabled dims one option's row, or,
/// while the group is disabled, every row; hover washes one row, spare cells
/// included; pressed inverts one row's box. [RadioGroupModel.labelAlign] has
/// no visible effect while [RadioGroupModel.direction] is [Axis.horizontal]:
/// a row inside an unbounded main axis hugs its own content and leaves no
/// spare width to place a label in.
final class RadioGroup<T> implements View {
  /// Creates a radio group over [model], styled by [theme].
  const RadioGroup({required this.model, required this.theme, this.style = const RadioStyle()});

  /// The model whose options, value, and layout this view renders.
  final RadioGroupModel<T> model;

  /// The theme that resolves the radio group's styles.
  final Theme theme;

  /// Per-part style overrides. See [RadioStyle].
  final RadioStyle style;

  @override
  Node build() {
    final resolver = StyleResolver(theme);
    final options = model.options;
    final rows = <View>[for (var i = 0; i < options.length; i++) _buildRow(resolver, i, options[i])];

    final container = model.direction == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: _withGaps(rows))
        : Column(crossAxis: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows);

    return container.build()..tag = IdTag(model.id);
  }

  /// Builds the option at [index], its row resolved and marked with
  /// [RowRegion].
  View _buildRow(StyleResolver resolver, int index, RadioOption<T> option) {
    final atCursor = index == model.cursor;
    final off = option.disabled || model.disabled;
    final pressed = index == model.pressedIndex;
    final hovered = index == model.hoveredIndex;

    final bracketStates = <WidgetState>{
      if (model.focused && atCursor) WidgetState.focused,
      if (model.error) WidgetState.error,
      if (off) WidgetState.disabled,
      if (pressed) WidgetState.pressed,
    };
    final markStates = <WidgetState>{
      if (model.focused && atCursor) WidgetState.focused,
      if (off) WidgetState.disabled,
      if (pressed) WidgetState.pressed,
    };
    final labelStates = <WidgetState>{if (off) WidgetState.disabled};

    final styles = resolveCheckRowStyles(
      resolver,
      open: style.open,
      close: style.close,
      mark: style.mark,
      checkedMark: style.checkedMark,
      label: style.label,
      bracketStates: bracketStates,
      markStates: markStates,
      labelStates: labelStates,
      hovered: hovered,
    );

    final row = buildCheckRow(
      glyphs: model.glyphs,
      showing: option.value == model.value ? CheckState.checked : CheckState.unchecked,
      stackMixed: false,
      label: option.label,
      labelFirst: model.labelFirst,
      labelAlign: model.labelAlign,
      styles: styles,
    );

    return RegionMark(RowRegion(index), row);
  }

  /// Interleaves [rows] with a two-cell gap, empty when [rows] is empty.
  List<View> _withGaps(List<View> rows) {
    if (rows.isEmpty) return rows;
    final gapped = <View>[rows.first];
    for (final row in rows.skip(1)) {
      gapped
        ..add(const Text('  '))
        ..add(row);
    }
    return gapped;
  }
}
