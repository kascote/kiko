import 'package:kiko/kiko.dart';

import 'shared.dart';

// Page 3: the contrast audit. Three tables and a report. The ink table puts
// the text color, the three neutral rungs and the six intent inks over each
// ground they must read on, and checks each pair against its
// [ContrastTargets] entry. The fills table shows every fill and composed
// state with the WCAG 2 text grade. The separation table compares two grounds
// and carries no grade. The report is what [deriveTheme] would change in
// the current theme and spans the page's foot. Every ratio is
// [Color.contrastRatio]. The ink table stands on the left, the fills and
// separation tables stand on the right, so the page fits a 120-column terminal.

/// One measured pair: a label, the resolver call that yields its `fg` over
/// its `bg`, and the [ContrastTargets] ratio the pair must reach, if any.
typedef _Pair = (String label, Style Function(StyleResolver rgb) style, double? target);

/// How a table reads the ratio of each pair.
enum _Grading {
  /// The WCAG 2 text grade: `AAA`, `AA`, `large` or `fail`.
  wcag,

  /// Pass or fail against the pair's own target.
  target,

  /// No verdict; the ratio stands alone.
  none,
}

/// The style for [ink] painted over [ground]: [ink]'s color as the
/// foreground, [ground]'s color as the background.
Style _over(Tone ink, SurfaceTone ground) => Style(fg: ink.color, bg: ground.color);

/// The primary face, patched with [states] — the composed rows in
/// [_fillPairs] read this for "focused", "hovered", and "disabled".
Style _face(StyleResolver rgb, Set<WidgetState> states) =>
    rgb.resolve(rgb.fill(rgb.tones.primary), states, cls: PaintClass.fill);

/// The grounds an ink must read on, with the resolver tone for each.
const _inkGrounds = <(String, SurfaceTone Function(ToneSet))>[
  ('background', _background),
  ('surface', _surface),
  ('selection', _selection),
];

SurfaceTone _background(ToneSet t) => t.background;
SurfaceTone _surface(ToneSet t) => t.surface;
SurfaceTone _selection(ToneSet t) => t.selection;

// The tables are `final`, not `const`: each entry's style function is a
// closure over `rgb`, and an anonymous function is never a compile-time
// constant in Dart, even one that only reads its parameter.

/// Section 1: the text color and the neutral rungs over the background and
/// the surface, then each intent ink over the background, the surface and
/// the selection. Each row has a target.
final List<_Pair> _inkPairs = [
  for (final (ground, tone) in _inkGrounds.take(2))
    ('text/$ground', (rgb) => _over(Tone(color: tone(rgb.tones).on), tone(rgb.tones)), ContrastTargets.onFill),
  for (final (name, ink, target) in <(String, Tone Function(ToneSet), double)>[
    ('border', (t) => t.border, ContrastTargets.border),
    ('muted', (t) => t.muted, ContrastTargets.muted),
    ('disabled', (t) => t.disabled, ContrastTargets.disabled),
  ])
    for (final (ground, tone) in _inkGrounds.take(2))
      ('$name/$ground', (rgb) => _over(ink(rgb.tones), tone(rgb.tones)), target),
  for (final (name, ink) in <(String, Tone Function(ToneSet))>[
    ('primary', (t) => t.primary),
    ('secondary', (t) => t.secondary),
    ('accent', (t) => t.accent),
    ('error', (t) => t.error),
    ('warning', (t) => t.warning),
    ('success', (t) => t.success),
  ])
    for (final (ground, tone) in _inkGrounds)
      ('$name/$ground', (rgb) => _over(ink(rgb.tones), tone(rgb.tones)), ContrastTargets.ink),
];

