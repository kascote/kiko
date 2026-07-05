import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

Buffer _buf(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

/// A paint token carrying just [style].
PaintToken _tok([Style style = const Style()]) => PaintToken(style);

/// A single text run carrying [style], the leaf of the smallest possible tree.
plume.Text<PaintToken> _text(String s, [Style style = const Style()]) =>
    plume.Text<PaintToken>([plume.TextRun(s, _tok(style))]);

const BorderSet _plain = (
  topLeft: '┌',
  topRight: '┐',
  bottomLeft: '└',
  bottomRight: '┘',
  left: '│',
  right: '│',
  top: '─',
  bottom: '─',
);

void main() {
  group('Frame.renderNode', () {
    test('paints a text leaf at the frame origin', () {
      final b = _buf(10, 1);
      Frame(b.area, b, 0).renderNode(_text('hi'));
      expect(b[(x: 0, y: 0)].symbol, 'h');
      expect(b[(x: 1, y: 0)].symbol, 'i');
    });

    test('redeems the carried style onto painted cells', () {
      final b = _buf(5, 1);
      Frame(b.area, b, 0).renderNode(_text('ok', const Style(fg: Color.green, bg: Color.red)));
      final c = b[(x: 0, y: 0)];
      expect(c.fg, Color.green);
      expect(c.bg, Color.red);
    });

    test('lays the tree out tight to the whole frame area', () {
      final b = _buf(4, 3);
      // A background container with no fixed size takes the tight constraints
      // handed by the frame, so its fill covers every cell — including the
      // far corner, well away from the child text.
      Frame(b.area, b, 0).renderNode(
        plume.Container<PaintToken>(
          background: _tok(const Style(bg: Color.blue)),
          child: _text('x'),
        ),
      );
      expect(b[(x: 3, y: 2)].bg, Color.blue);
    });

    test('decodes a border token into box-drawing glyphs', () {
      final b = _buf(4, 3);
      Frame(b.area, b, 0).renderNode(
        plume.Container<PaintToken>(
          border: const PaintToken(Style(), border: _plain),
          child: plume.SizedBox<PaintToken>(),
        ),
      );
      expect(b[(x: 0, y: 0)].symbol, '┌');
      expect(b[(x: 3, y: 0)].symbol, '┐');
      expect(b[(x: 0, y: 2)].symbol, '└');
      expect(b[(x: 3, y: 2)].symbol, '┘');
    });

    test('places the tree at a non-zero frame area origin', () {
      final b = _buf(6, 4);
      // A frame over only the inner region of the buffer: the tree is laid out
      // and placed there, not at the buffer's own origin.
      Frame(Rect.create(x: 2, y: 1, width: 3, height: 2), b, 0).renderNode(_text('ab'));
      expect(b[(x: 2, y: 1)].symbol, 'a');
      expect(b[(x: 3, y: 1)].symbol, 'b');
      // Cells before the origin are untouched.
      expect(b[(x: 0, y: 0)].symbol, ' ');
    });

    test('measures wide glyphs with termunicode so layout accounts for them', () {
      final b = _buf(5, 1);
      // A crab is two cells wide; the row places the next child after it. Only
      // the injected termunicode measurer knows that — a monospace measurer
      // would size the crab as one cell and put 'b' at column 1.
      Frame(b.area, b, 0).renderNode(
        plume.Row<PaintToken>(children: [_text('🦀'), _text('b')]),
      );
      expect(b[(x: 0, y: 0)].symbol, '🦀');
      expect(b[(x: 1, y: 0)].skip, isTrue);
      expect(b[(x: 2, y: 0)].symbol, 'b');
    });

    test('honors a cjk-configured measurer passed in', () {
      // '│' is ambiguous width: one cell normally, two under a cjk locale.
      // Passing the cjk measurer widens it in layout, pushing 'b' one column
      // right of where the default measurer would place it.
      final b = _buf(5, 1);
      Frame(b.area, b, 0).renderNode(
        plume.Row<PaintToken>(children: [_text('│'), _text('b')]),
        measurer: const TermUnicodeMeasurer(cjk: true),
      );
      expect(b[(x: 2, y: 0)].symbol, 'b');
    });
  });

  group('Frame.render', () {
    test('inflates a view and paints it — the public entry', () {
      final b = _buf(10, 1);
      Frame(b.area, b, 0).render(Line('hi'));
      expect(b[(x: 0, y: 0)].symbol, 'h');
      expect(b[(x: 1, y: 0)].symbol, 'i');
    });

    test('forwards a cjk-configured measurer to layout', () {
      // '│' is ambiguous width; the cjk measurer widens it, pushing 'b' right.
      final b = _buf(5, 1);
      Frame(b.area, b, 0).render(
        const Row(children: <View>[Text('│'), Text('b')]),
        measurer: const TermUnicodeMeasurer(cjk: true),
      );
      expect(b[(x: 2, y: 0)].symbol, 'b');
    });
  });
}
