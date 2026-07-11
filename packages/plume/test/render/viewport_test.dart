import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/golden.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// A leaf that fills its own rect, so its paint records as a [FillIntent].
class _Fill<T> extends RenderNode<T> {
  _Fill(this.token, this.w, this.h);

  final T token;
  final int w;
  final int h;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.constrain(Size(w, h));

  @override
  void paintSelf(Surface<T> surface) => surface.fillRect(rect, token);
}

/// Three stacked, individually tagged rows — 'a', 'b', 'c' — each 3 rows
/// tall, for a 9-row content total.
Column<String> _taggedRows() => Column<String>(
  children: [
    _Fill<String>('a', 6, 3)..tag = 'a',
    _Fill<String>('b', 6, 3)..tag = 'b',
    _Fill<String>('c', 6, 3)..tag = 'c',
  ],
);

/// Lays [viewport] out tightly at [size] and fixes its absolute rects.
Viewport<String> _layout(Viewport<String> viewport, Size size) => viewport
  ..layout(BoxConstraints.tight(size), _ctx)
  ..place(Offset.zero);

/// Lays [viewport] out tightly at [size], places, and paints it.
RecordingSurface<String> _paint(Viewport<String> viewport, Size size) {
  final surface = RecordingSurface<String>();
  _layout(viewport, size).paint(surface);
  return surface;
}

void main() {
  group('Viewport layout', () {
    test('lays the child out with the main axis unbounded and the cross axis tight', () {
      final viewport = Viewport<String>(scrollOffset: 0, child: SizedBox<String>(width: 999, height: 30))
        ..layout(BoxConstraints.tight(const Size(10, 4)), _ctx);
      expect(viewport.size, const Size(10, 4), reason: 'sizes to the box it was given, not the child');
      expect(viewport.child.size, const Size(10, 30), reason: 'cross tight to 10, main axis reports its full 30');
    });

    test('declares clipsHits, unlike an ordinary node', () {
      final viewport = Viewport<String>(scrollOffset: 0, child: SizedBox<String>());
      expect(viewport.clipsHits, isTrue);
      expect(SizedBox<String>().clipsHits, isFalse);
    });
  });

  group('Viewport scrolling and paint clipping', () {
    test('places the child at Offset(0, -scrollOffset)', () {
      final content = _Fill<String>('c', 6, 12);
      _layout(Viewport<String>(scrollOffset: 5, child: content), const Size(6, 4));
      expect(content.rect, const Rect(0, -5, 6, 12));
    });

    test('draws the scrolled-past-the-top content clipped to the window', () {
      final content = _Fill<String>('c', 6, 12);
      final surface = _paint(Viewport<String>(scrollOffset: 5, child: content), const Size(6, 4));
      expect(surface.intents.map((i) => '$i').toList(), [
        'fillRect(Rect(0, -5, 6, 12), c, clip: Rect(0, 0, 6, 4))',
      ]);
      noOverflow(surface.intents, const Rect(0, 0, 6, 4));
    });

    test('content scrolled entirely past the window paints nothing', () {
      final content = _Fill<String>('c', 6, 4);
      final surface = _paint(Viewport<String>(scrollOffset: 10, child: content), const Size(6, 4));
      expect(surface.intents, isEmpty);
    });

    test('a zero scrollOffset paints the content at the top, unshifted', () {
      // The content (2 rows) fits entirely inside the window (4 rows), so its
      // own pushed rect is already contained by the clip — no clip carried.
      final content = _Fill<String>('c', 6, 2);
      final surface = _paint(Viewport<String>(scrollOffset: 0, child: content), const Size(6, 4));
      expect(surface.intents.map((i) => '$i').toList(), ['fillRect(Rect(0, 0, 6, 2), c)']);
    });
  });

  group('Viewport hit/tag pruning at its own edges', () {
    test('a point above or below the viewport rect returns null', () {
      final viewport = _layout(Viewport<String>(scrollOffset: 0, child: _taggedRows()), const Size(6, 4));
      expect(viewport.hitTest(const Offset(0, -1)), isNull);
      expect(viewport.hitTest(const Offset(0, 4)), isNull, reason: 'one past the bottom of a 4-row window');
    });

    test('a partially visible row is hit only in its visible rows', () {
      // Rows are 'a' (content 0-2), 'b' (3-5), 'c' (6-8); a 4-row window at
      // offset 0 shows content rows 0-3, so only 'b's first row (y=3) is
      // reachable — its remaining rows fall outside the viewport's own rect.
      final viewport = _layout(Viewport<String>(scrollOffset: 0, child: _taggedRows()), const Size(6, 4));
      expect(viewport.tagAt(const Offset(0, 3)), 'b');
      expect(viewport.hitTest(const Offset(0, 4)), isNull, reason: "b's second row is outside the window");
    });

    test('tagAt resolves the innermost tag inside the window', () {
      final viewport = _layout(Viewport<String>(scrollOffset: 0, child: _taggedRows()), const Size(6, 4));
      expect(viewport.tagAt(Offset.zero), 'a');
      expect(viewport.tagAt(const Offset(0, 3)), 'b');
    });

    test('scrolling changes which tag a point resolves to', () {
      final viewport = _layout(Viewport<String>(scrollOffset: 3, child: _taggedRows()), const Size(6, 4));
      // Window now shows content rows 3-6: row 'b' fills it entirely.
      expect(viewport.tagAt(Offset.zero), 'b');
      expect(viewport.tagAt(const Offset(0, 2)), 'b');
    });
  });

  group('Viewport measurement', () {
    test('onMeasure fires with the viewport and content extents', () {
      ViewportMetrics? metrics;
      final viewport = Viewport<String>(scrollOffset: 0, onMeasure: (m) => metrics = m, child: _taggedRows());
      _paint(viewport, const Size(6, 4));
      expect(metrics, isNotNull);
      expect(metrics!.viewportRows, 4);
      expect(metrics!.contentRows, 9);
    });

    test('reports each tagged row as a content-relative range', () {
      ViewportMetrics? metrics;
      final viewport = Viewport<String>(scrollOffset: 0, onMeasure: (m) => metrics = m, child: _taggedRows());
      _paint(viewport, const Size(6, 4));
      expect(metrics!.tagRanges, {
        'a': const ViewportTagRange(0, 3),
        'b': const ViewportTagRange(3, 3),
        'c': const ViewportTagRange(6, 3),
      });
    });

    test('tag ranges do not change as scrollOffset changes', () {
      ViewportMetrics? unscrolled;
      final atTop = Viewport<String>(scrollOffset: 0, onMeasure: (m) => unscrolled = m, child: _taggedRows());
      _paint(atTop, const Size(6, 4));

      ViewportMetrics? scrolled;
      final atFive = Viewport<String>(scrollOffset: 5, onMeasure: (m) => scrolled = m, child: _taggedRows());
      _paint(atFive, const Size(6, 4));

      expect(scrolled!.tagRanges, unscrolled!.tagRanges);
    });

    test('a null onMeasure is a no-op — no walk, no callback', () {
      final viewport = Viewport<String>(scrollOffset: 0, child: _taggedRows());
      expect(() => _paint(viewport, const Size(6, 4)), returnsNormally);
    });
  });
}
