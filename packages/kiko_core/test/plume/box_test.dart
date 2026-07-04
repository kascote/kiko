import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

/// Renders [node] onto a fresh [width]×[height] buffer and dumps it to text —
/// one line per row, empty cells as spaces, trailing blanks trimmed.
String _render(plume.RenderNode<PaintToken> node, int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  plume.renderFrame(node, plume.Rect(0, 0, width, height), BufferSurface(buffer));

  final out = StringBuffer();
  for (var y = 0; y < height; y++) {
    final row = StringBuffer();
    for (var x = 0; x < width; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

void main() {
  group('box mapping', () {
    test('no border produces a BorderBox with no border token', () {
      final node = box(child: plume.SizedBox<PaintToken>(width: 1, height: 1)) as plume.BorderBox<PaintToken>;
      expect(node.border, isNull);
      expect(node.background, isNull);
    });

    test('a border type becomes one token carrying its glyphs and style', () {
      final node =
          box(
                border: BorderType.plain,
                borderStyle: const Style(fg: Color.red),
                child: plume.SizedBox<PaintToken>(width: 1, height: 1),
              )
              as plume.BorderBox<PaintToken>;

      expect(node.border, PaintToken(const Style(fg: Color.red), border: BorderType.plain.symbols(BorderType.plain)));
    });

    test('a non-empty style becomes the background fill', () {
      final node =
          box(
                background: const Style(bg: Color.blue),
                child: plume.SizedBox<PaintToken>(width: 1, height: 1),
              )
              as plume.BorderBox<PaintToken>;
      expect(node.background, const PaintToken(Style(bg: Color.blue)));
    });

    test('titles become edge labels at the start of their edge', () {
      final node =
          box(
                topTitles: <Line>[Line('Top')],
                bottomTitles: <Line>[Line('Bot')],
                child: plume.SizedBox<PaintToken>(width: 1, height: 1),
              )
              as plume.BorderBox<PaintToken>;

      expect(node.labels, hasLength(2));
      expect(node.labels[0].side, plume.EdgeSide.top);
      expect(node.labels[0].align, plume.LabelAlign.start);
      expect(node.labels[1].side, plume.EdgeSide.bottom);
      expect(node.labels[1].align, plume.LabelAlign.start);
    });
  });

  group('box rendering', () {
    test('draws a bordered frame with a start-aligned title and body text', () {
      final node = box(
        border: BorderType.plain,
        topTitles: <Line>[Line('Hi')],
        child: Line('body').build(),
      );

      expect(_render(node, 10, 4), '''
┌Hi──────┐
│body    │
│        │
└────────┘
''');
    });
  });
}
