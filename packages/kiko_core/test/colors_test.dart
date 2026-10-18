import 'dart:math';

import 'package:kiko/src/colors.dart';
import 'package:kiko/src/theme.dart';
import 'package:test/test.dart';

void main() {
  oklabTests();
  group('Color', () {
    test('ansi factory creates correct Color', () {
      const color = Color.magenta;
      expect(color.value, 5);
      expect(color.kind, ColorKind.ansi);
    });

    test('indexed factory creates correct Color', () {
      const color = Color.indexed(100);
      expect(color.value, 100);
      expect(color.kind, ColorKind.indexed);
    });

    test('fromRGB factory creates correct Color', () {
      const color = Color.rgb(0x123456);
      expect(color.value, 0x123456);
      expect(color.kind, ColorKind.rgb);
    });

    test('fromRGBString factory creates correct Color', () {
      final color = Color.fromRGBString('#123456');
      expect(color.value, 0x123456);
      expect(color.kind, ColorKind.rgb);
    });

    test('fromRGBString factory throws error for invalid strings', () {
      expect(() => Color.fromRGBString('123456'), returnsNormally);
      expect(() => Color.fromRGBString('#12345'), throwsArgumentError);
      expect(() => Color.fromRGBString('#1234567'), throwsArgumentError);
    });

    test('fromHSV factory creates correct Color', () {
      final color = Color.fromHSV(0, 1, 1);
      expect(color.value, 0xFF0000); // Pure red

      final color2 = Color.fromHSV(120, 1, 1);
      expect(color2.value, 0x00FF00); // Pure green

      final color3 = Color.fromHSV(240, 1, 1);
      expect(color3.value, 0x0000FF); // Pure blue
    });

    test('fromHSV factory handles edge cases', () {
      final black = Color.fromHSV(0, 0, 0);
      expect(black.value, 0x000000); // Black
      expect(black.kind, ColorKind.rgb);

      final white = Color.fromHSV(0, 0, 1);
      expect(white.value, 0xFFFFFF); // White
      expect(black.kind, ColorKind.rgb);

      final gray = Color.fromHSV(0, 0, 0.498);
      expect(gray.value, 0x7F7F7F); // Gray
      expect(black.kind, ColorKind.rgb);

      final bananas = Color.fromHSV(330, 1, 0.3);
      expect(bananas.value, 0x4D0026);
      expect(bananas.kind, ColorKind.rgb);
    });

    test('toString returns correct format', () {
      const color = Color.magenta;
      expect(color.toString(), 'Color(5, ansi)');

      const resetColor = Color.reset;
      expect(resetColor.toString(), 'Color(Reset)');
    });

    test('predefined colors have correct values and kinds', () {
      expect(Color.black.value, 0);
      expect(Color.black.kind, ColorKind.ansi);

      expect(Color.red.value, 1);
      expect(Color.red.kind, ColorKind.ansi);

      expect(Color.green.value, 2);
      expect(Color.green.kind, ColorKind.ansi);

      expect(Color.yellow.value, 3);
      expect(Color.yellow.kind, ColorKind.ansi);

      expect(Color.blue.value, 4);
      expect(Color.blue.kind, ColorKind.ansi);

      expect(Color.magenta.value, 5);
      expect(Color.magenta.kind, ColorKind.ansi);

      expect(Color.cyan.value, 6);
      expect(Color.cyan.kind, ColorKind.ansi);

      expect(Color.gray.value, 7);
      expect(Color.gray.kind, ColorKind.ansi);

      expect(Color.darkGray.value, 8);
      expect(Color.darkGray.kind, ColorKind.ansi);

      expect(Color.brightRed.value, 9);
      expect(Color.brightRed.kind, ColorKind.ansi);

      expect(Color.brightGreen.value, 10);
      expect(Color.brightGreen.kind, ColorKind.ansi);

      expect(Color.brightYellow.value, 11);
      expect(Color.brightYellow.kind, ColorKind.ansi);

      expect(Color.brightBlue.value, 12);
      expect(Color.brightBlue.kind, ColorKind.ansi);

      expect(Color.brightMagenta.value, 13);
      expect(Color.brightMagenta.kind, ColorKind.ansi);

      expect(Color.brightCyan.value, 14);
      expect(Color.brightCyan.kind, ColorKind.ansi);

      expect(Color.white.value, 15);
      expect(Color.white.kind, ColorKind.ansi);
    });
    group('lighten', () {
      test('ANSI dark maps to bright variant', () {
        expect(Color.red.lighten(0.5), Color.brightRed);
        expect(Color.blue.lighten(0.5), Color.brightBlue);
        expect(Color.black.lighten(0.5), Color.darkGray);
      });

      test('ANSI bright stays bright', () {
        expect(Color.brightRed.lighten(0.5), Color.brightRed);
        expect(Color.white.lighten(0.5), Color.white);
      });

      test('a color that is not ANSI-16 comes back unchanged', () {
        const rgb = Color.rgb(0x808080);
        const indexed = Color.indexed(196);
        expect(rgb.lighten(0.5), rgb);
        expect(indexed.lighten(0.5), indexed);
        expect(Color.reset.lighten(0.5), Color.reset);
      });
    });

    group('luminance', () {
      test('black is 0 and white is 1', () {
        expect(const Color.rgb(0x000000).luminance, closeTo(0.0, 1e-9));
        expect(const Color.rgb(0xffffff).luminance, closeTo(1.0, 1e-9));
      });

      test('a dark base reads below mid, a light base above', () {
        expect(const Color.rgb(0x0d1117).luminance, lessThan(0.5));
        expect(const Color.rgb(0xf6f8fa).luminance, greaterThan(0.5));
      });

      test('ANSI colors resolve to RGB first', () {
        expect(Color.black.luminance, closeTo(0.0, 1e-9));
      });
    });

    group('relativeLuminance', () {
      test('black is 0 and white is 1', () {
        expect(const Color.rgb(0x000000).relativeLuminance, closeTo(0.0, 1e-9));
        expect(const Color.rgb(0xffffff).relativeLuminance, closeTo(1.0, 1e-9));
      });
    });

    group('contrastRatio', () {
      test('white on black is 21:1', () {
        expect(const Color.rgb(0xffffff).contrastRatio(const Color.rgb(0x000000)), closeTo(21.0, 0.01));
      });

      test('a color against itself is 1:1', () {
        const color = Color.rgb(0x808080);
        expect(color.contrastRatio(color), closeTo(1.0, 1e-9));
      });

      test('is symmetric', () {
        const a = Color.rgb(0xcaa356);
        const b = Color.rgb(0x14100b);
        expect(a.contrastRatio(b), equals(b.contrastRatio(a)));
      });

      test('a known pair rounds to 8.0:1', () {
        const foreground = Color.rgb(0xcaa356);
        const background = Color.rgb(0x14100b);
        final rounded = double.parse(foreground.contrastRatio(background).toStringAsFixed(1));
        expect(rounded, equals(8.0));
      });
    });
  });
}

