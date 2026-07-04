import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

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

(Model, Cmd?) update(Model model, Msg msg) {
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

  // Fill background with theme color
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final ui = plume.Column<PaintToken>(
    crossAxisAlignment: plume.CrossAxisAlignment.stretch,
    children: [
      // Header
      box(
        border: BorderType.plain,
        borderStyle: theme.border,
        child: plume.Row<PaintToken>(
          children: [
            plume.Expanded<PaintToken>(
              child: lineNode(
                Line(
                  ' Theme: ${model.themeName}',
                  style: Style(fg: theme.primary.fg, addModifier: Modifier.bold),
                ),
              ),
            ),
            _col(
              30,
              lineNode(Line('←/→: switch  q: quit ', style: theme.muted, alignment: Alignment.right)),
            ),
          ],
        ),
      ),
      // Content
      plume.Expanded<PaintToken>(
        child: plume.Row<PaintToken>(
          crossAxisAlignment: plume.CrossAxisAlignment.stretch,
          children: [
            // Palette styles
            plume.Expanded<PaintToken>(child: _styleSection(theme, 'Palette Styles', _paletteStyles(theme))),
            // Semantic styles
            plume.Expanded<PaintToken>(child: _styleSection(theme, 'Semantic Styles', _semanticStyles(theme))),
          ],
        ),
      ),
    ],
  );

  frame.renderNode(ui);
}

List<(String, Style)> _paletteStyles(Theme t) => [
  ('primary', t.primary),
  ('secondary', t.secondary),
  ('accent', t.accent),
  ('error', t.error),
  ('success', t.success),
  ('warning', t.warning),
  ('surface', t.surface),
  ('background', t.background),
];

List<(String, Style)> _semanticStyles(Theme t) => [
  ('focus', t.focus),
  ('muted', t.muted),
  ('disabled', t.disabled),
  ('border', t.border),
  ('highlight', t.highlight),
];

plume.RenderNode<PaintToken> _styleSection(Theme theme, String title, List<(String, Style)> styles) {
  final rows = <plume.RenderNode<PaintToken>>[_headerRow(theme)];
  for (final (name, style) in styles) {
    rows.add(_styleRow(theme, name, style));
  }
  return box(
    border: BorderType.plain,
    borderStyle: theme.border,
    padding: const plume.EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(title, style: theme.focus)],
    child: plume.Column<PaintToken>(children: rows),
  );
}

plume.RenderNode<PaintToken> _headerRow(Theme theme) => plume.Row<PaintToken>(
  children: [
    _col(12, lineNode(Line('Name', style: theme.muted))),
    _col(10, lineNode(Line('fg', style: theme.muted))),
    _col(10, lineNode(Line('bg', style: theme.muted))),
    _col(8, lineNode(Line('Normal', style: theme.muted))),
    _col(10, lineNode(Line('Inverted', style: theme.muted))),
  ],
);

plume.RenderNode<PaintToken> _styleRow(Theme theme, String name, Style style) => plume.Row<PaintToken>(
  children: [
    // Name column
    _col(12, lineNode(Line(name, style: Style(fg: theme.background.fg)))),
    // fg hex
    _col(10, lineNode(Line(_colorHex(style.fg), style: Style(fg: style.fg)))),
    // bg hex
    _col(10, lineNode(Line(_colorHex(style.bg), style: Style(fg: style.bg ?? theme.muted.fg)))),
    // Normal swatch
    _swatch(8, style, 'Abc'),
    // Inverted swatch
    _swatch(10, style.inverted, 'Abc'),
  ],
);

/// Pins [child] to an exact [width], one visual row tall.
plume.RenderNode<PaintToken> _col(int width, plume.RenderNode<PaintToken> child) => plume.ConstrainedBox<PaintToken>(
  additionalConstraints: plume.BoxConstraints(minW: width, maxW: width),
  child: child,
);

/// A color chip: [width] cells of [style]'s background with [label] over it.
plume.RenderNode<PaintToken> _swatch(int width, Style style, String label) => plume.ConstrainedBox<PaintToken>(
  additionalConstraints: plume.BoxConstraints(minW: width, maxW: width),
  child: box(
    background: style,
    child: lineNode(Line(' $label ', style: style)),
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
