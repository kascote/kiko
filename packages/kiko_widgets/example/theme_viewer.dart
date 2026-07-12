import 'package:kiko/kiko.dart';

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
  final resolver = StyleResolver(theme);

  // Fill background with theme color
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      // Header
      Container(
        border: BorderType.plain,
        borderStyle: resolver.border(const {}),
        child: Row(
          children: [
            Expanded(
              child: Line(
                ' Theme: ${model.themeName}',
                style: Style(fg: theme.primary.color, addModifier: Modifier.bold),
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
      // Content
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            // Palette styles
            Expanded(child: _styleSection(theme, 'Palette Styles', _paletteStyles(theme))),
            // Semantic styles
            Expanded(child: _styleSection(theme, 'Semantic Styles', _semanticStyles(theme))),
          ],
        ),
      ),
    ],
  );

  frame.render(ui);
}

List<(String, Style)> _paletteStyles(Theme t) => [
  ('primary', t.primary.fill),
  ('secondary', t.secondary.fill),
  ('accent', t.accent.fill),
  ('error', t.error.fill),
  ('success', t.success.fill),
  ('warning', t.warning.fill),
  ('surface', t.surface.fill),
  ('background', t.background.fill),
];

List<(String, Style)> _semanticStyles(Theme t) => [
  ('focus', t.focus.fill),
  ('muted', t.muted.fill),
  ('disabled', t.disabled.fill),
  ('border', t.border.fill),
  ('selection', t.selection.fill),
];

View _styleSection(Theme theme, String title, List<(String, Style)> styles) {
  final rows = <View>[_headerRow(theme)];
  for (final (name, style) in styles) {
    rows.add(_styleRow(theme, name, style));
  }
  return Container(
    border: BorderType.plain,
    borderStyle: StyleResolver(theme).border(const {}),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(title, style: theme.focus.ink)],
    child: Column(children: rows),
  );
}

View _headerRow(Theme theme) => Row(
  children: [
    _col(12, Line('Name', style: theme.muted.ink)),
    _col(10, Line('fg', style: theme.muted.ink)),
    _col(10, Line('bg', style: theme.muted.ink)),
    _col(8, Line('Normal', style: theme.muted.ink)),
    _col(10, Line('Inverted', style: theme.muted.ink)),
  ],
);

View _styleRow(Theme theme, String name, Style style) => Row(
  children: [
    // Name column
    _col(12, Line(name, style: Style(fg: theme.background.on))),
    // fg hex
    _col(10, Line(_colorHex(style.fg), style: Style(fg: style.fg))),
    // bg hex
    _col(10, Line(_colorHex(style.bg), style: Style(fg: style.bg ?? theme.muted.color))),
    // Normal swatch
    _swatch(8, style, 'Abc'),
    // Inverted swatch
    _swatch(10, style.inverted, 'Abc'),
  ],
);

/// Pins [child] to an exact [width], one visual row tall.
View _col(int width, View child) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: child,
);

/// A color chip: [width] cells of [style]'s background with [label] over it.
View _swatch(int width, Style style, String label) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: Container(
    background: style,
    child: Line(' $label ', style: style),
  ),
);

/// Format color as hex string.
String _colorHex(Color? color) {
  if (color == null) return '-';
  if (color == Color.reset) return 'reset';

  final rgb = color.toRgb();
  return '#${rgb.value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Theme Viewer').run(
    init: Model(),
    update: update,
    view: view,
  );
}
