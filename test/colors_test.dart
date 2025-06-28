import 'package:kiko/src/colors.dart';
import 'package:test/test.dart';

void main() {
  group('Color', () {
    test('ansi factory creates correct Color', () {
      final color = Color.ansi(5);
      expect(color.value, 5);
      expect(color.kind, ColorKind.ansi);
    });

    test('ansi factory throws error for out of range values', () {
      expect(() => Color.ansi(-1), throwsArgumentError);
      expect(() => Color.ansi(16), throwsArgumentError);
    });

    test('indexed factory creates correct Color', () {
      final color = Color.indexed(100);
      expect(color.value, 100);
      expect(color.kind, ColorKind.indexed);
    });

    test('indexed factory throws error for out of range values', () {
      expect(() => Color.indexed(-1), throwsArgumentError);
      expect(() => Color.indexed(256), throwsArgumentError);
    });

    test('fromRGB factory creates correct Color', () {
      final color = Color.fromRGB(0x123456);
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
      final color = Color.ansi(5);
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
  });
}
