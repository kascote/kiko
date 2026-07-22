import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Ansi16Tones.derive', () {
    const theme = Theme(
      primary: Tone(color: Color.rgb(0x000000)), // pure black: darkest slot
      secondary: Tone(color: Color.rgb(0xffffff)), // pure white: lightest slot
      accent: Tone(color: Color.yellow), // already an ANSI-16 color
      error: Tone(color: Color.rgb(0xff0000), on: Color.rgb(0x123456)), // `on` must be ignored
      warning: Tone(), // no color at all
      success: Tone(color: Color.rgb(0x008000)),
      background: Tone(color: Color.rgb(0x101010)),
      surface: Tone(color: Color.rgb(0x202020)),
      border: Tone(color: Color.rgb(0x303030)),
      muted: Tone(color: Color.rgb(0x404040)),
      disabled: Tone(color: Color.rgb(0x505050)),
      focus: Tone(color: Color.rgb(0x606060)),
      selection: Tone(color: Color.rgb(0x708090)),
      cursor: Tone(color: Color.rgb(0x123456)),
    );

    test('a dark tone color derives brightWhite as its on', () {
      final tones16 = Ansi16Tones.derive(theme);
      expect(tones16.primary.color, equals(Color.black));
      expect(tones16.primary.on, equals(Color.white));
    });

    test('a light tone color derives black as its on', () {
      final tones16 = Ansi16Tones.derive(theme);
      expect(tones16.secondary.color, equals(Color.white));
      expect(tones16.secondary.on, equals(Color.black));
    });

    test('an ANSI-kind tone passes through unchanged', () {
      final tones16 = Ansi16Tones.derive(theme);
      expect(tones16.accent.color, equals(Color.yellow));
    });

    test("on is picked from the mapped color, never from the theme's RGB on", () {
      final tones16 = Ansi16Tones.derive(theme);
      // Pure red maps to the ANSI brightRed slot; its on must come from that
      // slot's own luminance, not from the 0x123456 the theme happened to
      // pair it with.
      expect(tones16.error.color, equals(Color.brightRed));
      expect(tones16.error.on, isNot(equals(const Color.rgb(0x123456))));
      expect(tones16.error.on, equals(Color.white));
    });

    test('a tone with no color derives to a fully empty tone', () {
      final tones16 = Ansi16Tones.derive(theme);
      expect(tones16.warning.color, isNull);
      expect(tones16.warning.on, isNull);
    });

    test('every table entry is present', () {
      final tones16 = Ansi16Tones.derive(theme);
      expect(tones16.background.color, isNotNull);
      expect(tones16.surface.color, isNotNull);
      expect(tones16.border.color, isNotNull);
      expect(tones16.muted.color, isNotNull);
      expect(tones16.disabled.color, isNotNull);
      expect(tones16.focus.color, isNotNull);
      expect(tones16.selection.color, isNotNull);
      expect(tones16.cursor.color, isNotNull);
      expect(tones16.success.color, isNotNull);
    });

    test('deriving twice from the same Theme returns the identical instance', () {
      final first = Ansi16Tones.derive(theme);
      final second = Ansi16Tones.derive(theme);
      expect(identical(first, second), isTrue);
    });

    test('a built-in theme derives without error and memoizes', () {
      final first = Ansi16Tones.derive(Theme.dark);
      final second = Ansi16Tones.derive(Theme.dark);
      expect(identical(first, second), isTrue);
      expect(first.error.color, isNotNull);
    });
  });

  group('Ansi16Tones value semantics', () {
    // Not const: every call builds a fresh instance, so equality here can
    // only pass by comparing fields, never by canonicalization.
    Ansi16Tones buildTable({Tone? primary}) => Ansi16Tones(
      primary: primary ?? const Tone(color: Color.cyan, on: Color.black),
      secondary: const Tone(color: Color.magenta, on: Color.black),
      accent: const Tone(color: Color.yellow, on: Color.black),
      error: const Tone(color: Color.red, on: Color.white),
      warning: const Tone(color: Color.yellow, on: Color.black),
      success: const Tone(color: Color.green, on: Color.black),
      background: const Tone(color: Color.black, on: Color.white),
      surface: const Tone(color: Color.darkGray, on: Color.white),
      border: const Tone(color: Color.gray),
      muted: const Tone(color: Color.darkGray),
      disabled: const Tone(color: Color.darkGray),
      focus: const Tone(color: Color.brightCyan, on: Color.black),
      selection: const Tone(color: Color.yellow, on: Color.black),
      cursor: const Tone(color: Color.darkGray, on: Color.white),
    );

    test('two separately constructed equal tables compare equal and hash equal', () {
      final a = buildTable();
      final b = buildTable();
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a differing tone breaks equality', () {
      final a = buildTable();
      final b = buildTable(
        primary: const Tone(color: Color.brightRed, on: Color.black),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
