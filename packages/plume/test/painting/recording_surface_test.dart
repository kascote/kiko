import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  group('RecordingSurface', () {
    test('records draw calls in order as intents', () {
      final surface = RecordingSurface<String>()
        ..drawText(1, 2, 'hi', 'red')
        ..fillRect(const Rect(0, 0, 3, 3), 'blue')
        ..drawBorder(const Rect(0, 0, 5, 5), 'green');

      expect(surface.intents, const [
        TextIntent<String>(1, 2, 'hi', 'red'),
        FillIntent<String>(Rect(0, 0, 3, 3), 'blue'),
        BorderIntent<String>(Rect(0, 0, 5, 5), 'green'),
      ]);
    });

    test('intents render readably for goldens', () {
      final surface = RecordingSurface<String>()
        ..drawText(1, 2, 'hi', 'red')
        ..fillRect(const Rect(0, 0, 3, 3), 'blue')
        ..drawBorder(const Rect(0, 0, 5, 5), 'green');

      expect(surface.intents.map((i) => i.toString()).toList(), [
        'drawText(1, 2, "hi", red)',
        'fillRect(Rect(0, 0, 3, 3), blue)',
        'drawBorder(Rect(0, 0, 5, 5), green)',
      ]);
    });
  });
}
