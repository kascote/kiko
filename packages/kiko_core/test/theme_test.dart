import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Theme', () {
    test('dark preset has all required tones', () {
      const theme = Theme.dark;

      expect(theme.primary.color, isNotNull);
      expect(theme.primary.on, isNotNull);
      expect(theme.secondary.color, isNotNull);
      expect(theme.accent.color, isNotNull);
      expect(theme.error.color, isNotNull);
      expect(theme.warning.color, isNotNull);
      expect(theme.success.color, isNotNull);
      expect(theme.background.color, isNotNull);
      expect(theme.background.on, isNotNull);
      expect(theme.surface.color, isNotNull);
      expect(theme.surface.on, isNotNull);
      expect(theme.border.color, isNotNull);
      expect(theme.muted.color, isNotNull);
      expect(theme.disabled.color, isNotNull);
      expect(theme.selection.color, isNotNull);
      expect(theme.selection.on, isNotNull);
    });

    for (final (name, theme) in [
      ('catppuccin', Theme.catppuccin),
      ('rosePine', Theme.rosePine),
      ('gruvbox', Theme.gruvbox),
      ('monokai', Theme.monokai),
      ('nord', Theme.nord),
      ('tokyoNight', Theme.tokyoNight),
      ('oneDark', Theme.oneDark),
      ('dracula', Theme.dracula),
      ('solarized', Theme.solarized),
    ]) {
      test('$name preset has all required tones', () {
        expect(theme.primary.color, isNotNull);
        expect(theme.primary.on, isNotNull);
        expect(theme.secondary.color, isNotNull);
        expect(theme.accent.color, isNotNull);
        expect(theme.error.color, isNotNull);
        expect(theme.warning.color, isNotNull);
        expect(theme.success.color, isNotNull);
        expect(theme.background.color, isNotNull);
        expect(theme.background.on, isNotNull);
        expect(theme.surface.color, isNotNull);
        expect(theme.surface.on, isNotNull);
        expect(theme.border.color, isNotNull);
        expect(theme.muted.color, isNotNull);
        expect(theme.disabled.color, isNotNull);
        expect(theme.selection.color, isNotNull);
        expect(theme.selection.on, isNotNull);
      });
    }

    test('background tone: color is the base bg, on is default text', () {
      // The surface-shaped tones invert the old Style(fg: text, bg: bg) layout:
      // the identity color is the bg, the readable color is the text.
      expect(Theme.dark.background.color, equals(const Color.rgb(0x0d1117)));
      expect(Theme.dark.background.on, equals(const Color.rgb(0xc9d1d9)));
      expect(Theme.dark.surface.color, equals(const Color.rgb(0x161b22)));
      expect(Theme.dark.surface.on, equals(const Color.rgb(0xc9d1d9)));
    });

    test('selection carries a color and a readable on', () {
      // Old highlight Style(fg: F, bg: B) maps to selection SurfaceTone(color: B, on: F).
      expect(Theme.dark.selection.color, equals(const Color.rgb(0x264a5c)));
      expect(Theme.dark.selection.on, equals(const Color.rgb(0xc9d1d9)));
    });

    test('no tone carries a modifier — modifiers ride on projections', () {
      // Tones are pure color; bold/dim/blink come from the resolver matrix.
      expect(Theme.dark.primary.ink.addModifier, equals(Modifier.empty));
      expect(Theme.dark.disabled.ink.addModifier, equals(Modifier.empty));
    });

    group('state step and de-emphasis', () {
      test('one state step is 0.12 of OKLab lightness', () {
        expect(Theme.step, equals(0.12));
      });

      test('every shipped theme de-emphasises by 0.45 unless told otherwise', () {
        for (final theme in _shipped) {
          expect(theme.deEmphasis, equals(0.45), reason: theme.name);
        }
      });

      test('a theme takes its own de-emphasis amount', () {
        expect(Theme.dark.copyWith(deEmphasis: 0.6).deEmphasis, equals(0.6));
      });
    });

    group('copyWith', () {
      test('replaces a single tone', () {
        const customPrimary = SurfaceTone(color: Color.red, on: Color.white);
        final theme = Theme.gruvbox.copyWith(primary: customPrimary);

        expect(theme.primary, equals(customPrimary));
        expect(theme.secondary, equals(Theme.gruvbox.secondary));
        expect(theme.error, equals(Theme.gruvbox.error));
      });

      test('null values keep the original', () {
        final theme = Theme.gruvbox.copyWith();

        expect(theme.primary, equals(Theme.gruvbox.primary));
        expect(theme.background, equals(Theme.gruvbox.background));
      });

      test('a variant paints its changed tone under ANSI-16', () {
        final variant = Theme.dark.copyWith(selection: Theme.dark.error);
        final resolver = StyleResolver(variant, policy: RenderPolicy.ansi16);
        final selected = resolver.resolve(null, const {WidgetState.selected}, cls: PaintClass.fill);

        expect(selected.bg, equals(resolver.tones.error.color));
        expect(selected.bg, isNot(equals(Ansi16Tones.derive(Theme.dark).selection.color)));
      });

      test('renaming to selection replaces the old highlight token', () {
        const custom = SurfaceTone(color: Color.blue, on: Color.white);
        final theme = Theme.dark.copyWith(selection: custom);
        expect(theme.selection, equals(custom));
      });
    });

    group('equality', () {
      test('same presets are equal', () {
        expect(Theme.gruvbox, equals(Theme.gruvbox));
        expect(Theme.gruvbox.hashCode, equals(Theme.gruvbox.hashCode));
      });

      test('two presets are different', () {
        expect(Theme.dark, isNot(equals(Theme.catppuccin)));
      });

      test('differing in one tone is unequal', () {
        final other = Theme.dark.copyWith(
          primary: const SurfaceTone(color: Color.red, on: Color.white),
        );
        expect(Theme.dark, isNot(equals(other)));
      });

      test('differing in de-emphasis is unequal', () {
        final other = Theme.dark.copyWith(deEmphasis: 0.6);
        expect(other, isNot(equals(Theme.dark)));
        expect(other.hashCode, isNot(equals(Theme.dark.hashCode)));
      });
    });

    group('projection usage patterns', () {
      test('primary.fill for buttons (fg: on, bg: color)', () {
        final buttonStyle = _plain.primary.fill;

        expect(buttonStyle.fg, equals(Color.black));
        expect(buttonStyle.bg, equals(Color.cyan));
      });

      test('background.on for default text', () {
        expect(_plain.background.on, equals(Color.white));
      });

      test('border.ink for chrome carries no background', () {
        expect(Theme.dark.border.ink.fg, equals(Theme.dark.border.color));
        expect(Theme.dark.border.ink.bg, isNull);
      });
    });
  });
}

const List<Theme> _shipped = [
  Theme.dark,
  Theme.catppuccin,
  Theme.rosePine,
  Theme.gruvbox,
  Theme.monokai,
  Theme.nord,
  Theme.tokyoNight,
  Theme.oneDark,
  Theme.dracula,
  Theme.solarized,
];

/// A theme on plain ANSI colors, for tests that read projections.
const _plain = Theme(
  name: 'plain',
  primary: SurfaceTone(color: Color.cyan, on: Color.black),
  secondary: SurfaceTone(color: Color.magenta, on: Color.black),
  accent: SurfaceTone(color: Color.yellow, on: Color.black),
  error: SurfaceTone(color: Color.red, on: Color.white),
  warning: SurfaceTone(color: Color.yellow, on: Color.black),
  success: SurfaceTone(color: Color.green, on: Color.black),
  background: SurfaceTone(color: Color.black, on: Color.white),
  surface: SurfaceTone(color: Color.darkGray, on: Color.white),
  border: Tone(color: Color.gray),
  muted: Tone(color: Color.darkGray),
  disabled: Tone(color: Color.darkGray),
  selection: SurfaceTone(color: Color.yellow, on: Color.black),
);
