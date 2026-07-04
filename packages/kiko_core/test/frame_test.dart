import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('dimBackdrop', () {
    test('dims RGB colors', () {
      final area = Rect.create(x: 0, y: 0, width: 2, height: 1);
      final buffer = Buffer.empty(area);

      // Set cells with RGB colors
      buffer[(x: 0, y: 0)] = const Cell(
        char: 'A',
        fg: Color.rgb(0xFF0000), // red
        bg: Color.rgb(0x00FF00), // green
      );
      buffer[(x: 1, y: 0)] = const Cell(
        char: 'B',
        fg: Color.rgb(0x0000FF), // blue
        bg: Color.rgb(0xFFFFFF), // white
      );

      Frame(area, buffer, 0).dimBackdrop(factor: 0.5);

      // Check dimmed values (50%)
      final cell0 = buffer[(x: 0, y: 0)];
      expect(cell0.fg, equals(const Color.rgb(0x800000))); // dimmed red
      expect(cell0.bg, equals(const Color.rgb(0x008000))); // dimmed green

      final cell1 = buffer[(x: 1, y: 0)];
      expect(cell1.fg, equals(const Color.rgb(0x000080))); // dimmed blue
      expect(cell1.bg, equals(const Color.rgb(0x808080))); // dimmed white -> gray
    });

    test('dims with custom factor', () {
      final area = Rect.create(x: 0, y: 0, width: 1, height: 1);
      final buffer = Buffer.empty(area);

      buffer[(x: 0, y: 0)] = const Cell(
        char: 'X',
        fg: Color.rgb(0xFF0000),
      );

      Frame(area, buffer, 0).dimBackdrop(factor: 0.25); // 25% brightness

      final cell = buffer[(x: 0, y: 0)];
      expect(cell.fg, equals(const Color.rgb(0x400000))); // 25% of 255 = 64 = 0x40
    });

    test('converts ANSI to RGB and dims', () {
      final area = Rect.create(x: 0, y: 0, width: 1, height: 1);
      final buffer = Buffer.empty(area);

      buffer[(x: 0, y: 0)] = const Cell(
        char: 'X',
        fg: Color.white, // bright white (15) = 0xFFFFFF
        bg: Color.brightRed, // bright red (9) = 0xFF0000
      );

      Frame(area, buffer, 0).dimBackdrop(factor: 0.5);

      final cell = buffer[(x: 0, y: 0)];
      // ANSI colors converted to RGB then dimmed
      expect(cell.fg, equals(const Color.rgb(0x808080))); // white -> gray
      expect(cell.bg, equals(const Color.rgb(0x800000))); // brightRed -> dark red
    });

    test('dims reset fg as gray, reset bg as black', () {
      final area = Rect.create(x: 0, y: 0, width: 1, height: 1);
      final buffer = Buffer.empty(area);

      // fg and bg default to Color.reset
      buffer[(x: 0, y: 0)] = const Cell(char: 'X');

      Frame(area, buffer, 0).dimBackdrop(factor: 0.5);

      final cell = buffer[(x: 0, y: 0)];
      // fg reset (0xc0c0c0) dimmed by 0.5 = 0x606060
      expect(cell.fg, equals(const Color.rgb(0x606060)));
      // bg reset (0x000000) dimmed stays black
      expect(cell.bg, equals(const Color.rgb(0x000000)));
    });
  });
}
