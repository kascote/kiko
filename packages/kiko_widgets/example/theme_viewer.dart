import 'dart:io';

import 'package:kiko/kiko.dart';

// A visual reference for the theme doctrine (specs/theme-doctrine.md).
//
// The doctrine models every styled cell as a `Tone` — a color identity
// `(color, on)` — projected into paint one of three ways:
//
//   ink   fg only              (line glyphs, separators, accent text)
//   fill  fg: on, bg: color    (selected rows, button faces, badges)
//   wash  bg only              (crosshair tints under existing content)
//
// So this viewer lays each theme out as its tones, grouped the way the theme
// itself groups them (Intent / Neutral / Interaction), and shows every tone's
// two halves and all three projections side by side.

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class Model {
  int themeIndex = 0;
  static const List<Theme> themes = [Theme.dark, Theme.light, Theme.ember, Theme.ansiDark];
  static const themeNames = ['Kiko Dark', 'Kiko Light', 'Ember', 'ANSI-16 Dark'];

  Theme get theme => themes[themeIndex];
  String get themeName => themeNames[themeIndex];

  void nextTheme() => themeIndex = (themeIndex + 1) % themes.length;
  void prevTheme() => themeIndex = (themeIndex - 1 + themes.length) % themes.length;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(Model, Cmd?) update(Model model, Msg msg, UpdateContext _) {
  if (msg case KeyMsg(:final key)) {
    return switch (key) {
      'q' || 'escape' => (model, const Quit()),
      'right' || 'l' || 'tab' => (model..nextTheme(), null),
      'left' || 'h' || 'shift+tab' => (model..prevTheme(), null),
      _ => (model, null),
    };
  }
  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void view(Model model, Frame frame) {
  final theme = model.theme;

  // Fill the background with the theme's base tone (background.wash = bg only).
  frame.buffer.setStyle(frame.area, theme.background.wash);

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      // Header
      Container(
        border: BorderType.plain,
        borderStyle: StyleResolver(theme).border(const {}),
        child: Row(
          children: [
            Expanded(
              child: Line(
                ' Theme: ${model.themeName}',
                style: theme.primary.ink.copyWith(addModifier: Modifier.bold),
              ),
            ),
            _col(
              30,
              Align(
                alignment: Alignment.centerRight,
                child: Line('←/→: switch  q: quit ', style: theme.muted.ink),
              ),
            ),
          ],
        ),
      ),
      // One column per tone group — the doctrine's three families.
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _toneSection(theme, 'Intent', _intent(theme))),
            Expanded(child: _toneSection(theme, 'Neutral', _neutral(theme))),
            Expanded(child: _toneSection(theme, 'Interaction', _interaction(theme))),
          ],
        ),
      ),
    ],
  );

  frame.render(ui);
}

// The doctrine's tone groups, in the doctrine's order.

List<(String, Tone)> _intent(Theme t) => [
  ('primary', t.primary),
  ('secondary', t.secondary),
  ('accent', t.accent),
  ('error', t.error),
  ('warning', t.warning),
  ('success', t.success),
];

List<(String, Tone)> _neutral(Theme t) => [
  ('background', t.background),
  ('surface', t.surface),
  ('border', t.border),
  ('muted', t.muted),
  ('disabled', t.disabled),
];

List<(String, Tone)> _interaction(Theme t) => [
  ('focus', t.focus),
  ('selection', t.selection),
  ('cursor', t.cursor), // derived: a subtle lift of background
  ('hover', t.hover), // derived: a fainter lift of background
];

View _toneSection(Theme theme, String title, List<(String, Tone)> tones) {
  final rows = <View>[_headerRow(theme)];
  for (final (name, tone) in tones) {
    rows.add(_toneRow(theme, name, tone));
  }
  return Container(
    border: BorderType.plain,
    borderStyle: StyleResolver(theme).border(const {}),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(title, style: theme.focus.ink)],
    child: Column(children: rows),
  );
}

View _headerRow(Theme theme) {
  final label = theme.muted.ink;
  return Row(
    children: [
      _col(11, Line('Tone', style: label)),
      _col(8, Line('color', style: label)),
      _col(8, Line('on', style: label)),
      _col(4, Line('ink', style: label)),
      _col(4, Line('fill', style: label)),
      _col(4, Line('wash', style: label)),
    ],
  );
}

/// One tone: its name, its two halves as hex, then its three projections.
View _toneRow(Theme theme, String name, Tone tone) => Row(
  children: [
    // Name, in the theme's default text color.
    _col(11, Line(name, style: Style(fg: theme.background.on))),
    // color half — drawn in its own hue (its ink) so the swatch reads true.
    _col(8, Line(_hex(tone.color), style: tone.color != null ? tone.ink : theme.muted.ink)),
    // on half — drawn in the on color, or muted "—" when the tone has none.
    _col(8, Line(_hex(tone.on), style: tone.on != null ? Style(fg: tone.on) : theme.muted.ink)),
    // ink: fg only — tinted text over the theme background.
    _swatch(4, tone.ink),
    // fill: on over color.
    _swatch(4, tone.fill),
    // wash: bg only — default text sitting on the tint.
    _swatch(4, Style(fg: theme.background.on).patch(tone.wash)),
  ],
);

/// Pins [child] to an exact [width], one visual row tall.
View _col(int width, View child) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: child,
);

/// A projection swatch: `Ab` painted in [style], padded to [width] cells.
View _swatch(int width, Style style) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: Container(
    background: style,
    child: Line(' Ab ', style: style),
  ),
);

/// Format a tone half as hex, or an em dash when the half is unset.
String _hex(Color? color) {
  if (color == null) return '—';
  if (color == Color.reset) return 'reset';

  final rgb = color.toRgb();
  return '#${rgb.value.toRadixString(16).padLeft(6, '0')}';
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Theme Viewer').run(
      init: Model(),
      update: update,
      view: view,
    ),
  );
}
