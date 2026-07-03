import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

Buffer _buf(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

const _ctx = plume.LayoutContext(measurer: plume.MonospaceMeasurer());

/// A kiko widget that records the area it was handed and fills it with [fill].
class _FakeWidget implements Widget {
  _FakeWidget(this.fill);

  final String fill;
  Rect? handedArea;

  @override
  void render(Rect area, Frame frame) {
    handedArea = area;
    for (var y = area.top; y < area.bottom; y++) {
      for (var x = area.left; x < area.right; x++) {
        frame.buffer.setCellAtPos(x: x, y: y, char: fill);
      }
    }
  }
}

void main() {
  group('LegacyLeaf', () {
    group('layout', () {
      test('takes its requested size under loose constraints', () {
        final leaf = LegacyLeaf(_FakeWidget('x'), width: 4, height: 2);
        final size = leaf.layout(plume.BoxConstraints.loose(const plume.Size(10, 10)), _ctx);
        expect(size, const plume.Size(4, 2));
      });

      test('clamps to tight constraints so an Expanded can override it', () {
        final leaf = LegacyLeaf(_FakeWidget('x'), width: 4, height: 2);
        final size = leaf.layout(plume.BoxConstraints.tight(const plume.Size(7, 3)), _ctx);
        expect(size, const plume.Size(7, 3));
      });
    });

    group('paint', () {
      test('renders the wrapped widget into the buffer', () {
        final b = _buf(3, 2);
        // Laid out tight to the whole frame, the leaf fills the buffer.
        Frame(b.area, b, 0).renderNode(LegacyLeaf(_FakeWidget('#'), width: 3, height: 2));
        expect(b[(x: 0, y: 0)].symbol, '#');
        expect(b[(x: 2, y: 1)].symbol, '#');
      });

      test('hands the widget the rect it was placed at', () {
        final b = _buf(6, 4);
        final widget = _FakeWidget('#');
        // Center a 2×1 leaf in a 6×4 frame: it lands at (2, 1).
        Frame(b.area, b, 0).renderNode(
          plume.Center<PaintToken>(child: LegacyLeaf(widget, width: 2, height: 1)),
        );
        expect(widget.handedArea, Rect.create(x: 2, y: 1, width: 2, height: 1));
      });

      test('draws only inside its own box, leaving the rest untouched', () {
        final b = _buf(6, 3);
        Frame(b.area, b, 0).renderNode(
          plume.Center<PaintToken>(child: LegacyLeaf(_FakeWidget('#'), width: 2, height: 1)),
        );
        // Inside the centered 2×1 box at (2, 1).
        expect(b[(x: 2, y: 1)].symbol, '#');
        expect(b[(x: 3, y: 1)].symbol, '#');
        // Outside it stays blank.
        expect(b[(x: 0, y: 0)].symbol, ' ');
        expect(b[(x: 5, y: 2)].symbol, ' ');
      });

      test('is a no-op when painted into a non-buffer surface', () {
        final widget = _FakeWidget('#');
        final leaf = LegacyLeaf(widget, width: 2, height: 1)
          ..layout(plume.BoxConstraints.tight(const plume.Size(2, 1)), _ctx)
          ..place(plume.Offset.zero);
        final recorder = plume.RecordingSurface<PaintToken>();
        expect(() => leaf.paint(recorder), returnsNormally);
        // The widget never ran, so it recorded no area and drew nothing.
        expect(widget.handedArea, isNull);
        expect(recorder.intents, isEmpty);
      });
    });
  });
}
