import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

void main() {
  group('Viewport view builds a plume Viewport node', () {
    test('threads scrollOffset, child, and onMeasure straight through', () {
      void onMeasure(plume.ViewportMetrics metrics, Surface surface) {}

      final node = Viewport(scrollOffset: 5, onMeasure: onMeasure, child: const Text('x')).build();

      expect(node, isA<plume.Viewport<PaintToken>>());
      final viewport = node as plume.Viewport<PaintToken>;
      expect(viewport.scrollOffset, 5);
      expect(viewport.onMeasure, same(onMeasure));
      expect(viewport.child, isA<plume.Text<PaintToken>>());
    });

    test('a null onMeasure is a no-op, matching plume default', () {
      final node = const Viewport(scrollOffset: 0, child: Text('x')).build() as plume.Viewport<PaintToken>;

      expect(node.onMeasure, isNull);
    });

    test('carries clipsHits as declared by the underlying plume node', () {
      final node = const Viewport(scrollOffset: 0, child: Text('x')).build();

      expect(node.clipsHits, isTrue);
    });
  });

  group('Viewport view painted into a Frame', () {
    Frame frame(int w, int h) {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));
      return Frame(buffer.area, buffer, 0);
    }

    /// Three stacked, individually tagged rows — 'a', 'b', 'c' — each 3 rows
    /// tall, [w] wide, for a 9-row content total.
    View taggedRows(int w) => Column(
      children: [
        Tagged('a', SizedBox(width: w, height: 3)),
        Tagged('b', SizedBox(width: w, height: 3)),
        Tagged('c', SizedBox(width: w, height: 3)),
      ],
    );

    test('windows a shorter view onto a taller composed region', () {
      final f = frame(6, 4)..render(Viewport(scrollOffset: 0, child: taggedRows(6)));

      expect(f.hits.hitId(0, 0), 'a');
      expect(f.hits.hitId(0, 3), 'b', reason: "b's first row is the window's last row");
      expect(f.hits.rectOf('c'), isNull, reason: 'c is scrolled below the 4-row window');
    });

    test('scrolling changes which row the same point resolves to', () {
      final f = frame(6, 4)..render(Viewport(scrollOffset: 3, child: taggedRows(6)));

      expect(f.hits.hitId(0, 0), 'b', reason: 'the window now starts at content row 3');
      expect(f.hits.rectOf('a'), isNull, reason: 'a has scrolled entirely above the window');
    });

    test('onMeasure reports viewport and content extents through the bridge', () {
      plume.ViewportMetrics? metrics;
      frame(6, 4).render(Viewport(scrollOffset: 0, onMeasure: (m, _) => metrics = m, child: taggedRows(6)));

      expect(metrics, isNotNull);
      expect(metrics!.viewportRows, 4);
      expect(metrics!.contentRows, 9);
    });

    test('onMeasure reports each descendant as a one-element IdTag chain through the bridge', () {
      plume.ViewportMetrics? metrics;
      frame(6, 4).render(Viewport(scrollOffset: 0, onMeasure: (m, _) => metrics = m, child: taggedRows(6)));

      expect(metrics!.entries.map((e) => e.chain).toList(), [
        [IdTag('a')],
        [IdTag('b')],
        [IdTag('c')],
      ]);
    });
  });
}
