import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

void main() {
  group('paintLine', () {
    test('paints a single-span line at the given origin', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hi'), x: 2, y: 1, width: 10);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(2, 1, "hi", ${const PaintToken(Style())})']);
    });

    test('resolves the style chain base then line then span', () {
      final line = Line.fromSpans(
        const <Text>[Text('a', style: Style(fg: Color.red))],
        style: const Style(bg: Color.green),
      );
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, line, x: 0, y: 0, width: 10, base: const Style(addModifier: Modifier.bold));

      final expectedStyle = const Style(
        addModifier: Modifier.bold,
      ).patch(const Style(bg: Color.green)).patch(const Style(fg: Color.red));
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(0, 0, "a", PaintToken($expectedStyle))']);
    });

    test('centers when given center alignment', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hi'), x: 0, y: 0, width: 10, align: TextAlign.center);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(4, 0, "hi", ${const PaintToken(Style())})']);
    });

    test('right-aligns when given end alignment', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hi'), x: 0, y: 0, width: 10, align: TextAlign.end);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(8, 0, "hi", ${const PaintToken(Style())})']);
    });

    test('clips a line wider than the box', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hello'), x: 0, y: 0, width: 3);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(0, 0, "hel", ${const PaintToken(Style())})']);
    });

    test('skipColumns scrolls the line left, dropping fully-hidden spans', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hello world'), x: 0, y: 0, width: 5, skipColumns: 6);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(0, 0, "world", ${const PaintToken(Style())})']);
    });
  });

  group('fillRow', () {
    test('emits a fillRect intent spanning the row', () {
      final surface = plume.RecordingSurface<PaintToken>();
      fillRow(surface, x: 1, y: 2, width: 4, style: const Style(bg: Color.blue));
      const token = PaintToken(Style(bg: Color.blue));
      expect(surface.intents.map((i) => '$i').toList(), ['fillRect(${const plume.Rect(1, 2, 4, 1)}, $token)']);
    });
  });
}
