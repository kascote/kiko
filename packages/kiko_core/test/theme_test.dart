import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Theme', () {
    test('dark preset has all required styles', () {
      const theme = Theme.dark;

      expect(theme.primary.fg, isNotNull);
      expect(theme.primary.bg, isNotNull);
      expect(theme.secondary.fg, isNotNull);
      expect(theme.accent.fg, isNotNull);
      expect(theme.error.fg, isNotNull);
      expect(theme.success.fg, isNotNull);
      expect(theme.warning.fg, isNotNull);
      expect(theme.surface.fg, isNotNull);
      expect(theme.surface.bg, isNotNull);
      expect(theme.background.fg, isNotNull);
      expect(theme.background.bg, isNotNull);
      expect(theme.focus.fg, isNotNull);
      expect(theme.muted.fg, isNotNull);
      expect(theme.disabled.fg, isNotNull);
      expect(theme.border.fg, isNotNull);
      expect(theme.highlight.fg, isNotNull);
      expect(theme.highlight.bg, isNotNull);
    });

    test('light preset has all required styles', () {
      const theme = Theme.light;

      expect(theme.primary.fg, isNotNull);
      expect(theme.primary.bg, isNotNull);
      expect(theme.secondary.fg, isNotNull);
      expect(theme.accent.fg, isNotNull);
      expect(theme.error.fg, isNotNull);
      expect(theme.success.fg, isNotNull);
      expect(theme.warning.fg, isNotNull);
      expect(theme.surface.fg, isNotNull);
      expect(theme.surface.bg, isNotNull);
      expect(theme.background.fg, isNotNull);
      expect(theme.background.bg, isNotNull);
      expect(theme.focus.fg, isNotNull);
      expect(theme.muted.fg, isNotNull);
      expect(theme.disabled.fg, isNotNull);
      expect(theme.border.fg, isNotNull);
      expect(theme.highlight.fg, isNotNull);
      expect(theme.highlight.bg, isNotNull);
    });

    test('ansiDark preset uses ANSI colors', () {
      const theme = Theme.ansiDark;

      expect(theme.primary.fg, equals(Color.cyan));
      expect(theme.primary.bg, equals(Color.black));
      expect(theme.error.fg, equals(Color.red));
      expect(theme.success.fg, equals(Color.green));
      expect(theme.background.fg, equals(Color.white));
      expect(theme.background.bg, equals(Color.black));
    });

    test('focus has bold modifier', () {
      expect(Theme.dark.focus.addModifier.has(Modifier.bold), isTrue);
      expect(Theme.light.focus.addModifier.has(Modifier.bold), isTrue);
      expect(Theme.ansiDark.focus.addModifier.has(Modifier.bold), isTrue);
    });

    test('disabled has dim modifier', () {
      expect(Theme.dark.disabled.addModifier.has(Modifier.dim), isTrue);
      expect(Theme.light.disabled.addModifier.has(Modifier.dim), isTrue);
      expect(Theme.ansiDark.disabled.addModifier.has(Modifier.dim), isTrue);
    });

    group('copyWith', () {
      test('replaces single field', () {
        const customPrimary = Style(fg: Color.red, bg: Color.white);
        final theme = Theme.ansiDark.copyWith(primary: customPrimary);

        expect(theme.primary, equals(customPrimary));
        expect(theme.secondary, equals(Theme.ansiDark.secondary));
        expect(theme.error, equals(Theme.ansiDark.error));
      });

      test('replaces multiple fields', () {
        const customPrimary = Style(fg: Color.red);
        const customError = Style(fg: Color.magenta);
        final theme = Theme.ansiDark.copyWith(
          primary: customPrimary,
          error: customError,
        );

        expect(theme.primary, equals(customPrimary));
        expect(theme.error, equals(customError));
        expect(theme.secondary, equals(Theme.ansiDark.secondary));
      });

      test('null values keep original', () {
        final theme = Theme.ansiDark.copyWith();

        expect(theme.primary, equals(Theme.ansiDark.primary));
        expect(theme.secondary, equals(Theme.ansiDark.secondary));
        expect(theme.background, equals(Theme.ansiDark.background));
      });
    });

    group('equality', () {
      test('same presets are equal', () {
        expect(Theme.ansiDark, equals(Theme.ansiDark));
      });

      test('identical themes are equal', () {
        const theme1 = Theme(
          primary: Style(fg: Color.cyan),
          secondary: Style(fg: Color.magenta),
          accent: Style(fg: Color.yellow),
          error: Style(fg: Color.red),
          success: Style(fg: Color.green),
          warning: Style(fg: Color.yellow),
          surface: Style(fg: Color.white),
          background: Style(fg: Color.white, bg: Color.black),
          focus: Style(fg: Color.cyan),
          muted: Style(fg: Color.gray),
          disabled: Style(fg: Color.darkGray),
          border: Style(fg: Color.gray),
          highlight: Style(fg: Color.black, bg: Color.yellow),
        );
        const theme2 = Theme(
          primary: Style(fg: Color.cyan),
          secondary: Style(fg: Color.magenta),
          accent: Style(fg: Color.yellow),
          error: Style(fg: Color.red),
          success: Style(fg: Color.green),
          warning: Style(fg: Color.yellow),
          surface: Style(fg: Color.white),
          background: Style(fg: Color.white, bg: Color.black),
          focus: Style(fg: Color.cyan),
          muted: Style(fg: Color.gray),
          disabled: Style(fg: Color.darkGray),
          border: Style(fg: Color.gray),
          highlight: Style(fg: Color.black, bg: Color.yellow),
        );

        expect(theme1, equals(theme2));
        expect(theme1.hashCode, equals(theme2.hashCode));
      });

      test('different themes are not equal', () {
        const theme1 = Theme(
          primary: Style(fg: Color.cyan),
          secondary: Style(fg: Color.magenta),
          accent: Style(fg: Color.yellow),
          error: Style(fg: Color.red),
          success: Style(fg: Color.green),
          warning: Style(fg: Color.yellow),
          surface: Style(fg: Color.white),
          background: Style(fg: Color.white, bg: Color.black),
          focus: Style(fg: Color.cyan),
          muted: Style(fg: Color.gray),
          disabled: Style(fg: Color.darkGray),
          border: Style(fg: Color.gray),
          highlight: Style(fg: Color.black, bg: Color.yellow),
        );
        const theme2 = Theme(
          primary: Style(fg: Color.red), // different
          secondary: Style(fg: Color.magenta),
          accent: Style(fg: Color.yellow),
          error: Style(fg: Color.red),
          success: Style(fg: Color.green),
          warning: Style(fg: Color.yellow),
          surface: Style(fg: Color.white),
          background: Style(fg: Color.white, bg: Color.black),
          focus: Style(fg: Color.cyan),
          muted: Style(fg: Color.gray),
          disabled: Style(fg: Color.darkGray),
          border: Style(fg: Color.gray),
          highlight: Style(fg: Color.black, bg: Color.yellow),
        );

        expect(theme1, isNot(equals(theme2)));
      });

      test('dark and light are different', () {
        expect(Theme.dark, isNot(equals(Theme.light)));
      });
    });

    group('usage patterns', () {
      test('primary.inverted for buttons', () {
        final buttonStyle = Theme.ansiDark.primary.inverted;

        expect(buttonStyle.fg, equals(Color.black));
        expect(buttonStyle.bg, equals(Color.cyan));
      });

      test('background.fg for default text', () {
        final textColor = Theme.ansiDark.background.fg;

        expect(textColor, equals(Color.white));
      });

      test('error.inverted for destructive buttons', () {
        final deleteStyle = Theme.ansiDark.error.inverted;

        expect(deleteStyle.bg, equals(Color.red));
        expect(deleteStyle.fg, equals(Color.white));
      });
    });
  });
}
