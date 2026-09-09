import 'package:kiko/kiko.dart';

import 'shared.dart';

// Page 3: the contrast audit. Three tables — text on a ground, fills and
// composed states, and separation between two grounds — each row a measured
// pair with its swatch, hex values, and ratio. Every ratio is the WCAG 2
// contrast ratio [Color.contrastRatio] returns. The text and fill tables
// grade it against the WCAG 2 text thresholds; the separation table asks a
// different question of the same number (can two grounds be told apart?),
// so its rows carry no grade. The text and the separation tables stack on
// the left, the fills table stands on the right, so the page fits a
// 120-column terminal.

/// One measured pair: a label and the resolver call that yields its `fg`
/// over its `bg`.
typedef _Pair = (String label, Style Function(StyleResolver rgb) style);

/// The style for [ink] painted over [ground]: [ink]'s color as the
/// foreground, [ground]'s color as the background.
Style _over(Tone ink, SurfaceTone ground) => Style(fg: ink.color, bg: ground.color);

/// The primary face, patched with [states] — the composed rows in
/// [_fillPairs] read this for "focused", "hovered", and "disabled".
Style _face(StyleResolver rgb, Set<WidgetState> states) =>
    rgb.resolve(rgb.fill(rgb.tones.primary), states, cls: PaintClass.fill);

// The tables are `final`, not `const`: each entry's style function is a
// closure over `rgb`, and an anonymous function is never a compile-time
// constant in Dart, even one that only reads its parameter. A `final` list
// keeps one line per pair; the alternative (fifty distinct top-level named
// functions to tear off) would obscure the pair list behind boilerplate.

/// Section 1: default text and the six intent tones as ink, over the
/// background ground and then over the surface ground.
final List<_Pair> _textPairs = [
  ('text / background', (rgb) => _over(Tone(color: rgb.tones.background.on), rgb.tones.background)),
  ('muted / background', (rgb) => _over(rgb.tones.muted, rgb.tones.background)),
  ('disabled / background', (rgb) => _over(rgb.tones.disabled, rgb.tones.background)),
  ('secondary / background', (rgb) => _over(rgb.tones.secondary, rgb.tones.background)),
  ('accent / background', (rgb) => _over(rgb.tones.accent, rgb.tones.background)),
  ('primary / background', (rgb) => _over(rgb.tones.primary, rgb.tones.background)),
  ('focus / background', (rgb) => _over(rgb.tones.focus, rgb.tones.background)),
  ('error / background', (rgb) => _over(rgb.tones.error, rgb.tones.background)),
  ('warning / background', (rgb) => _over(rgb.tones.warning, rgb.tones.background)),
  ('success / background', (rgb) => _over(rgb.tones.success, rgb.tones.background)),
  ('text / surface', (rgb) => _over(Tone(color: rgb.tones.surface.on), rgb.tones.surface)),
  ('muted / surface', (rgb) => _over(rgb.tones.muted, rgb.tones.surface)),
  ('disabled / surface', (rgb) => _over(rgb.tones.disabled, rgb.tones.surface)),
  ('secondary / surface', (rgb) => _over(rgb.tones.secondary, rgb.tones.surface)),
  ('accent / surface', (rgb) => _over(rgb.tones.accent, rgb.tones.surface)),
  ('primary / surface', (rgb) => _over(rgb.tones.primary, rgb.tones.surface)),
  ('focus / surface', (rgb) => _over(rgb.tones.focus, rgb.tones.surface)),
  ('error / surface', (rgb) => _over(rgb.tones.error, rgb.tones.surface)),
  ('warning / surface', (rgb) => _over(rgb.tones.warning, rgb.tones.surface)),
  ('success / surface', (rgb) => _over(rgb.tones.success, rgb.tones.surface)),
];

