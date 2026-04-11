import 'package:kiko/src/colors.dart';
import 'package:test/test.dart';

void main() {
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
      test('RGB color lightens toward white', () {
        const color = Color.rgb(0x808080);
        final lighter = color.lighten(0.5);
        expect(lighter.kind, ColorKind.rgb);
        // Each channel: 128 + (127 * 0.5) ≈ 192 = 0xC0
        expect(lighter.value, 0xC0C0C0);
      });

      test('amount 0.0 returns same RGB values', () {
        const color = Color.rgb(0x336699);
        final result = color.lighten(0);
        expect(result.value, 0x336699);
      });

      test('amount 1.0 returns white', () {
        const color = Color.rgb(0x336699);
        final result = color.lighten(1);
        expect(result.value, 0xFFFFFF);
      });

      test('ANSI dark maps to bright variant', () {
        expect(Color.red.lighten(0.5), Color.brightRed);
        expect(Color.blue.lighten(0.5), Color.brightBlue);
        expect(Color.black.lighten(0.5), Color.darkGray);
      });

      test('ANSI bright stays bright', () {
        expect(Color.brightRed.lighten(0.5), Color.brightRed);
        expect(Color.white.lighten(0.5), Color.white);
      });

      test('indexed converts to RGB then lightens', () {
        const color = Color.indexed(196); // red-ish
        final result = color.lighten(0.5);
        expect(result.kind, ColorKind.rgb);
      });
    });

    group('darken', () {
      test('RGB color darkens toward black', () {
        const color = Color.rgb(0x808080);
        final darker = color.darken(0.5);
        expect(darker.kind, ColorKind.rgb);
        // Each channel: 128 * 0.5 = 64 = 0x40
        expect(darker.value, 0x404040);
      });

      test('amount 0.0 returns same RGB values', () {
        const color = Color.rgb(0x336699);
        final result = color.darken(0);
        expect(result.value, 0x336699);
      });

      test('amount 1.0 returns black', () {
        const color = Color.rgb(0x336699);
        final result = color.darken(1);
        expect(result.value, 0x000000);
      });

      test('ANSI bright maps to dark variant', () {
        expect(Color.brightRed.darken(0.5), Color.red);
        expect(Color.brightBlue.darken(0.5), Color.blue);
        expect(Color.white.darken(0.5), Color.gray);
      });

      test('ANSI dark stays dark', () {
        expect(Color.red.darken(0.5), Color.red);
        expect(Color.black.darken(0.5), Color.black);
      });

      test('indexed converts to RGB then darkens', () {
        const color = Color.indexed(196);
        final result = color.darken(0.5);
        expect(result.kind, ColorKind.rgb);
      });
    });
  });
}
