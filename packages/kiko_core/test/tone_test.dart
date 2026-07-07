import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Tone projections', () {
    const tone = Tone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9));

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

    test('nullable halves project to nulls', () {
      const bare = Tone(color: Color.red);
      expect(bare.ink.fg, equals(Color.red));
      expect(bare.fill.fg, isNull); // no `on`
      expect(bare.fill.bg, equals(Color.red));

      const empty = Tone();
      expect(empty.ink.fg, isNull);
      expect(empty.wash.bg, isNull);
    });
  });

  group('Tone value semantics', () {
    test('equality and hashCode', () {
      const a = Tone(color: Color.red, on: Color.white);
      const b = Tone(color: Color.red, on: Color.white);
      const c = Tone(color: Color.blue, on: Color.white);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith replaces a half', () {
      const a = Tone(color: Color.red, on: Color.white);
      expect(a.copyWith(on: Color.black), const Tone(color: Color.red, on: Color.black));
      expect(a.copyWith(color: Color.blue), const Tone(color: Color.blue, on: Color.white));
    });
  });
}
