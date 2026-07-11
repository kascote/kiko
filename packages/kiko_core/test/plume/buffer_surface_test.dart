import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

Buffer _buf(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

/// A paint token carrying just [style] — the common case for text and fills.
PaintToken _tok([Style style = const Style()]) => PaintToken(style);

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
  group('BufferSurface', () {
    group('drawText', () {
      test('writes a run starting at the given cell', () {
        final b = _buf(10, 1);
        BufferSurface(b).drawText(2, 0, 'hi', _tok());
        expect(b[(x: 2, y: 0)].symbol, 'h');
        expect(b[(x: 3, y: 0)].symbol, 'i');
      });

      test('redeems the carried style onto each cell', () {
        final b = _buf(5, 1);
        BufferSurface(b).drawText(0, 0, 'ok', _tok(const Style(fg: Color.green, bg: Color.red)));
        final c = b[(x: 0, y: 0)];
        expect(c.fg, Color.green);
        expect(c.bg, Color.red);
      });

      test('clamps a run past the right edge instead of throwing', () {
        final b = _buf(3, 1);
        final s = BufferSurface(b);
        expect(() => s.drawText(1, 0, 'abcdef', _tok()), returnsNormally);
        expect(b[(x: 1, y: 0)].symbol, 'a');
        expect(b[(x: 2, y: 0)].symbol, 'b');
      });

      test('drops a run on a row outside the buffer', () {
        final b = _buf(5, 2);
        expect(() => BufferSurface(b).drawText(0, 5, 'x', _tok()), returnsNormally);
        expect(b[(x: 0, y: 0)].symbol, ' ');
      });

      test('a wide glyph fills two cells, the trailing one skipped', () {
        final b = _buf(4, 1);
        BufferSurface(b).drawText(0, 0, '🦀', _tok());
        expect(b[(x: 0, y: 0)].symbol, '🦀');
        expect(b[(x: 1, y: 0)].skip, isTrue);
      });

      test('a wide glyph that would straddle the right edge is dropped', () {
        final b = _buf(3, 1);
        // A width-2 glyph at x=2 needs column 3, which is off the buffer.
        BufferSurface(b).drawText(2, 0, '🦀', _tok());
        expect(b[(x: 2, y: 0)].symbol, ' ');
      });
    });

    group('fillRect', () {
      test('fills every cell of the rect with the style', () {
        final b = _buf(4, 3);
        BufferSurface(b).fillRect(const plume.Rect(1, 1, 2, 2), _tok(const Style(bg: Color.blue)));
        for (final (x, y) in <(int, int)>[(1, 1), (2, 1), (1, 2), (2, 2)]) {
          expect(b[(x: x, y: y)].bg, Color.blue, reason: 'cell ($x,$y)');
        }
        expect(b[(x: 0, y: 0)].bg, Color.reset);
      });

      test('clamps a rect that spills past the buffer instead of throwing', () {
        final b = _buf(3, 3);
        final s = BufferSurface(b);
        expect(
          () => s.fillRect(const plume.Rect(1, 1, 10, 10), _tok(const Style(bg: Color.blue))),
          returnsNormally,
        );
        expect(b[(x: 2, y: 2)].bg, Color.blue);
      });
    });

    group('drawBorder', () {
      test("draws the token's glyph set around the rect", () {
        final b = _buf(4, 3);
        BufferSurface(b).drawBorder(const plume.Rect(0, 0, 4, 3), const PaintToken(Style(), border: _plain));
        expect(b[(x: 0, y: 0)].symbol, '┌');
        expect(b[(x: 3, y: 0)].symbol, '┐');
        expect(b[(x: 0, y: 2)].symbol, '└');
        expect(b[(x: 3, y: 2)].symbol, '┘');
        expect(b[(x: 1, y: 0)].symbol, '─'); // top edge
        expect(b[(x: 0, y: 1)].symbol, '│'); // left edge
        expect(b[(x: 1, y: 1)].symbol, ' '); // interior untouched
      });

      test('redeems the carried style onto border cells', () {
        final b = _buf(4, 3);
        BufferSurface(b).drawBorder(
          const plume.Rect(0, 0, 4, 3),
          const PaintToken(Style(fg: Color.green), border: _plain),
        );
        expect(b[(x: 0, y: 0)].fg, Color.green);
        expect(b[(x: 1, y: 0)].fg, Color.green);
      });

      test('drops perimeter cells outside the clip', () {
        final b = _buf(6, 5);
        BufferSurface(b)
          ..pushClip(const plume.Rect(0, 0, 3, 3))
          ..drawBorder(const plume.Rect(0, 0, 5, 5), const PaintToken(Style(), border: _plain))
          ..popClip();
        expect(b[(x: 0, y: 0)].symbol, '┌'); // corner inside the clip
        expect(b[(x: 1, y: 0)].symbol, '─'); // top edge inside the clip
        expect(b[(x: 3, y: 0)].symbol, ' '); // past the clip's right edge
        expect(b[(x: 0, y: 3)].symbol, ' '); // below the clip's bottom edge
      });

      test('throws on a token with no glyph set, in every build', () {
        final s = BufferSurface(_buf(4, 3));
        // Never silently paint nothing: layout has already reserved the edge, so
        // a skipped border leaves a one-cell hole around the child.
        expect(
          () => s.drawBorder(const plume.Rect(0, 0, 4, 3), _tok()),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('an empty rect draws nothing and is not an error', () {
        final b = _buf(4, 3);
        final s = BufferSurface(b);
        expect(() => s.drawBorder(plume.Rect.zero, const PaintToken(Style(), border: _plain)), returnsNormally);
        expect(b[(x: 0, y: 0)].symbol, ' ');
      });

      test('clamps a border past the buffer instead of throwing', () {
        final b = _buf(3, 3);
        final s = BufferSurface(b);
        expect(
          () => s.drawBorder(const plume.Rect(0, 0, 10, 10), const PaintToken(Style(), border: _plain)),
          returnsNormally,
        );
        expect(b[(x: 0, y: 0)].symbol, '┌'); // top-left corner still lands
        expect(b[(x: 2, y: 0)].symbol, '─'); // top edge on the buffer
        expect(b[(x: 0, y: 2)].symbol, '│'); // left edge on the buffer
      });
    });

    group('clipping', () {
      test('drops a fill entirely outside the clip', () {
        final b = _buf(10, 3);
        BufferSurface(b)
          ..pushClip(const plume.Rect(0, 0, 3, 3))
          ..fillRect(const plume.Rect(5, 0, 3, 3), _tok(const Style(bg: Color.blue)))
          ..popClip();
        expect(b[(x: 5, y: 0)].bg, Color.reset);
      });

      test('trims a fill to the clip', () {
        final b = _buf(10, 1);
        BufferSurface(b)
          ..pushClip(const plume.Rect(0, 0, 4, 1))
          ..fillRect(const plume.Rect(2, 0, 6, 1), _tok(const Style(bg: Color.blue)))
          ..popClip();
        expect(b[(x: 3, y: 0)].bg, Color.blue); // inside the clip
        expect(b[(x: 4, y: 0)].bg, Color.reset); // past the clip's right edge
      });

      test('trims a text run that starts left of the clip', () {
        final b = _buf(10, 1);
        BufferSurface(b)
          ..pushClip(const plume.Rect(3, 0, 4, 1))
          ..drawText(0, 0, 'abcdefgh', _tok())
          ..popClip();
        expect(b[(x: 2, y: 0)].symbol, ' '); // trimmed: left of the clip
        expect(b[(x: 3, y: 0)].symbol, 'd'); // first visible cell
        expect(b[(x: 6, y: 0)].symbol, 'g'); // last cell inside the clip
        expect(b[(x: 7, y: 0)].symbol, ' '); // past the clip's right edge
      });
    });

    group('placeCursor', () {
      test('records the position when no clip is active', () {
        final s = BufferSurface(_buf(10, 3))..placeCursor(const Position(2, 1));
        expect(s.cursor, const Position(2, 1));
      });

      test('records a position inside the active clip', () {
        final s = BufferSurface(_buf(10, 3))
          ..pushClip(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(3, 2));
        expect(s.cursor, const Position(3, 2));
      });

      test('drops a position outside the active clip', () {
        // The caret row of a field half-scrolled off a Viewport: a cursor IS
        // still claimed, but at a cell the clip has cut away.
        final s = BufferSurface(_buf(10, 3))
          ..pushClip(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(5, 1));
        expect(s.cursor, isNull);
      });

      test('a dropped claim does not erase an earlier valid one', () {
        // The clip-gate must not reintroduce the erase-by-null bug 0168 fixed
        // — a claim outside the clip is discarded, not written over the slot.
        final s = BufferSurface(_buf(10, 3))
          ..placeCursor(const Position(1, 1))
          ..pushClip(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(9, 1));
        expect(s.cursor, const Position(1, 1));
      });

      test('a position on the clip boundary is dropped, right and bottom exclusive', () {
        final s = BufferSurface(_buf(10, 3))
          ..pushClip(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(4, 0));
        expect(s.cursor, isNull);
      });
    });
  });
}