/// Section 2: every [SurfaceTone] as its own fill, then the resolver's
/// composed states — the results a widget actually paints.
final List<_Pair> _fillPairs = [
  ('primary', (rgb) => rgb.fill(rgb.tones.primary), null),
  ('secondary', (rgb) => rgb.fill(rgb.tones.secondary), null),
  ('accent', (rgb) => rgb.fill(rgb.tones.accent), null),
  ('error', (rgb) => rgb.fill(rgb.tones.error), null),
  ('warning', (rgb) => rgb.fill(rgb.tones.warning), null),
  ('success', (rgb) => rgb.fill(rgb.tones.success), null),
  ('background', (rgb) => rgb.fill(rgb.tones.background), null),
  ('surface', (rgb) => rgb.fill(rgb.tones.surface), null),
  ('selection', (rgb) => rgb.fill(rgb.tones.selection), null),
  (
    'selected + cursor',
    (rgb) => rgb.resolve(null, const {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill),
    null,
  ),
  ('cursor on bare', (rgb) => rgb.resolve(null, const {WidgetState.cursor}, cls: PaintClass.fill), null),
  (
    'selected + disabled',
    (rgb) => rgb.resolve(null, const {WidgetState.selected, WidgetState.disabled}, cls: PaintClass.fill),
    null,
  ),
  (
    'cursor + disabled',
    (rgb) => rgb.resolve(null, const {WidgetState.cursor, WidgetState.disabled}, cls: PaintClass.fill),
    null,
  ),
  ('primary at rest', (rgb) => rgb.fill(rgb.tones.primary), null),
  ('primary focused', (rgb) => _face(rgb, const {WidgetState.focused}), null),
  ('primary hovered', (rgb) => _face(rgb, const {WidgetState.hover}), null),
  ('primary disabled', (rgb) => _face(rgb, const {WidgetState.disabled}), null),
  ('error at rest', (rgb) => rgb.fill(rgb.tones.error), null),
  (
    'error focused',
    (rgb) => rgb.resolve(rgb.fill(rgb.tones.error), const {WidgetState.focused}, cls: PaintClass.fill),
    null,
  ),
];

/// Section 3: ratio only, no verdict — two grounds compared against each
/// other, where the text thresholds do not apply.
final List<_Pair> _separationPairs = [
  ('bg/surface', (rgb) => Style(fg: rgb.tones.background.color, bg: rgb.tones.surface.color), null),
  ('bg/selection', (rgb) => Style(fg: rgb.tones.background.color, bg: rgb.tones.selection.color), null),
  (
    'sel/sel+cursor',
    (rgb) => Style(
      fg: rgb.tones.selection.color,
      bg: rgb.resolve(null, const {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill).bg,
    ),
    null,
  ),
  (
    'primary/focused',
    (rgb) => Style(fg: rgb.fill(rgb.tones.primary).bg, bg: _face(rgb, const {WidgetState.focused}).bg),
    null,
  ),
  (
    'primary/hovered',
    (rgb) => Style(fg: rgb.fill(rgb.tones.primary).bg, bg: _face(rgb, const {WidgetState.hover}).bg),
    null,
  ),
  ('border/muted', (rgb) => Style(fg: rgb.tones.border.color, bg: rgb.tones.muted.color), null),
  ('muted/disabled', (rgb) => Style(fg: rgb.tones.muted.color, bg: rgb.tones.disabled.color), null),
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

/// The ratio text and the verdict for one pair's `fg` over `bg`.
///
/// Either side missing or [Color.reset] makes the pair unmeasurable: the
/// ratio reads an em dash and the verdict reads `n/a`, in muted ink. A
/// [_Grading.target] verdict reads `ok` or `NO` and the [target] it was held
/// to.
({String ratio, String grade, Style gradeStyle}) _readout(
  StyleResolver chrome,
  Color? fg,
  Color? bg,
  _Grading grading,
  double? target,
) {
  final muted = chrome.ink(chrome.tones.muted);
  if (fg == null || fg == Color.reset || bg == null || bg == Color.reset) {
    return (ratio: '—', grade: 'n/a', gradeStyle: muted);
  }
  final value = fg.contrastRatio(bg);
  final ratio = '${value.toStringAsFixed(2)}:1';
  if (grading == _Grading.target && target != null) {
    final pass = value >= target;
    return (
      ratio: ratio,
      grade: '${pass ? 'ok' : 'NO'} ${target.toStringAsFixed(1)}',
      gradeStyle: chrome.ink(pass ? chrome.tones.success : chrome.tones.error),
    );
  }
  final grade = _grade(value);
  return (ratio: ratio, grade: grade, gradeStyle: _gradeInk(chrome, grade));
}

/// The header row of a section's table, in muted ink. A graded table ends
/// with the verdict column; a separation table stops at the ratio.
View _pairHeader(StyleResolver chrome, {required _Grading grading}) {
  final muted = chrome.ink(chrome.tones.muted);
  return Row(
    children: [
      col(20, Line('pair', style: muted)),
      col(5, Line(' Ab', style: muted)),
      col(8, Line('fg', style: muted)),
      col(8, Line('bg', style: muted)),
      col(8, Line('ratio', style: muted)),
      if (grading != _Grading.none) col(7, Line(grading == _Grading.target ? 'need' : 'grade', style: muted)),
    ],
  );
}

/// One row: the pair's label, its swatch, both hex values, the ratio, and —
/// in a graded table — the verdict, every measured value read straight off
/// [pair]'s style.
View _pairRow(StyleResolver chrome, StyleResolver rgb, _Pair pair, {required _Grading grading}) {
  final (label, styleOf, target) = pair;
  final style = styleOf(rgb);
  final readout = _readout(chrome, style.fg, style.bg, grading, target);
  final muted = chrome.ink(chrome.tones.muted);
  final defaultText = chrome.ink(Tone(color: chrome.tones.background.on));
  return Row(
    children: [
      col(20, Line(label, style: muted)),
      swatch(4, style),
      const SizedBox(width: 1),
      col(8, Line(_hexOrDash(style.fg), style: defaultText)),
      col(8, Line(_hexOrDash(style.bg), style: defaultText)),
      col(8, Line(readout.ratio, style: muted)),
      if (grading != _Grading.none) col(7, Line(readout.grade, style: readout.gradeStyle)),
    ],
  );
}

/// One bordered, titled table: a one-line [question] the table answers, a
/// header row, then [pairs], each measured through [rgb] and painted with
/// [chrome]'s tier-following chrome.
View _section(
  StyleResolver chrome,
  StyleResolver rgb,
  String title,
  String question,
  List<_Pair> pairs, {
  required _Grading grading,
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
        _pairHeader(chrome, grading: grading),
        for (final pair in pairs) _pairRow(chrome, rgb, pair, grading: grading),
      ],
    ),
  );
}

/// The report [deriveTheme] returns for [theme], one line per entry, in a
/// titled box: what it would change and which published colors fail a check.
View _report(StyleResolver chrome, Theme theme) {
  final t = chrome.tones;
  return Container(
    border: BorderType.plain,
    borderStyle: chrome.border(const {}),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(' Derivation report ', style: chrome.ink(t.secondary))],
    child: Column(
      children: [
        for (final line in deriveTheme(theme).$2.toString().split('\n')) Line(line, style: chrome.ink(t.muted)),
      ],
    ),
  );
}

