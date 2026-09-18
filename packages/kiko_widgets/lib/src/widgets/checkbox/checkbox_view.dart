import 'package:kiko/kiko.dart';

import 'check_row.dart';
import 'checkbox_model.dart';
import 'types.dart';

/// A checkbox as a view — the plume-native view for [CheckboxModel].
///
/// A checkbox is one row: a box (`open` `mark` `close`), one gap cell, and a
/// label, in the order [CheckboxModel.labelFirst] picks. The row is a
/// [Container] over a [Row] of two children — the box and the label — so
/// [CheckboxModel.labelAlign] places the label's spare width the way
/// `MainAxisAlignment` places any row's spare width. The built subtree is
/// stamped with the model's id, so a press anywhere on the row resolves back
/// to it through [HitMap.hitId].
///
/// Styles come from [theme] and the model's state (focused / error / disabled
/// / hovered / pressed) through [StyleResolver], with [style] slots taken
/// verbatim where set. A per-instance state look is a theme variant passed to
/// [theme].
final class Checkbox implements View {
  /// Creates a checkbox over [model], styled by [theme].
  const Checkbox({required this.model, required this.theme, this.style = const CheckboxStyle()});

  /// The model whose value, glyphs, and layout this view renders.
  final CheckboxModel model;

  /// The theme that resolves the checkbox's styles.
  final Theme theme;

  /// Per-part style overrides. See [CheckboxStyle].
  final CheckboxStyle style;

  @override
  Node build() {
    final resolver = StyleResolver(theme);

    final bracketStates = <WidgetState>{
      if (model.focused) WidgetState.focused,
      if (model.error) WidgetState.error,
      if (model.disabled) WidgetState.disabled,
      if (model.pressed) WidgetState.pressed,
    };
    final markStates = <WidgetState>{
      if (model.focused) WidgetState.focused,
      if (model.disabled) WidgetState.disabled,
      if (model.pressed) WidgetState.pressed,
    };
    final labelStates = <WidgetState>{if (model.disabled) WidgetState.disabled};

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
      hovered: model.hovered,
    );

    return buildCheckRow(
      glyphs: model.glyphs,
      showing: model.state,
      stackMixed: true,
      label: model.label,
      labelFirst: model.labelFirst,
      labelAlign: model.labelAlign,
      styles: styles,
    ).build()..tag = IdTag(model.id);
  }
}
