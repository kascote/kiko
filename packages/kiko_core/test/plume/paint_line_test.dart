import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

Buffer _buf(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

/// Dumps every cell's symbol + style as a comparable string, so a parity
/// check reads a clean diff instead of a wall of Cell equality failures.
String _dumpRow(Buffer buffer, int y) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var x = area.left; x < area.right; x++) {
    final cell = buffer[(x: x, y: y)];
    out.write('(${cell.skip ? "skip" : cell.symbol}:${cell.style})');
  }
  return out.toString();
}

void main() {
  group('paintLine', () {
    test('paints a single-span line at the given origin', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hi'), x: 2, y: 1, width: 10);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(2, 1, "hi", ${const PaintToken(Style())})']);
    });

    test('resolves the style chain base then line then span', () {
      final line = Line.fromSpans(
        const <Span>[Span('a', style: Style(fg: Color.red))],
        style: const Style(bg: Color.green),
      );
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, line, x: 0, y: 0, width: 10, base: const Style(addModifier: Modifier.bold));

      final expectedStyle = const Style(
        addModifier: Modifier.bold,
      ).patch(const Style(bg: Color.green)).patch(const Style(fg: Color.red));
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(0, 0, "a", PaintToken($expectedStyle))']);
    });

    test('centers when the line carries center alignment', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hi', alignment: Alignment.center), x: 0, y: 0, width: 10);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(4, 0, "hi", ${const PaintToken(Style())})']);
    });

    test('falls back to the given alignment when the line sets none', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hi'), x: 0, y: 0, width: 10, fallbackAlign: Alignment.right);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(8, 0, "hi", ${const PaintToken(Style())})']);
    });

    test('clips a line wider than the box', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hello'), x: 0, y: 0, width: 3);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(0, 0, "hel", ${const PaintToken(Style())})']);
    });

    test('skipColumns scrolls the line left, dropping fully-hidden spans', () {
      final surface = plume.RecordingSurface<PaintToken>();
      paintLine(surface, Line('hello world'), x: 0, y: 0, width: 5, skipColumns: 6);
      expect(surface.intents.map((i) => '$i').toList(), ['drawText(0, 0, "world", ${const PaintToken(Style())})']);
    });
  });

  group('fillRow', () {
    test('emits a fillRect intent spanning the row', () {
      final surface = plume.RecordingSurface<PaintToken>();
      fillRow(surface, x: 1, y: 2, width: 4, style: const Style(bg: Color.blue));
      const token = PaintToken(Style(bg: Color.blue));
      expect(surface.intents.map((i) => '$i').toList(), ['fillRect(${const plume.Rect(1, 2, 4, 1)}, $token)']);
    });
  });

  group('paintLine / Line.render parity', () {
    // The old buffer-bridge (Line.render into a Frame) and the new plume
    // paint protocol (paintLine into a BufferSurface) must land identical
    // cells while both paths coexist — this is the seam 0092 has to keep
    // faithful before the bridge is retired in 0088.
    //
    // `base` is deliberately not exercised here: it composes as base ▸ line ▸
    // span (lineNode's chain, already covered by text_flatten_test.dart),
    // which has no equivalent in the legacy `Line.render` — there is no
    // legacy call site that composes an outer style *under* a line's own
    // (`patchStyle` composes an outer style *over* it, the opposite order),
    // so there is nothing faithful to assert parity against.
    //
    // `paintLine` alone resolves only glyph-cell style, not the whole-row
    // background fill `Line.render` also does (that is `fillRow`'s job,
    // tested on its own above). A trivial (default) line style makes that
    // fill a no-op, so most cases below use a box wider than the content —
    // exactly to prove the alignment shift — and only the one case with a
    // real line style tightens the box to its content to stay scoped to
    // what `paintLine` promises.
    void expectParity(Line line, {int width = 10, Alignment? fallbackAlign}) {
      final legacyBuffer = _buf(width, 1);
      final area = Rect.create(x: 0, y: 0, width: width, height: 1);
      line.renderWidthAlignment(area, Frame(area, legacyBuffer, 0), fallbackAlign);

      final plumeBuffer = _buf(width, 1);
      paintLine(BufferSurface(plumeBuffer), line, x: 0, y: 0, width: width, fallbackAlign: fallbackAlign);

      expect(_dumpRow(plumeBuffer, 0), _dumpRow(legacyBuffer, 0));
    }

    test('a plain single-span line', () => expectParity(Line('hello')));

    test('a multi-span line with distinct styles', () {
      expectParity(
        Line.fromSpans(const <Span>[
          Span('ab', style: Style(fg: Color.red)),
          Span('cd', style: Style(fg: Color.blue)),
        ]),
      );
    });

    test('a center-aligned line', () => expectParity(Line('hi', alignment: Alignment.center)));

    test('a right-aligned line via fallback', () => expectParity(Line('hi'), fallbackAlign: Alignment.right));

    test('a line wider than its box, clipped', () => expectParity(Line('hello world'), width: 5));

    test('a line carrying its own (non-default) style', () {
      // Tight width: a non-trivial line style would otherwise diverge on the
      // padding columns, which only Line.render's row-fill paints.
      expectParity(Line('hi', style: const Style(bg: Color.green)), width: 2);
    });
  });
}