/// Section 2: every [SurfaceTone] as its own fill, then the resolver's
/// composed states — the results a widget actually paints.
final List<_Pair> _fillPairs = [
  ('primary', (rgb) => rgb.fill(rgb.tones.primary)),
  ('secondary', (rgb) => rgb.fill(rgb.tones.secondary)),
  ('accent', (rgb) => rgb.fill(rgb.tones.accent)),
  ('error', (rgb) => rgb.fill(rgb.tones.error)),
  ('warning', (rgb) => rgb.fill(rgb.tones.warning)),
  ('success', (rgb) => rgb.fill(rgb.tones.success)),
  ('background', (rgb) => rgb.fill(rgb.tones.background)),
  ('surface', (rgb) => rgb.fill(rgb.tones.surface)),
  ('focus', (rgb) => rgb.fill(rgb.tones.focus)),
  ('selection', (rgb) => rgb.fill(rgb.tones.selection)),
  ('cursor', (rgb) => rgb.fill(rgb.tones.cursor)),
  (
    'selected + cursor',
    (rgb) => rgb.resolve(null, const {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill),
  ),
  ('cursor on bare', (rgb) => rgb.resolve(null, const {WidgetState.cursor}, cls: PaintClass.fill)),
  (
    'selected + disabled',
    (rgb) => rgb.resolve(null, const {WidgetState.selected, WidgetState.disabled}, cls: PaintClass.fill),
  ),
  (
    'cursor + disabled',
    (rgb) => rgb.resolve(null, const {WidgetState.cursor, WidgetState.disabled}, cls: PaintClass.fill),
  ),
  ('primary face at rest', (rgb) => rgb.fill(rgb.tones.primary)),
  ('primary face focused', (rgb) => _face(rgb, const {WidgetState.focused})),
  ('primary face hovered', (rgb) => _face(rgb, const {WidgetState.hover})),
  ('primary face disabled', (rgb) => _face(rgb, const {WidgetState.disabled})),
  ('error face at rest', (rgb) => rgb.fill(rgb.tones.error)),
  (
    'error face focused',
    (rgb) => rgb.resolve(rgb.fill(rgb.tones.error), const {WidgetState.focused}, cls: PaintClass.fill),
  ),
];

/// Section 3: ratio only, no grade — two grounds compared against each
/// other, where the text thresholds do not apply.
final List<_Pair> _separationPairs = [
  ('background / surface', (rgb) => Style(fg: rgb.tones.background.color, bg: rgb.tones.surface.color)),
  ('background / cursor', (rgb) => Style(fg: rgb.tones.background.color, bg: rgb.tones.cursor.color)),
  ('background / hover', (rgb) => Style(fg: rgb.tones.background.color, bg: rgb.theme.hover.color)),
  ('background / selection', (rgb) => Style(fg: rgb.tones.background.color, bg: rgb.tones.selection.color)),
  ('cursor / hover', (rgb) => Style(fg: rgb.tones.cursor.color, bg: rgb.theme.hover.color)),
  (
    'selection / sel+cursor',
    (rgb) => Style(
      fg: rgb.tones.selection.color,
      bg: rgb.resolve(null, const {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill).bg,
    ),
  ),
  (
    'primary rest / focused',
    (rgb) => Style(fg: rgb.fill(rgb.tones.primary).bg, bg: _face(rgb, const {WidgetState.focused}).bg),
  ),
  (
    'primary rest / hovered',
    (rgb) => Style(fg: rgb.fill(rgb.tones.primary).bg, bg: _face(rgb, const {WidgetState.hover}).bg),
  ),
  ('background / border', (rgb) => Style(fg: rgb.tones.background.color, bg: rgb.tones.border.color)),
  ('surface / border', (rgb) => Style(fg: rgb.tones.surface.color, bg: rgb.tones.border.color)),
  ('border / muted', (rgb) => Style(fg: rgb.tones.border.color, bg: rgb.tones.muted.color)),
  ('muted / disabled', (rgb) => Style(fg: rgb.tones.muted.color, bg: rgb.tones.disabled.color)),
];

/// A grade for [ratio] against the WCAG 2 text thresholds: `AAA` at 7, `AA`
/// at 4.5, `large` at 3 (readable only as large or bold text), `fail` below.
String _grade(double ratio) {
  if (ratio >= 7) return 'AAA';
  if (ratio >= 4.5) return 'AA';
  if (ratio >= 3) return 'large';
  return 'fail';
}

/// The ink a grade paints in: success for a pass, warning for `large`,
/// error for `fail`.
Style _gradeInk(StyleResolver chrome, String grade) {
  final t = chrome.tones;
  return switch (grade) {
    'AAA' || 'AA' => chrome.ink(t.success),
    'large' => chrome.ink(t.warning),
    _ => chrome.ink(t.error),
  };
}

/// Hex text for one side of a pair: [colorLabel]'s convention, except
/// [Color.reset] also reads as unmeasurable and prints an em dash, the same
/// as a null color.
String _hexOrDash(Color? color) => (color == null || color == Color.reset) ? '—' : colorLabel(color);

/// The ratio text and the grade for one pair's `fg` over `bg`.
///
/// Either side missing or [Color.reset] makes the pair unmeasurable: the
/// ratio reads an em dash and the grade reads `n/a`, in muted ink.
({String ratio, String grade, Style gradeStyle}) _readout(StyleResolver chrome, Color? fg, Color? bg) {
  final muted = chrome.ink(chrome.tones.muted);
  if (fg == null || fg == Color.reset || bg == null || bg == Color.reset) {
    return (ratio: '—', grade: 'n/a', gradeStyle: muted);
  }
  final value = fg.contrastRatio(bg);
  final ratio = '${value.toStringAsFixed(2)}:1';
  final grade = _grade(value);
  return (ratio: ratio, grade: grade, gradeStyle: _gradeInk(chrome, grade));
}

/// The header row of a section's table, in muted ink. A [graded] table
/// ends with the grade column; a separation table stops at the ratio.
View _pairHeader(StyleResolver chrome, {required bool graded}) {
  final muted = chrome.ink(chrome.tones.muted);
  return Row(
    children: [
      col(22, Line('pair', style: muted)),
      col(5, Line(' Ab', style: muted)),
      col(8, Line('fg', style: muted)),
      col(8, Line('bg', style: muted)),
      col(8, Line('ratio', style: muted)),
      if (graded) col(5, Line('grade', style: muted)),
    ],
  );
}

/// One row: the pair's label, its swatch, both hex values, the ratio, and —
/// in a [graded] table — the grade, every measured value read straight off
/// [pair]'s style.
View _pairRow(StyleResolver chrome, StyleResolver rgb, _Pair pair, {required bool graded}) {
  final (label, styleOf) = pair;
  final style = styleOf(rgb);
  final readout = _readout(chrome, style.fg, style.bg);
  final muted = chrome.ink(chrome.tones.muted);
  final defaultText = chrome.ink(Tone(color: chrome.tones.background.on));
  return Row(
    children: [
      col(22, Line(label, style: muted)),
      swatch(4, style),
      const SizedBox(width: 1),
      col(8, Line(_hexOrDash(style.fg), style: defaultText)),
      col(8, Line(_hexOrDash(style.bg), style: defaultText)),
      col(8, Line(readout.ratio, style: muted)),
      if (graded) col(5, Line(readout.grade, style: readout.gradeStyle)),
    ],
  );
}

/// One bordered, titled table: a one-line [question] the table answers, a
/// header row, then [pairs], each measured through [rgb] and painted with
/// [chrome]'s tier-following chrome. A separation table is not [graded].
View _section(
  StyleResolver chrome,
  StyleResolver rgb,
  String title,
  String question,
  List<_Pair> pairs, {
  bool graded = true,
}) {
  final t = chrome.tones;
  return Container(
    border: BorderType.plain,
    borderStyle: chrome.border(const {}),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(title, style: chrome.ink(t.secondary))],
    child: Column(
      children: [
        Line(question, style: chrome.ink(t.muted)),
        _pairHeader(chrome, graded: graded),
        for (final pair in pairs) _pairRow(chrome, rgb, pair, graded: graded),
      ],
    ),
  );
}

/// Page 3 of the theme viewer: the contrast audit.
///
/// Three tables — text on a ground, fills and composed states, and
/// separation between two grounds — each row a pair painted as a swatch,
/// its hex values, and the ratio [Color.contrastRatio] returns; the first
/// two tables also grade it. The text and separation tables stack on the
/// left; the fills table stands on the right. [chrome] paints the page's
/// own title, section titles, and borders, so they degrade with the render
/// tier like the rest of the screen; every measured pair instead reads a
/// resolver locked to [RenderPolicy.color], since a ratio against a
/// terminal's own ANSI-16 or NO_COLOR palette cannot be measured.
View contrastPage(Theme theme, StyleResolver chrome) {
  final t = chrome.tones;
  final rgb = StyleResolver(theme, policy: RenderPolicy.color);
  return Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line(
        "Contrast: ratio is the WCAG 2 contrast ratio of a pair's two colors, 1:1 (same color) to 21:1 (black on white)",
        style: chrome.ink(t.secondary),
      ),
      Line(
        'grade: the ratio against the WCAG 2 text thresholds: AAA ≥ 7 · AA ≥ 4.5 · large ≥ 3 (large or bold text only) · fail',
        style: chrome.ink(t.muted),
      ),
      Line(
        "RGB tones only, so F3 changes no number: a terminal's own ANSI-16 or NO_COLOR palette cannot be measured",
        style: chrome.ink(t.muted),
      ),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxis: CrossAxisAlignment.stretch,
                children: [
                  _section(
                    chrome,
                    rgb,
                    ' Text on a ground ',
                    'ink over a ground: is the text readable?',
                    _textPairs,
                  ),
                  _section(
                    chrome,
                    rgb,
                    ' Separation ',
                    'ground next to ground: can you tell them apart? no grade',
                    _separationPairs,
                    graded: false,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _section(
                chrome,
                rgb,
                ' Fills and composed states ',
                "the tone's \"on\" ink over its color: readable on a fill?",
                _fillPairs,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
