import 'dart:math';

import 'package:characters/characters.dart';
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

    group('controls and lone zero-width clusters', () {
      /// The cell symbols of row 0 of [b], one string per cell.
      List<String> row(Buffer b) => [for (var x = 0; x < b.area.width; x++) b[(x: x, y: 0)].symbol];

      /// Whether [symbol] holds a C0 control, DEL or a C1 control.
      bool holdsControl(String symbol) => symbol.runes.any((cp) => cp < 0x20 || (cp >= 0x7f && cp < 0xa0));

      test('drops a tab and paints the rest in place', () {
        final b = _buf(12, 1);
        BufferSurface(b).drawText(0, 0, 'before\tafter', _tok());
        expect(row(b), ['b', 'e', 'f', 'o', 'r', 'e', 'a', 'f', 't', 'e', 'r', ' ']);
        expect(row(b).any(holdsControl), isFalse);
      });

      test('drops an escape and paints the sequence bytes as text', () {
        final b = _buf(5, 1);
        BufferSurface(b).drawText(0, 0, 'x\x1b[2J', _tok());
        expect(row(b), ['x', '[', '2', 'J', ' ']);
      });

      test('drops NUL, DEL, a C1 control and CR LF', () {
        for (final run in ['\x00', '\x7f', '\u0085', '\r\n']) {
          final b = _buf(3, 1);
          BufferSurface(b).drawText(1, 0, run, _tok());
          expect(row(b), [' ', ' ', ' '], reason: 'run ${run.runes}');
        }
        final b = _buf(3, 1);
        BufferSurface(b).drawText(0, 0, 'a\r\nb', _tok());
        expect(row(b), ['a', 'b', ' ']);
      });

      test('a control at the start of a run leaves the cell to its left alone', () {
        final b = _buf(4, 1);
        BufferSurface(b)
          ..drawText(0, 0, 'ab', _tok())
          ..drawText(1, 0, '\tX', _tok());
        expect(row(b), ['a', 'X', ' ', ' ']);
      });

      test('a combining mark paints as part of its glyph', () {
        final b = _buf(3, 1);
        BufferSurface(b).drawText(0, 0, 'e\u0301x', _tok());
        expect(row(b), ['e\u0301', 'x', ' ']);
      });

      test('a ZWJ after a glyph stays in the cluster of that glyph', () {
        final b = _buf(3, 1);
        BufferSurface(b).drawText(0, 0, 'a\u200Db', _tok());
        expect(row(b), ['a\u200D', 'b', ' ']);
      });

      test('a lone format character paints nothing and stays out of every cell', () {
        // Each of these stands in a cluster of its own between two letters,
        // measures zero, and draws nothing: it is dropped, not appended.
        const lone = {
          'zero-width space': '\u200B',
          'left-to-right mark': '\u200E',
          'right-to-left override': '\u202E',
          'word joiner': '\u2060',
          'right-to-left isolate': '\u2067',
          'byte order mark': '\uFEFF',
          'Arabic letter mark': '\u061C',
        };
        for (final entry in lone.entries) {
          final b = _buf(3, 1);
          BufferSurface(b).drawText(0, 0, 'a${entry.value}b', _tok());
          expect(row(b), ['a', 'b', ' '], reason: entry.key);
        }
      });

      test('an emoji ZWJ sequence still paints as one glyph', () {
        final b = _buf(4, 1);
        BufferSurface(b).drawText(0, 0, '\u{1F468}\u200D\u{1F469}', _tok());
        expect(b[(x: 0, y: 0)].symbol, '\u{1F468}\u200D\u{1F469}');
        expect(b[(x: 1, y: 0)].skip, isTrue);
        expect(b[(x: 2, y: 0)].symbol, ' ');
      });

      test('a combining mark at the start of a run does not touch the cell to its left', () {
        final b = _buf(4, 1);
        BufferSurface(b)
          ..drawText(0, 0, 'ab', _tok())
          ..drawText(1, 0, '\u0301X', _tok());
        expect(row(b), ['a', 'X', ' ', ' ']);
      });

      test('a control ends the glyph: a mark after it is dropped, not folded', () {
        final b = _buf(3, 1);
        BufferSurface(b).drawText(0, 0, 'e\t\u0301x', _tok());
        expect(row(b), ['e', 'x', ' ']);
      });

      test('a variation selector after a control cannot widen the glyph before it', () {
        // Layout measured the lone selector as zero; folding it into 'a'
        // would make that cell two wide and put paint one column past layout.
        final b = _buf(4, 1);
        BufferSurface(b).drawText(0, 0, 'a\t\uFE0Fb', _tok());
        expect(row(b), ['a', 'b', ' ', ' ']);
        expect(b[(x: 1, y: 0)].skip, isFalse);
      });

      test('every C0, DEL and C1 code point is dropped; the printable neighbors are not', () {
        final controls = [
          for (var cp = 0x00; cp < 0x20; cp++) cp,
          for (var cp = 0x7f; cp < 0xa0; cp++) cp,
        ];
        for (final cp in controls) {
          final b = _buf(3, 1);
          BufferSurface(b).drawText(0, 0, 'a${String.fromCharCode(cp)}b', _tok());
          expect(row(b), ['a', 'b', ' '], reason: 'U+${cp.toRadixString(16)}');
        }
        // The predicate's four boundaries: space and NBSP paint a cell each.
        for (final cp in [0x20, 0xa0]) {
          final b = _buf(4, 1);
          BufferSurface(b).drawText(0, 0, 'a${String.fromCharCode(cp)}b', _tok());
          expect(row(b), ['a', String.fromCharCode(cp), 'b', ' '], reason: 'U+${cp.toRadixString(16)}');
        }
      });

      test('a mark after a glyph dropped at the right edge is dropped too', () {
        final b = _buf(2, 1);
        // The crab straddles the right edge and is dropped; the tab keeps the
        // mark out of the crab's cluster, so it stands alone with no glyph.
        BufferSurface(b).drawText(0, 0, 'a\u{1F980}\t\u0301', _tok());
        expect(row(b), ['a', ' ']);
      });

      test('a seeded random run leaves one cluster per cell, no control, and exactly its measured width', () {
        final rng = Random(466);
        const pool = [
          'a', 'Z', ' ', '\u{1F980}', '\u{1F468}\u200D\u{1F469}', '\u2602\uFE0F', // glyphs
          '\u0301', '\u200D', '\uFE0F', // zero-width, glyph-bound
          '\u200B', '\u200F', '\u202E', '\uFEFF', // zero-width, always alone
          '\t', '\x1b', '\x00', '\x7f', '\u0085', '\r\n', // controls
        ];
        const width = 24;
        for (var iter = 0; iter < 300; iter++) {
          final run = [for (var i = 0, n = rng.nextInt(8); i < n; i++) pool[rng.nextInt(pool.length)]].join();
          final b = _buf(width, 1);
          BufferSurface(b).drawText(0, 0, run, _tok());

          final symbols = row(b);
          expect(symbols.any(holdsControl), isFalse, reason: 'run ${run.runes}');
          for (final symbol in symbols) {
            expect(symbol.characters.length, 1, reason: 'run ${run.runes} symbol ${symbol.runes}');
          }

          // Layout and paint agree: the run covers exactly its measured width,
          // and every cell past it is untouched.
          final measured = b.measurer.widthOf(run);
          for (var x = measured; x < width; x++) {
            expect(b[(x: x, y: 0)].symbol, ' ', reason: 'run ${run.runes} at $x');
            expect(b[(x: x, y: 0)].skip, isFalse, reason: 'run ${run.runes} at $x');
          }
          for (var x = 0; x < measured; x++) {
            final cell = b[(x: x, y: 0)];
            expect(cell.skip || cell.symbol != ' ' || run.contains(' '), isTrue, reason: 'run ${run.runes} at $x');
          }

          // The width sidecar still matches the measurer over every symbol.
          for (var x = 0; x < width; x++) {
            final cell = b[(x: x, y: 0)];
            expect(b.debugWidths[x], b.measurer.widthOf(cell.symbol), reason: 'run ${run.runes} at $x');
          }
        }
      });

      test('every lone zero-width format code point is dropped; its visible neighbors are not', () {
        // The ranges segmentation breaks on both sides of and termunicode
        // measures as zero: ZWSP, the bidi marks, embeddings, overrides and
        // isolates, the word joiner and invisible operators, BOM, ALM, MVS.
        final lone = [
          0x200B,
          0x200E,
          0x200F,
          for (var cp = 0x202A; cp <= 0x202E; cp++) cp,
          for (var cp = 0x2060; cp <= 0x2064; cp++) cp,
          for (var cp = 0x2066; cp <= 0x2069; cp++) cp,
          0xFEFF,
          0x061C,
          0x180E,
        ];
        for (final cp in lone) {
          final b = _buf(3, 1);
          final c = String.fromCharCode(cp);
          expect('a${c}b'.characters.length, 3, reason: 'U+${cp.toRadixString(16)} must stand alone');
          BufferSurface(b).drawText(0, 0, 'a${c}b', _tok());
          expect(row(b), ['a', 'b', ' '], reason: 'U+${cp.toRadixString(16)}');
        }
        // Visible neighbors of those ranges paint a cell: hair space, hyphen,
        // the line and paragraph separators, and NBSP.
        for (final cp in [0x200A, 0x2010, 0x2028, 0x2029, 0x00A0]) {
          final b = _buf(4, 1);
          final c = String.fromCharCode(cp);
          BufferSurface(b).drawText(0, 0, 'a${c}b', _tok());
          expect(row(b), ['a', c, 'b', ' '], reason: 'U+${cp.toRadixString(16)}');
        }
      });

      test('ZWNJ and ZWJ join the glyph before them and paint inside its cluster', () {
        for (final c in ['\u200C', '\u200D']) {
          final b = _buf(3, 1);
          BufferSurface(b).drawText(0, 0, 'a${c}b', _tok());
          expect(row(b), ['a$c', 'b', ' '], reason: c.runes.toString());
          expect(b[(x: 0, y: 0)].symbol.characters.length, 1);
        }
      });

      test('a lone format character at the start of a run leaves the cell to its left alone', () {
        final b = _buf(4, 1);
        BufferSurface(b)
          ..drawText(0, 0, 'ab', _tok())
          ..drawText(1, 0, '\u200BX', _tok());
        expect(row(b), ['a', 'X', ' ', ' ']);
      });

      test('dropping a zero-width cluster does not restyle the glyph before it', () {
        // The old fold re-applied the cluster's style onto the target cell.
        final b = _buf(3, 1);
        BufferSurface(b)
          ..drawText(0, 0, 'a', _tok(const Style(fg: Color.red)))
          ..drawText(1, 0, '\u200B\u0301b', _tok(const Style(fg: Color.blue)));
        expect(row(b), ['a', 'b', ' ']);
        expect(b[(x: 0, y: 0)].fg, Color.red);
        expect(b[(x: 1, y: 0)].fg, Color.blue);
      });

      test('a format character and an orphan mark after a wide glyph leave its skip cell alone', () {
        final b = _buf(4, 1);
        BufferSurface(b).drawText(0, 0, '\u{1F980}\u200B\u0301x', _tok());
        expect(b[(x: 0, y: 0)].symbol, '\u{1F980}');
        expect(b[(x: 1, y: 0)].skip, isTrue);
        expect(b[(x: 2, y: 0)].symbol, 'x');
      });

      test('a format character between two halves of a clipped run changes nothing', () {
        final b = _buf(8, 1);
        BufferSurface(b)
          ..pushNode(const plume.Rect(2, 0, 4, 1))
          ..drawText(0, 0, 'ab\u200Bcd\uFEFFef', _tok())
          ..popNode();
        expect(row(b), [' ', ' ', 'c', 'd', 'e', 'f', ' ', ' ']);
      });

      test('every non-blank cell holds exactly one grapheme cluster after a mixed run', () {
        final b = _buf(12, 1);
        BufferSurface(b).drawText(0, 0, 'e\u0301\u200B\u{1F468}\u200D\u{1F469}\u202E\t\u2602\uFE0F\uFEFFz', _tok());
        expect(row(b).sublist(0, 6), ['e\u0301', '\u{1F468}\u200D\u{1F469}', ' ', '\u2602\uFE0F', ' ', 'z']);
        expect(b[(x: 2, y: 0)].skip, isTrue);
        expect(b[(x: 4, y: 0)].skip, isTrue);
        for (final symbol in row(b)) {
          expect(symbol.characters.length, 1, reason: symbol.runes.toString());
        }
      });

      test('a mark after a cluster the clip trimmed away is dropped, not folded', () {
        final b = _buf(6, 1);
        BufferSurface(b)
          ..pushNode(const plume.Rect(2, 0, 4, 1))
          ..drawText(0, 0, 'ab\u0301cd', _tok())
          ..popNode();
        // 'b' fell left of the clip, so its mark has no glyph in this run.
        expect(row(b), [' ', ' ', 'c', 'd', ' ', ' ']);
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
          ..pushNode(const plume.Rect(0, 0, 3, 3))
          ..drawBorder(const plume.Rect(0, 0, 5, 5), const PaintToken(Style(), border: _plain))
          ..popNode();
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
          ..pushNode(const plume.Rect(0, 0, 3, 3))
          ..fillRect(const plume.Rect(5, 0, 3, 3), _tok(const Style(bg: Color.blue)))
          ..popNode();
        expect(b[(x: 5, y: 0)].bg, Color.reset);
      });

      test('trims a fill to the clip', () {
        final b = _buf(10, 1);
        BufferSurface(b)
          ..pushNode(const plume.Rect(0, 0, 4, 1))
          ..fillRect(const plume.Rect(2, 0, 6, 1), _tok(const Style(bg: Color.blue)))
          ..popNode();
        expect(b[(x: 3, y: 0)].bg, Color.blue); // inside the clip
        expect(b[(x: 4, y: 0)].bg, Color.reset); // past the clip's right edge
      });

      test('trims a text run that starts left of the clip', () {
        final b = _buf(10, 1);
        BufferSurface(b)
          ..pushNode(const plume.Rect(3, 0, 4, 1))
          ..drawText(0, 0, 'abcdefgh', _tok())
          ..popNode();
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
          ..pushNode(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(3, 2));
        expect(s.cursor, const Position(3, 2));
      });

      test('drops a position outside the active clip', () {
        // The caret row of a field half-scrolled off a Viewport: a cursor IS
        // still claimed, but at a cell the clip has cut away.
        final s = BufferSurface(_buf(10, 3))
          ..pushNode(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(5, 1));
        expect(s.cursor, isNull);
      });

      test('a dropped claim does not erase an earlier valid one', () {
        // The clip-gate must not reintroduce the erase-by-null bug 0168 fixed
        // — a claim outside the clip is discarded, not written over the slot.
        final s = BufferSurface(_buf(10, 3))
          ..placeCursor(const Position(1, 1))
          ..pushNode(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(9, 1));
        expect(s.cursor, const Position(1, 1));
      });

      test('a position on the clip boundary is dropped, right and bottom exclusive', () {
        final s = BufferSurface(_buf(10, 3))
          ..pushNode(const plume.Rect(0, 0, 4, 3))
          ..placeCursor(const Position(4, 0));
        expect(s.cursor, isNull);
      });
    });
  });
}
