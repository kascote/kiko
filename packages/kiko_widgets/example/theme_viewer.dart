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

  final ui = Column(
    children: [
      // Header
      Fixed(
        3,
        child: Block(
          borders: Borders.all,
          borderStyle: theme.border,
          child: Row(
            children: [
              Expanded(
                child: Text.raw(
                  ' Theme: ${model.themeName}',
                  style: Style(fg: theme.primary.fg, addModifier: Modifier.bold),
                ),
              ),
              Fixed(
                30,
                child: Text.raw(
                  '←/→: switch  q: quit ',
                  style: theme.muted,
                  alignment: Alignment.right,
                ),
              ),
            ],
          ),
        ),
      ),
      // Content
      Expanded(
        child: Row(
          children: [
            // Palette styles
            Expanded(child: _StyleSection(theme, 'Palette Styles', _paletteStyles(theme))),
            // Semantic styles
            Expanded(child: _StyleSection(theme, 'Semantic Styles', _semanticStyles(theme))),
          ],
        ),
      ),
    ],
  );

  frame.renderWidget(ui, frame.area);
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

class _StyleSection implements Widget {
  final Theme theme;
  final String title;
  final List<(String, Style)> styles;

  const _StyleSection(this.theme, this.title, this.styles);

  @override
  void render(Rect area, Frame frame) {
    final block = Block(
      borders: Borders.all,
      borderStyle: theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
    ).titleTop(Line(title, style: theme.focus));
    final inner = block.inner(area);
    frame.renderWidget(block, area);

    final children = <LayoutChild>[Fixed(1, child: _HeaderRow(theme))];
    for (final (name, style) in styles) {
      children.add(Fixed(1, child: _StyleRow(theme, name, style)));
    }
    Column(children: children).render(inner, frame);
  }
}

class _HeaderRow implements Widget {
  final Theme theme;
  const _HeaderRow(this.theme);

  @override
  void render(Rect area, Frame frame) {
    Row(
      children: [
        Fixed(12, child: Text.raw('Name', style: theme.muted)),
        Fixed(10, child: Text.raw('fg', style: theme.muted)),
        Fixed(10, child: Text.raw('bg', style: theme.muted)),
        Fixed(8, child: Text.raw('Normal', style: theme.muted)),
        Fixed(10, child: Text.raw('Inverted', style: theme.muted)),
      ],
    ).render(area, frame);
  }
}

class _StyleRow implements Widget {
  final Theme theme;
  final String name;
  final Style style;

  const _StyleRow(this.theme, this.name, this.style);

  @override
  void render(Rect area, Frame frame) {
    Row(
      children: [
        // Name column
        Fixed(
          12,
          child: Text.raw(name, style: Style(fg: theme.background.fg)),
        ),
        // fg hex
        Fixed(
          10,
          child: Text.raw(_colorHex(style.fg), style: Style(fg: style.fg)),
        ),
        // bg hex
        Fixed(
          10,
          child: Text.raw(_colorHex(style.bg), style: Style(fg: style.bg ?? theme.muted.fg)),
        ),
        // Normal swatch
        Fixed(8, child: _Swatch(style, 'Abc')),
        // Inverted swatch
        Fixed(10, child: _Swatch(style.inverted, 'Abc')),
      ],
    ).render(area, frame);
  }
}

class _Swatch implements Widget {
  final Style style;
  final String label;

  const _Swatch(this.style, this.label);

  @override
  void render(Rect area, Frame frame) {
    Text.raw(' $label ', style: style).render(area, frame);
  }
}

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
