import 'package:kiko/kiko.dart';

import 'types.dart';

/// One check row's resolved part styles, as [resolveCheckRowStyles] returns
/// them: the five painted parts and the row's ground.
typedef CheckRowStyles = ({Style open, Style close, Style mark, Style checkedMark, Style label, Style rowGround});

/// Resolves one check row's part styles through [resolver].
///
/// [open], [close], [mark], [checkedMark] and [label] are the caller's style
/// slots; a `null` slot falls back to the part's derived default before the
/// states in [bracketStates], [markStates] and [labelStates] patch over it.
/// [hovered] washes the row's ground.
///
/// The brackets default to `resolver.ink(border)`. The checked mark's base
/// folds in the `selected` state only when [checkedMark] is `null`, so an
/// explicit slot keeps its own color while checked.
CheckRowStyles resolveCheckRowStyles(
  StyleResolver resolver, {
  required Set<WidgetState> bracketStates,
  required Set<WidgetState> markStates,
  required Set<WidgetState> labelStates,
  required bool hovered,
  Style? open,
  Style? close,
  Style? mark,
  Style? checkedMark,
  Style? label,
}) {
  final resolvedOpen = resolver.resolve(
    open ?? resolver.ink(resolver.tones.border),
    bracketStates,
    cls: PaintClass.ink,
  );
  final resolvedClose = resolver.resolve(
    close ?? resolver.ink(resolver.tones.border),
    bracketStates,
    cls: PaintClass.ink,
  );
  final resolvedMark = resolver.resolve(mark, markStates, cls: PaintClass.ink);

  final checkedMarkBase = checkedMark ?? resolver.resolve(null, const {WidgetState.selected}, cls: PaintClass.ink);
  final resolvedCheckedMark = resolver.resolve(checkedMarkBase, markStates, cls: PaintClass.ink);

  final resolvedLabel = resolver.resolve(label, labelStates, cls: PaintClass.ink);

  final rowGround = hovered ? resolver.resolve(null, const {WidgetState.hover}, cls: PaintClass.wash) : const Style();

  return (
    open: resolvedOpen,
    close: resolvedClose,
    mark: resolvedMark,
    checkedMark: resolvedCheckedMark,
    label: resolvedLabel,
    rowGround: rowGround,
  );
}

/// Builds one check row: a box (`open` `mark` `close`), one gap cell, and a
/// label, in the order [labelFirst] picks.
///
/// [glyphs] supplies the parts, [showing] is the [CheckState] whose glyph
/// paints, and [styles] are the row's resolved part styles from
/// [resolveCheckRowStyles]. [stackMixed] decides whether
/// [CheckGlyphs.mixed] joins the mark [Stack]: the checkbox passes `true`,
/// the radio group `false`. The result is untagged; the caller wraps it in
/// whatever tag or hit region it needs.
///
/// The mark cell is a [Stack] where every candidate glyph lays out and votes
/// on the width, and only [showing]'s glyph is visible; the rest sit in
/// [Offstage]. A stack sizes to its widest child, and an offstage child still
/// counts, so the box keeps one width across every value.
Container buildCheckRow({
  required CheckGlyphs glyphs,
  required CheckState showing,
  required bool stackMixed,
  required Line label,
  required bool labelFirst,
  required TextAlign labelAlign,
  required CheckRowStyles styles,
}) {
  final open = Text(glyphs.open, style: styles.open);
  final close = Text(glyphs.close, style: styles.close);
  final mark = _markStack(glyphs, showing, stackMixed, styles.mark, styles.checkedMark);
  const gap = Text(' ');

  final box = Row(children: labelFirst ? [gap, open, mark, close] : [open, mark, close, gap]);
  final builtLabel = label.over(styles.label);

  return Container(
    ground: styles.rowGround,
    child: Row(
      mainAxis: _mainAxisFor(labelFirst, labelAlign),
      children: labelFirst ? [builtLabel, box] : [box, builtLabel],
    ),
  );
}

/// The mark cell: every candidate glyph laid out and voting on the width,
/// only [showing]'s glyph shown. [stackMixed] leaves [CheckGlyphs.mixed] out
/// of the stack when `false`.
Stack _markStack(CheckGlyphs glyphs, CheckState showing, bool stackMixed, Style mark, Style checkedMark) {
  final children = <View>[];
  for (final state in CheckState.values) {
    if (state == CheckState.mixed && !stackMixed) continue;
    final text = Text(_glyphFor(state, glyphs), style: state == CheckState.unchecked ? mark : checkedMark);
    children.add(state == showing ? text : Offstage(child: text));
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