void _expectClose(Color actual, Color expected) {
  final a = actual.toRgb().value;
  final e = expected.toRgb().value;
  for (final shift in [16, 8, 0]) {
    expect((((a >> shift) & 0xFF) - ((e >> shift) & 0xFF)).abs(), lessThanOrEqualTo(1), reason: '$actual vs $expected');
  }
}

void oklabTests() {
  group('Oklab', () {
    test('black is lightness 0 and white is lightness 1', () {
      expect(const Color.rgb(0x000000).toOklab().l, closeTo(0, 1e-6));
      expect(const Color.rgb(0xffffff).toOklab().l, closeTo(1, 1e-4));
      expect(const Color.rgb(0xffffff).toOklab().chroma, lessThan(1e-4));
    });

    test('round trips sRGB colors within one 8-bit step', () {
      for (final value in [0x58a6b0, 0x0d1117, 0xc9d1d9, 0xeb6f92, 0x2e3440, 0xff0000, 0x00ff00, 0x0000ff, 0x808080]) {
        _expectClose(Color.rgb(value).toOklab().toColor(), Color.rgb(value));
      }
    });

    test('shiftLightness moves lightness by the delta and keeps hue', () {
      const start = Color.rgb(0x264a5c);
      final lifted = start.shiftLightness(0.1);
      expect(lifted.toOklab().l, closeTo(start.toOklab().l + 0.1, 0.005));
      final before = start.toOklab();
      final after = lifted.toOklab();
      expect(atan2(after.b, after.a), closeTo(atan2(before.b, before.a), 0.02));
    });

    test('shiftLightness clamps at the ends of the range', () {
      expect(const Color.rgb(0xffffff).shiftLightness(0.5).toOklab().l, closeTo(1, 1e-3));
      expect(const Color.rgb(0x000000).shiftLightness(-0.5).toOklab().l, closeTo(0, 1e-3));
    });

    test('round trips background and surface of every shipped theme', () {
      const themes = [
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
      for (final theme in themes) {
        for (final color in [theme.background.color!, theme.surface.color!]) {
          final lab = color.toOklab();
          expect(lab.toColor().toOklab().l, closeTo(lab.l, 0.005), reason: '${theme.name} $color');
          _expectClose(lab.toColor(), color);
        }
      }
    });

    test('non-RGB colors convert through their RGB value', () {
      expect(Color.red.toOklab(), Color.red.toRgb().toOklab());
      expect(const Color.indexed(21).toOklab(), const Color.indexed(21).toRgb().toOklab());
      expect(Color.reset.toOklab(), const Color.rgb(0xc0c0c0).toOklab());
    });

    test('toColor fits an out-of-gamut triple by reducing chroma', () {
      final vivid = const Color.rgb(0xff0000).toOklab();
      final brighter = Oklab(0.9, vivid.a, vivid.b).toColor();
      expect(brighter.toOklab().l, closeTo(0.9, 0.01));
      expect(brighter.toOklab().chroma, lessThan(vivid.chroma));
    });
  });
}
