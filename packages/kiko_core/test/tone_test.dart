import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Tone projections', () {
    const tone = Tone(color: Color.rgb(0x264a5c));

    test('ink is foreground only', () {
      expect(tone.ink.fg, equals(const Color.rgb(0x264a5c)));
      expect(tone.ink.bg, isNull);
    });

    test('wash is background only', () {
      expect(tone.wash.bg, equals(const Color.rgb(0x264a5c)));
      expect(tone.wash.fg, isNull);
    });

    test('an empty tone projects to nulls', () {
      const empty = Tone();
      expect(empty.ink.fg, isNull);
      expect(empty.wash.bg, isNull);
    });
  });

  group('Tone value semantics', () {
    test('equality and hashCode', () {
      const a = Tone(color: Color.red);
      const b = Tone(color: Color.red);
      const c = Tone(color: Color.blue);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith replaces color', () {
      const a = Tone(color: Color.red);
      expect(a.copyWith(color: Color.blue), const Tone(color: Color.blue));
    });
  });

  group('SurfaceTone projections', () {
    const tone = SurfaceTone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9));

    test('ink is foreground only', () {
      expect(tone.ink.fg, equals(const Color.rgb(0x264a5c)));
      expect(tone.ink.bg, isNull);
    });

    test('fill is on over color', () {
      expect(tone.fill.fg, equals(const Color.rgb(0xc9d1d9)));
      expect(tone.fill.bg, equals(const Color.rgb(0x264a5c)));
    });

    test('wash is background only', () {
      expect(tone.wash.bg, equals(const Color.rgb(0x264a5c)));
      expect(tone.wash.fg, isNull);
    });

    test('a null color still projects a fill from `on` alone', () {
      const bare = SurfaceTone(on: Color.white);
      expect(bare.ink.fg, isNull);
      expect(bare.fill.fg, equals(Color.white));
      expect(bare.fill.bg, isNull);
    });
  });

  group('SurfaceTone value semantics', () {
    test('equality and hashCode', () {
      const a = SurfaceTone(color: Color.red, on: Color.white);
      const b = SurfaceTone(color: Color.red, on: Color.white);
      const c = SurfaceTone(color: Color.blue, on: Color.white);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith replaces a half', () {
      const a = SurfaceTone(color: Color.red, on: Color.white);
      expect(a.copyWith(on: Color.black), const SurfaceTone(color: Color.red, on: Color.black));
      expect(a.copyWith(color: Color.blue), const SurfaceTone(color: Color.blue, on: Color.white));
    });
  });

  group('Tone and SurfaceTone stay distinct types', () {
    test('a Tone and a SurfaceTone built from the same color are never equal', () {
      const tone = Tone(color: Color.red);
      const surfaceTone = SurfaceTone(color: Color.red, on: Color.white);
      expect(tone, isNot(equals(surfaceTone)));
      expect(surfaceTone, isNot(equals(tone)));
    });
  });
}
