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

    group('clip stack', () {
      test('pushClip intersects and popClip restores the previous clip', () {
        final surface = RecordingSurface<String>();
        expect(surface.clipRect, isNull);
        surface.pushClip(const Rect(0, 0, 10, 10));
        expect(surface.clipRect, const Rect(0, 0, 10, 10));
        surface.pushClip(const Rect(5, 5, 10, 10));
        expect(surface.clipRect, const Rect(5, 5, 5, 5));
        surface.popClip();
        expect(surface.clipRect, const Rect(0, 0, 10, 10));
        surface.popClip();
        expect(surface.clipRect, isNull);
      });

      test('a draw fully inside the clip carries no clip annotation', () {
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(0, 0, 10, 10))
          ..fillRect(const Rect(2, 2, 3, 3), 'blue');
        expect(surface.intents, const [FillIntent<String>(Rect(2, 2, 3, 3), 'blue')]);
      });

      test('a draw overflowing the clip carries it', () {
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(0, 0, 4, 4))
          ..fillRect(const Rect(2, 2, 5, 5), 'blue');
        expect(surface.intents, const [FillIntent<String>(Rect(2, 2, 5, 5), 'blue', clip: Rect(0, 0, 4, 4))]);
      });

      test('a draw fully outside the clip is dropped', () {
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(0, 0, 4, 4))
          ..fillRect(const Rect(10, 10, 2, 2), 'blue');
        expect(surface.intents, isEmpty);
      });

      test('a border keeps its original rect and carries the clip', () {
        // Never re-border a shrunken rect: the clip drops outside cells, it does
        // not fabricate an edge at the clip line.
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(0, 0, 4, 4))
          ..drawBorder(const Rect(0, 0, 6, 6), 'green');
        expect(surface.intents, const [BorderIntent<String>(Rect(0, 0, 6, 6), 'green', clip: Rect(0, 0, 4, 4))]);
      });

      test('an empty clip drops every draw', () {
        final surface = RecordingSurface<String>()
          ..pushClip(Rect.zero)
          ..fillRect(const Rect(0, 0, 3, 3), 'blue')
          ..drawBorder(const Rect(0, 0, 3, 3), 'green')
          ..drawText(0, 0, 'hi', 'red');
        expect(surface.intents, isEmpty);
      });
    });

    group('drawText clipping', () {
      test('drops a run on a row outside the clip', () {
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(0, 0, 5, 2))
          ..drawText(0, 3, 'hi', 'red');
        expect(surface.intents, isEmpty);
      });

      test('keeps a run inside the clip with no annotation', () {
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(0, 0, 5, 2))
          ..drawText(1, 1, 'hi', 'red');
        expect(surface.intents, const [TextIntent<String>(1, 1, 'hi', 'red')]);
      });

      test('carries the clip for a run starting left of it', () {
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(2, 0, 5, 2))
          ..drawText(0, 0, 'hello', 'red');
        expect(surface.intents, const [TextIntent<String>(0, 0, 'hello', 'red', clip: Rect(2, 0, 5, 2))]);
      });

      test('drops a run starting at or past the right edge', () {
        final surface = RecordingSurface<String>()
          ..pushClip(const Rect(0, 0, 5, 2))
          ..drawText(5, 0, 'hi', 'red');
        expect(surface.intents, isEmpty);
      });
    });
  });
}