/// Page 3 of the theme viewer: the contrast audit.
///
/// The ink table holds the text color, the neutral rungs and the intent inks
/// over each ground they read on, each against its [ContrastTargets] entry.
/// The report under the tables is what [deriveTheme] says about [theme]. The fills
/// table and the separation table stand on the right. [chrome] paints the
/// page's own title, section titles, and borders, so they degrade with the
/// render tier like the rest of the screen; every measured pair instead
/// reads a resolver locked to [RenderPolicy.color], since a ratio against a
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
        'need: the ContrastTargets ratio the pair must reach · grade: AAA ≥ 7 · AA ≥ 4.5 · large ≥ 3 · fail',
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
                    ' Ink on a ground ',
                    'ink over a ground it must read on: is the target met?',
                    _inkPairs,
                    grading: _Grading.target,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxis: CrossAxisAlignment.stretch,
                children: [
                  _section(
                    chrome,
                    rgb,
                    ' Fills and composed states ',
                    "the tone's \"on\" ink over its color: readable on a fill?",
                    _fillPairs,
                    grading: _Grading.wcag,
                  ),
                  _section(
                    chrome,
                    rgb,
                    ' Separation ',
                    'ground next to ground: can you tell them apart? no grade',
                    _separationPairs,
                    grading: _Grading.none,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _report(chrome, theme),
    ],
  );
}
