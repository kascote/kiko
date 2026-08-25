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
      expect(theme.focus.color, isNotNull);
      expect(theme.selection.color, isNotNull);
      expect(theme.selection.on, isNotNull);
    });

    test('light preset has all required tones', () {
      const theme = Theme.light;

      expect(theme.primary.color, isNotNull);
      expect(theme.primary.on, isNotNull);
      expect(theme.background.color, isNotNull);
      expect(theme.background.on, isNotNull);
      expect(theme.surface.color, isNotNull);
      expect(theme.selection.color, isNotNull);
      expect(theme.selection.on, isNotNull);
    });

    test('ansiDark preset uses ANSI colors', () {
      const theme = Theme.ansiDark;

      expect(theme.primary.color, equals(Color.cyan));
      expect(theme.primary.on, equals(Color.black));
      expect(theme.error.color, equals(Color.red));
      expect(theme.success.color, equals(Color.green));
      // background: color = base bg, on = default text.
      expect(theme.background.color, equals(Color.black));
      expect(theme.background.on, equals(Color.white));
    });

    test('background tone: color is the base bg, on is default text', () {
      // The surface-shaped tones invert the old Style(fg: text, bg: bg) layout:
      // the identity color is the bg, the readable color is the text.
      expect(Theme.dark.background.color, equals(const Color.rgb(0x0d1117)));
      expect(Theme.dark.background.on, equals(const Color.rgb(0xc9d1d9)));
      expect(Theme.dark.surface.color, equals(const Color.rgb(0x161b22)));
      expect(Theme.dark.surface.on, equals(const Color.rgb(0xc9d1d9)));
    });

    test('selection carries a color and a readable on', () {
      // Old highlight Style(fg: F, bg: B) maps to selection Tone(color: B, on: F).
      expect(Theme.dark.selection.color, equals(const Color.rgb(0x264a5c)));
      expect(Theme.dark.selection.on, equals(const Color.rgb(0xc9d1d9)));
    });

    test('no tone carries a modifier — modifiers ride on projections', () {
      // Tones are pure color; bold/dim/blink come from the resolver matrix.
      expect(Theme.dark.focus.ink.addModifier, equals(Modifier.empty));
      expect(Theme.dark.disabled.ink.addModifier, equals(Modifier.empty));
    });

    group('derived cursor and hover', () {
      test('dark theme derives washes by lifting the background', () {
        const theme = Theme.dark;
        final base = theme.background.color!;

        expect(theme.cursor.color, equals(base.lift(0.10)));
        expect(theme.cursor.on, equals(theme.background.on));
        expect(theme.hover.color, equals(base.lift(0.08)));
      });

      test('light theme derives washes by lifting (darkening) the background', () {
        const theme = Theme.light;
        final base = theme.background.color!;

        // On a light base, lift darkens.
        expect(theme.cursor.color, equals(base.lift(0.10)));
        expect(theme.cursor.color, equals(base.darken(0.10)));
      });

      test('explicit cursor/hover win over derivation', () {
        const custom = Tone(color: Color.rgb(0x2a1d10), on: Color.rgb(0xffffff));
        final theme = Theme.dark.copyWith(cursor: custom);

        expect(theme.cursor, equals(custom));
        // hover is still derived.
        expect(theme.hover.color, equals(theme.background.color!.lift(0.08)));
      });

      test('terminal-default background derives to an empty tone', () {
        const theme = Theme(
          primary: Tone(color: Color.cyan),
          secondary: Tone(color: Color.magenta),
          accent: Tone(color: Color.yellow),
          error: Tone(color: Color.red),
          warning: Tone(color: Color.yellow),
          success: Tone(color: Color.green),
          background: Tone(), // transparent: no color
          surface: Tone(color: Color.darkGray),
          border: Tone(color: Color.gray),
          muted: Tone(color: Color.darkGray),
          disabled: Tone(color: Color.darkGray),
          focus: Tone(color: Color.brightCyan),
          selection: Tone(color: Color.yellow),
        );

        expect(theme.cursor, equals(const Tone()));
        expect(theme.hover, equals(const Tone()));
      });
    });

    group('copyWith', () {
      test('replaces a single tone', () {
        const customPrimary = Tone(color: Color.red, on: Color.white);
        final theme = Theme.ansiDark.copyWith(primary: customPrimary);

        expect(theme.primary, equals(customPrimary));
        expect(theme.secondary, equals(Theme.ansiDark.secondary));
        expect(theme.error, equals(Theme.ansiDark.error));
      });

      test('null values keep the original', () {
        final theme = Theme.ansiDark.copyWith();

        expect(theme.primary, equals(Theme.ansiDark.primary));
        expect(theme.background, equals(Theme.ansiDark.background));
      });

      test('renaming to selection replaces the old highlight token', () {
        const custom = Tone(color: Color.blue, on: Color.white);
        final theme = Theme.dark.copyWith(selection: custom);
        expect(theme.selection, equals(custom));
      });
    });

    group('equality', () {
      test('same presets are equal', () {
        expect(Theme.ansiDark, equals(Theme.ansiDark));
        expect(Theme.ansiDark.hashCode, equals(Theme.ansiDark.hashCode));
      });

      test('dark and light are different', () {
        expect(Theme.dark, isNot(equals(Theme.light)));
      });

      test('differing in one tone is unequal', () {
        final other = Theme.dark.copyWith(primary: const Tone(color: Color.red));
        expect(Theme.dark, isNot(equals(other)));
      });

      test('explicit cursor differs from a derived one', () {
        final withCursor = Theme.dark.copyWith(
          cursor: const Tone(color: Color.rgb(0x123456)),
        );
        expect(withCursor, isNot(equals(Theme.dark)));
      });
    });

    group('projection usage patterns', () {
      test('primary.fill for buttons (fg: on, bg: color)', () {
        final buttonStyle = Theme.ansiDark.primary.fill;

        expect(buttonStyle.fg, equals(Color.black));
        expect(buttonStyle.bg, equals(Color.cyan));
      });

      test('background.on for default text', () {
        expect(Theme.ansiDark.background.on, equals(Color.white));
      });

      test('border.ink for chrome carries no background', () {
        expect(Theme.dark.border.ink.fg, equals(Theme.dark.border.color));
        expect(Theme.dark.border.ink.bg, isNull);
      });
    });

    group('derived cursor and hover', () {
      test('a preset that omits cursor and hover reports both derived', () {
        expect(Theme.dark.derivesCursor, isTrue);
        expect(Theme.dark.derivesHover, isTrue);
      });

      test('an explicit tone flips only its own flag', () {
        final custom = Theme.dark.copyWith(cursor: const Tone(color: Color.rgb(0x123456)));
        expect(custom.derivesCursor, isFalse);
        expect(custom.derivesHover, isTrue);
      });

      test('a copy without an override stays derived', () {
        expect(Theme.dark.copyWith(primary: const Tone(color: Color.red)).derivesCursor, isTrue);
      });
    });
  });
}
