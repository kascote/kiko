import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Ansi16Tones.derive', () {
    const theme = Theme(
      name: 'extremes',
      primary: SurfaceTone(color: Color.rgb(0x000000), on: Color.white), // pure black: darkest slot
      secondary: SurfaceTone(color: Color.rgb(0xffffff), on: Color.black), // pure white: lightest slot
      accent: SurfaceTone(color: Color.yellow, on: Color.black), // already an ANSI-16 color
      error: SurfaceTone(color: Color.rgb(0xff0000), on: Color.rgb(0x123456)), // `on` must be ignored
      warning: SurfaceTone(on: Color.rgb(0x123456)), // no color: `on` re-expresses through the same conversion
      success: SurfaceTone(color: Color.rgb(0x008000), on: Color.white),
      background: SurfaceTone(color: Color.rgb(0x101010), on: Color.white),
      surface: SurfaceTone(color: Color.rgb(0x202020), on: Color.white),
      border: Tone(color: Color.rgb(0x303030)),
      muted: Tone(color: Color.rgb(0x404040)),
      disabled: Tone(color: Color.rgb(0x505050)),
      selection: SurfaceTone(color: Color.rgb(0x708090), on: Color.white),
    );

    test('a dark tone color derives white as its on', () {
      final table = Ansi16Tones.derive(theme);
      expect(table.primary.color, equals(Color.black));
      expect(table.primary.on, equals(Color.white));
    });

    test('a light tone color derives black as its on', () {
      final table = Ansi16Tones.derive(theme);
      expect(table.secondary.color, equals(Color.white));
      expect(table.secondary.on, equals(Color.black));
    });

    test('an ANSI-kind tone passes through unchanged', () {
      final table = Ansi16Tones.derive(theme);
      expect(table.accent.color, equals(Color.yellow));
    });

    test("on is picked from the mapped color, never from the theme's RGB on", () {
      final table = Ansi16Tones.derive(theme);
      // Pure red maps to the ANSI red slot; its on must come from that slot,
      // not from the 0x123456 the theme happened to pair it with.
      expect(table.error.color, equals(Color.red));
      expect(table.error.on, isNot(equals(const Color.rgb(0x123456))));
      expect(table.error.on, equals(Color.white));
    });

    test('a surface tone with no color keeps its own on, re-expressed through the same conversion', () {
      final table = Ansi16Tones.derive(theme);
      expect(table.warning.color, isNull);
      // warning.on starts from 0x123456, a dark blue, which maps to blue.
      expect(table.warning.on, equals(Color.blue));
    });

    test('a derived surface tone carries an on; a derived chrome tone has none', () {
      final table = Ansi16Tones.derive(theme);
      expect(table.primary, isA<SurfaceTone>());
      expect(table.primary.on, isNotNull);
      expect(table.border, isNot(isA<SurfaceTone>()));
    });

    test('every table entry is present', () {
      final table = Ansi16Tones.derive(theme);
      expect(table.background.color, isNotNull);
      expect(table.surface.color, isNotNull);
      expect(table.border.color, isNotNull);
      expect(table.muted.color, isNotNull);
      expect(table.disabled.color, isNotNull);
      expect(table.selection.color, isNotNull);
      expect(table.success.color, isNotNull);
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

    test('two equal themes built separately share one derived table', () {
      // A theme variant built fresh each frame (e.g. Theme.dark.copyWith(...))
      // is a new instance every time, never identical to a prior one. The
      // memo must key by value so it still hits the cached entry.
      final a = Theme.dark.copyWith(accent: Theme.dark.success);
      final b = Theme.dark.copyWith(accent: Theme.dark.success);
      expect(identical(a, b), isFalse);
      expect(a, equals(b));

      final first = Ansi16Tones.derive(a);
      final second = Ansi16Tones.derive(b);
      expect(identical(first, second), isTrue);
    });
  });

  group('Ansi16Tones value semantics', () {
    // Not const: every call builds a fresh instance, so equality here can
    // only pass by comparing fields, never by canonicalization.
    Ansi16Tones buildTable({SurfaceTone? primary}) => Ansi16Tones(
      primary: primary ?? const SurfaceTone(color: Color.cyan, on: Color.black),
      secondary: const SurfaceTone(color: Color.magenta, on: Color.black),
      accent: const SurfaceTone(color: Color.yellow, on: Color.black),
      error: const SurfaceTone(color: Color.red, on: Color.white),
      warning: const SurfaceTone(color: Color.yellow, on: Color.black),
      success: const SurfaceTone(color: Color.green, on: Color.black),
      background: const SurfaceTone(color: Color.black, on: Color.white),
      surface: const SurfaceTone(color: Color.darkGray, on: Color.white),
      border: const Tone(color: Color.gray),
      muted: const Tone(color: Color.darkGray),
      disabled: const Tone(color: Color.darkGray),
      selection: const SurfaceTone(color: Color.yellow, on: Color.black),
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
        primary: const SurfaceTone(color: Color.brightRed, on: Color.black),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
