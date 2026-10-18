import 'dart:math' as math;

import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// Every shipped theme's hand-authored ANSI-16 rows as they stood before the
/// table was derived: theme name -> row name -> (color, on). Chrome rows have no `on`.
const handRows = <String, Map<String, (Color, Color?)>>{
  'dark': {
    'primary': (Color.cyan, Color.black),
    'secondary': (Color.blue, Color.white),
    'accent': (Color.brightRed, Color.white),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'catppuccin': {
    'primary': (Color.blue, Color.white),
    'secondary': (Color.magenta, Color.black),
    'accent': (Color.brightRed, Color.white),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'rosePine': {
    'primary': (Color.cyan, Color.black),
    'secondary': (Color.magenta, Color.black),
    'accent': (Color.brightMagenta, Color.black),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'gruvbox': {
    'primary': (Color.brightRed, Color.white),
    'secondary': (Color.blue, Color.white),
    'accent': (Color.magenta, Color.black),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'monokai': {
    'primary': (Color.cyan, Color.black),
    'secondary': (Color.magenta, Color.black),
    'accent': (Color.brightRed, Color.white),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'nord': {
    'primary': (Color.cyan, Color.black),
    'secondary': (Color.magenta, Color.black),
    'accent': (Color.brightRed, Color.white),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'tokyoNight': {
    'primary': (Color.blue, Color.white),
    'secondary': (Color.magenta, Color.black),
    'accent': (Color.brightRed, Color.white),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'oneDark': {
    'primary': (Color.blue, Color.white),
    'secondary': (Color.magenta, Color.black),
    'accent': (Color.brightRed, Color.white),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'dracula': {
    'primary': (Color.magenta, Color.black),
    'secondary': (Color.brightMagenta, Color.black),
    'accent': (Color.brightRed, Color.white),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
  'solarized': {
    'primary': (Color.blue, Color.white),
    'secondary': (Color.magenta, Color.black),
    'accent': (Color.brightMagenta, Color.black),
    'error': (Color.red, Color.white),
    'warning': (Color.yellow, Color.black),
    'success': (Color.green, Color.black),
    'background': (Color.black, Color.white),
    'surface': (Color.darkGray, Color.white),
    'border': (Color.darkGray, null),
    'muted': (Color.gray, null),
    'disabled': (Color.darkGray, null),
    'selection': (Color.blue, Color.white),
  },
};

const _themes = <String, Theme>{
  'dark': Theme.dark,
  'catppuccin': Theme.catppuccin,
  'rosePine': Theme.rosePine,
  'gruvbox': Theme.gruvbox,
  'monokai': Theme.monokai,
  'nord': Theme.nord,
  'tokyoNight': Theme.tokyoNight,
  'oneDark': Theme.oneDark,
  'dracula': Theme.dracula,
  'solarized': Theme.solarized,
};

const _intentRows = ['primary', 'secondary', 'accent', 'error', 'warning', 'success', 'selection'];
const _neutralRows = ['background', 'surface', 'border', 'muted', 'disabled'];

const _orange =
    'orange hue is nearest the red family and the derivation has no orange slot; the hand table used brightRed';
const _purple = 'a purple past the blue-magenta midpoint is nearest blue; the hand table chose magenta';
const _paleYellow = 'lighter than the bright cut, so it takes brightYellow; the hand table kept plain yellow';

/// The rows where the derived table differs from [handRows], with the reason.
/// A row listed here must differ; a row not listed must match.
const _accepted = <String, Map<String, String>>{
  'dark': {'accent': _orange},
  'catppuccin': {'accent': _orange, 'warning': _paleYellow},
  'rosePine': {
    'accent': 'a pink at hue 21 is nearest red; the hand table used brightMagenta',
    'success': 'the teal pine hue is nearest cyan; the hand table called it green',
  },
  'gruvbox': {
    'primary': _orange,
    'secondary': 'a gray-green at chroma 0.04 is nearest cyan; the hand table chose blue',
    'accent': 'a pink at hue 2 is nearest red; the hand table chose magenta',
    'success': 'a yellow-green at hue 111 is nearest yellow; the hand table chose green',
    'background': 'lightness 0.241 is over the black cut; one gray cut set cannot hold every surface and ground',
  },
  'monokai': {
    'secondary': _purple,
    'accent': _orange,
    'background': 'lightness 0.290 is over the black cut; the surface is darker than the ground in this theme',
  },
  'nord': {
    'accent': _orange,
    'background': 'lightness 0.324 is over the black cut; its surface (0.379) must stay above the ground',
    'disabled': 'lightness 0.642 is over the dark gray cut; the hand table placed it a rung below its muted',
  },
  'tokyoNight': {'accent': _orange},
  'oneDark': {'accent': _orange, 'background': 'lightness 0.263 is over the black cut'},
  'dracula': {
    'secondary': 'a pink at lightness 0.755 is under the bright cut; the hand table used brightMagenta',
    'accent': _orange,
    'warning': _paleYellow,
  },
  'solarized': {
    'secondary': _purple,
    'accent': 'a magenta at lightness 0.59 is under the bright cut; the hand table used brightMagenta',
    'success': 'an olive green at hue 119 is nearest yellow; the hand table chose green',
    'selection': 'a teal gray at hue 219 is nearest cyan; the hand table chose blue',
    'background': 'lightness 0.267 is over the black cut',
  },
};

void _expectRows(List<String> rows) {
  for (final MapEntry(key: name, value: theme) in _themes.entries) {
    final table = Ansi16Tones.derive(theme);
    final derived = <String, Tone>{
      'primary': table.primary,
      'secondary': table.secondary,
      'accent': table.accent,
      'error': table.error,
      'warning': table.warning,
      'success': table.success,
      'selection': table.selection,
      'background': table.background,
      'surface': table.surface,
      'border': table.border,
      'muted': table.muted,
      'disabled': table.disabled,
    };
    for (final row in rows) {
      final (handColor, handOn) = handRows[name]![row]!;
      final tone = derived[row]!;
      final on = tone is SurfaceTone ? tone.on : null;
      final matches = tone.color == handColor && on == handOn;
      if (_accepted[name]?.containsKey(row) ?? false) {
        expect(matches, isFalse, reason: '$name.$row is listed as an accepted difference but now matches the hand row');
      } else {
        expect(tone.color, handColor, reason: '$name.$row color');
        expect(on, handOn, reason: '$name.$row on');
      }
    }
  }
}

void main() {
  group('derived table against the former hand-authored rows', () {
    test('the intent rows match, except the listed differences', () => _expectRows(_intentRows));

    test('the neutral rows match, except the listed differences', () => _expectRows(_neutralRows));

    test('every accepted difference names a real theme and row', () {
      for (final MapEntry(key: name, value: rows) in _accepted.entries) {
        expect(_themes, contains(name));
        for (final row in rows.keys) {
          expect([..._intentRows, ..._neutralRows], contains(row), reason: '$name.$row');
        }
      }
    });
  });

  group('Ansi16Tones.derive by hue family', () {
    Theme withPrimary(Color color) => Theme.dark.copyWith(
      primary: SurfaceTone(color: color, on: Color.white),
    );
    Color primaryOf(Color color) => Ansi16Tones.derive(withPrimary(color)).primary.color!;
    Color oklab(double l, double chroma, double hueDegrees) {
      final radians = hueDegrees * math.pi / 180;
      return Oklab(l, chroma * math.cos(radians), chroma * math.sin(radians)).toColor();
    }

    test('the family centers are the OKLab hue angles of the dark ANSI colors', () {
      final centers = {for (final (slot, angle) in Ansi16Tones.hueCenters) slot: angle};

      expect(centers.keys, [Color.red, Color.yellow, Color.green, Color.cyan, Color.blue, Color.magenta]);
      for (final MapEntry(key: slot, value: angle) in centers.entries) {
        final lab = slot.toOklab();
        final expected = (math.atan2(lab.b, lab.a) * 180 / math.pi + 360) % 360;
        expect(angle, closeTo(expected, 1e-9), reason: '$slot');
      }
      expect(centers[Color.red], closeTo(29.2, 0.1));
      expect(centers[Color.yellow], closeTo(109.8, 0.1));
      expect(centers[Color.green], closeTo(142.5, 0.1));
      expect(centers[Color.cyan], closeTo(194.8, 0.1));
      expect(centers[Color.blue], closeTo(264.1, 0.1));
      expect(centers[Color.magenta], closeTo(328.4, 0.1));
    });

    test('each family color derives to its own slot', () {
      for (final slot in [Color.red, Color.yellow, Color.green, Color.cyan, Color.blue, Color.magenta]) {
        expect(primaryOf(slot.toRgb()), slot, reason: '$slot');
      }
    });

    test('a hue between two families goes to the nearer center, across the 0/360 seam too', () {
      expect(primaryOf(oklab(0.7, 0.1, 60)), Color.red, reason: '60 is nearer red (29) than yellow (110)');
      expect(primaryOf(oklab(0.7, 0.1, 85)), Color.yellow, reason: '85 is nearer yellow (110)');
      expect(primaryOf(oklab(0.7, 0.1, 290)), Color.blue, reason: '290 is nearer blue (264) than magenta (328)');
      expect(primaryOf(oklab(0.7, 0.1, 310)), Color.magenta, reason: '310 is nearer magenta (328)');
      expect(primaryOf(oklab(0.7, 0.1, 350)), Color.magenta, reason: '350 is 22 from magenta, 39 from red');
      expect(primaryOf(oklab(0.7, 0.1, 2)), Color.red, reason: '2 is 27 from red and 34 from magenta across the seam');
    });

    test('a color under the chroma cut is a gray by lightness', () {
      const chroma = Ansi16Tones.grayChroma;
      expect(primaryOf(oklab(0.5, chroma * 0.9, 29)), Color.darkGray);
      expect(primaryOf(oklab(0.5, chroma * 1.5, 29)), Color.red);
      expect(primaryOf(oklab(0.1, chroma * 0.5, 29)), Color.black);
      expect(primaryOf(oklab(0.7, chroma * 0.5, 29)), Color.gray);
      expect(primaryOf(oklab(0.97, chroma * 0.5, 29)), Color.white);
    });

    test('a hued color lighter than the bright cut takes the bright variant', () {
      const cut = Ansi16Tones.brightLightness;
      expect(primaryOf(oklab(cut - 0.03, 0.1, 110)), Color.yellow);
      expect(primaryOf(oklab(cut + 0.04, 0.1, 110)), Color.brightYellow);
      expect(primaryOf(oklab(cut - 0.03, 0.08, 195)), Color.cyan);
      expect(primaryOf(oklab(cut + 0.04, 0.05, 195)), Color.brightCyan);
    });

    test('the gray cuts are ordered and split the four grays', () {
      expect(Ansi16Tones.blackBelow, lessThan(Ansi16Tones.darkGrayBelow));
      expect(Ansi16Tones.darkGrayBelow, lessThan(Ansi16Tones.grayBelow));
      Color neutralOf(double l) =>
          Ansi16Tones.derive(Theme.dark.copyWith(muted: Tone(color: oklab(l, 0, 0)))).muted.color!;
      expect(neutralOf(Ansi16Tones.blackBelow - 0.02), Color.black);
      expect(neutralOf(Ansi16Tones.blackBelow + 0.02), Color.darkGray);
      expect(neutralOf(Ansi16Tones.darkGrayBelow - 0.02), Color.darkGray);
      expect(neutralOf(Ansi16Tones.darkGrayBelow + 0.02), Color.gray);
      expect(neutralOf(Ansi16Tones.grayBelow - 0.02), Color.gray);
      expect(neutralOf(Ansi16Tones.grayBelow + 0.02), Color.white);
    });

    test('a neutral tone is a gray whatever its chroma', () {
      final tinted = oklab(0.62, 0.07, 270);
      final table = Ansi16Tones.derive(
        Theme.dark.copyWith(
          muted: Tone(color: tinted),
          primary: withPrimary(tinted).primary,
        ),
      );
      expect(table.muted.color, Color.gray);
      expect(table.primary.color, Color.blue, reason: 'the same color on an intent row keeps its hue');
    });

    test('a selection with no hue of its own takes blue', () {
      final gray = oklab(0.48, 0.005, 60);
      final table = Ansi16Tones.derive(
        Theme.dark.copyWith(
          selection: SurfaceTone(color: gray, on: Color.white),
        ),
      );
      expect(table.selection.color, Color.blue);
      expect(table.selection.on, Color.white);
    });

    test('an indexed color converts through its RGB value', () {
      expect(primaryOf(const Color.indexed(1)), primaryOf(Color.red.toRgb()));
      expect(primaryOf(const Color.indexed(4)), Color.blue);
    });

    test('an ANSI color passes through unchanged, and a null color stays null', () {
      expect(primaryOf(Color.brightBlue), Color.brightBlue);
      final table = Ansi16Tones.derive(Theme.dark.copyWith(border: const Tone()));
      expect(table.border.color, isNull);
    });
  });

  group('the `on` of a derived surface tone', () {
    const white = {0, 1, 4, 8, 9, 12};

    test('is white on black, red, blue, dark gray, bright red and bright blue, black elsewhere', () {
      for (var slot = 0; slot < 16; slot++) {
        final theme = Theme.dark.copyWith(
          primary: SurfaceTone(color: Color.ansi(slot), on: const Color.rgb(0x123456)),
        );
        final on = Ansi16Tones.derive(theme).primary.on;
        expect(on, white.contains(slot) ? Color.white : Color.black, reason: 'slot $slot');
      }
    });

    test('is picked from the slot, never from the theme `on`', () {
      final theme = Theme.dark.copyWith(
        primary: const SurfaceTone(color: Color.rgb(0xffffff), on: Color.white),
      );
      expect(Ansi16Tones.derive(theme).primary.on, Color.black);
    });
  });
}
