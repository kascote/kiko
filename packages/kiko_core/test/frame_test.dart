import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('ground', () {
    final area = Rect.create(x: 0, y: 0, width: 3, height: 2);

    Iterable<Cell> cellsOf(Buffer buffer) sync* {
      for (var y = area.top; y < area.bottom; y++) {
        for (var x = area.left; x < area.right; x++) {
          yield buffer[(x: x, y: y)];
        }
      }
    }

    test('a full pair grounds every cell, and a second pair replaces it', () {
      final buffer = Buffer.empty(area);
      final frame = Frame(area, buffer, 0)..ground(const Style(fg: Color.rgb(0x111111), bg: Color.rgb(0x222222)));

      for (final cell in cellsOf(buffer)) {
        expect(cell.fg, const Color.rgb(0x111111));
        expect(cell.bg, const Color.rgb(0x222222));
      }

      frame.ground(const Style(fg: Color.rgb(0x333333), bg: Color.rgb(0x444444)));

      for (final cell in cellsOf(buffer)) {
        expect(cell.fg, const Color.rgb(0x333333));
        expect(cell.bg, const Color.rgb(0x444444));
      }
    });

    test('a null bg keeps the bg each cell already holds', () {
      final buffer = Buffer.empty(area);
      Frame(area, buffer, 0)
        ..ground(const Style(fg: Color.rgb(0x111111), bg: Color.rgb(0x222222)))
        // The ground resolver.ground returns under RenderPolicy.ansi16.
        ..ground(const Style(fg: Color.rgb(0x333333)));

      for (final cell in cellsOf(buffer)) {
        expect(cell.fg, const Color.rgb(0x333333));
        expect(cell.bg, const Color.rgb(0x222222));
      }
    });
  });
}
