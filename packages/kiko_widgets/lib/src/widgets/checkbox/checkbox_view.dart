import 'package:kiko/kiko.dart';

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
/// The mark cell is a [Stack] of the three glyphs
/// ([CheckGlyphs.unchecked], [CheckGlyphs.checked], [CheckGlyphs.mixed]): the
/// one matching [CheckboxModel.state] paints, the other two sit in
/// [Offstage]. A stack sizes to its widest child, and an offstage child still
/// counts. So the box keeps one width across every value, measured by the
/// frame's measurer.
///
/// Styles come from [theme] and the model's state (focused / error / disabled
/// / hovered / pressed) through [StyleResolver], with [style] slots taken
/// verbatim where set; [styleOverrides] replaces a state's contribution on
/// every part that state touches.
final class Checkbox implements View {
  /// Creates a checkbox over [model], styled by [theme].
  const Checkbox({required this.model, required this.theme, this.style = const CheckboxStyle(), this.styleOverrides});

  /// The model whose value, glyphs, and layout this view renders.
  final CheckboxModel model;

  /// The theme that resolves the checkbox's styles.
  final Theme theme;

  /// Per-part style overrides. See [CheckboxStyle].
  final CheckboxStyle style;

  /// Per-state style overrides that fully replace the resolved style for a state.
  final Map<WidgetState, Style>? styleOverrides;

  @override
  Node build() {
    final styles = _resolveStyles(model, theme, style, styleOverrides);

    final open = Text(model.glyphs.open, style: styles.open);
    final close = Text(model.glyphs.close, style: styles.close);
    final mark = _markStack(model, styles.mark, styles.checkedMark);
    const gap = Text(' ');

    final box = Row(children: model.labelFirst ? [gap, open, mark, close] : [open, mark, close, gap]);
    final label = model.label.patchStyle(styles.label);

    return Container(
      ground: styles.rowGround,
      child: Row(
        mainAxis: _mainAxisFor(model.labelFirst, model.labelAlign),
        children: model.labelFirst ? [label, box] : [box, label],
      ),
    ).build()..tag = IdTag(model.id);
  }
}

/// The mark cell: every glyph laid out and voting on the width, only
/// [CheckboxModel.state]'s glyph shown.
Stack _markStack(CheckboxModel model, Style mark, Style checkedMark) {
  final children = <View>[];
  for (final state in CheckState.values) {
    final text = Text(_glyphFor(state, model.glyphs), style: state == CheckState.unchecked ? mark : checkedMark);
    children.add(state == model.state ? text : Offstage(child: text));
  }
  return Stack(children: children);
}

/// The glyph [glyphs] shows for [state].
String _glyphFor(CheckState state, CheckGlyphs glyphs) => switch (state) {
  CheckState.unchecked => glyphs.unchecked,
  CheckState.checked => glyphs.checked,
  CheckState.mixed => glyphs.mixed,
};

/// Where the row's spare width goes, from [labelFirst] and [labelAlign].
///
/// `center` always centers the box-and-label pair, regardless of side.
/// Otherwise the spare width goes on the label's far side: after the label
/// when the box is first, before it when the label is first.
MainAxisAlignment _mainAxisFor(bool labelFirst, TextAlign labelAlign) {
  if (labelAlign == TextAlign.center) return MainAxisAlignment.center;
  if (!labelFirst) return labelAlign == TextAlign.start ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween;
  return labelAlign == TextAlign.start ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end;
}

/// Resolves every part style once: a [CheckboxStyle] slot stands in for the
/// derived default where set, then the part's active states patch over that
/// base.
///
/// The checked mark's base folds in the `selected` state only when
/// [CheckboxStyle.checkedMark] is unset — an explicit slot keeps its own
/// color while checked, the way a set `ListViewStyle.selectedItem` keeps its
/// color under an app-set slot.
({Style open, Style close, Style mark, Style checkedMark, Style label, Style rowGround}) _resolveStyles(
  CheckboxModel model,
  Theme theme,
  CheckboxStyle style,
  Map<WidgetState, Style>? styleOverrides,
) {
  final resolver = StyleResolver(theme);

  final bracketStates = <WidgetState>{
    if (model.focused) WidgetState.focused,
    if (model.error) WidgetState.error,
    if (model.disabled) WidgetState.disabled,
    if (model.pressed) WidgetState.pressed,
  };
  final open = resolver.resolve(
    style.open ?? resolver.ink(resolver.tones.border),
    bracketStates,
    cls: PaintClass.ink,
    overrides: styleOverrides,
  );
  final close = resolver.resolve(
    style.close ?? resolver.ink(resolver.tones.border),
    bracketStates,
    cls: PaintClass.ink,
    overrides: styleOverrides,
  );

  final markStates = <WidgetState>{
    if (model.focused) WidgetState.focused,
    if (model.disabled) WidgetState.disabled,
    if (model.pressed) WidgetState.pressed,
  };
  final mark = resolver.resolve(style.mark, markStates, cls: PaintClass.ink, overrides: styleOverrides);

  final checkedMarkBase =
      style.checkedMark ??
      resolver.resolve(null, const {WidgetState.selected}, cls: PaintClass.ink, overrides: styleOverrides);
  final checkedMark = resolver.resolve(checkedMarkBase, markStates, cls: PaintClass.ink, overrides: styleOverrides);

  final label = resolver.resolve(
    style.label,
    {if (model.disabled) WidgetState.disabled},
    cls: PaintClass.ink,
    overrides: styleOverrides,
  );

  final rowGround = model.hovered
      ? resolver.resolve(null, const {WidgetState.hover}, overrides: styleOverrides)
      : const Style();

  return (open: open, close: close, mark: mark, checkedMark: checkedMark, label: label, rowGround: rowGround);
}
