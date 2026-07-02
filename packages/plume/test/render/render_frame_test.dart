import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  group('renderFrame', () {
    test('runs layout, place, and paint in one call (the README example)', () {
      final tree = Container<String>(
        border: 'grey',
        child: Column<String>(
          children: [
            Text<String>([const TextRun('Hello, Plume', 'title')]),
            Text<String>([const TextRun('layout without a solver', 'body')]),
          ],
        ),
      );
      final surface = RecordingSurface<String>();
      renderFrame(tree, const Rect(0, 0, 27, 4), surface);
      expect(surface.intents.map((intent) => '$intent').toList(), [
        'drawBorder(Rect(0, 0, 27, 4), grey)',
        'drawText(1, 1, "Hello, Plume", title)',
        'drawText(1, 2, "layout without a solver", body)',
      ]);
    });

    test('places the tree at the frame origin', () {
      final box = SizedBox<String>(width: 2, height: 1);
      renderFrame(box, const Rect(3, 2, 5, 4), RecordingSurface<String>());
      expect(box.rect, const Rect(3, 2, 5, 4));
    });

    test('keeps paint inside the frame', () {
      // A child taller than the frame is clipped by the root's own rect.
      final tree = Column<String>(
        children: [
          Text<String>([const TextRun('a\nb\nc\nd', 'x')]),
        ],
      );
      final surface = RecordingSurface<String>();
      renderFrame(tree, const Rect(0, 0, 1, 2), surface);
      expect(surface.intents.map((intent) => '$intent').toList(), [
        'drawText(0, 0, "a", x)',
        'drawText(0, 1, "b", x)',
      ]);
    });
  });
}
