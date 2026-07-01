import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  const m = MonospaceMeasurer();

  group('MonospaceMeasurer', () {
    test('width is one cell per grapheme', () {
      expect(m.widthOf('hello'), 5);
      expect(m.widthOf(''), 0);
    });

    group('wrap', () {
      test('returns the whole string when it fits', () {
        expect(m.wrap('hello world', 20), ['hello world']);
      });

      test('breaks on word boundaries', () {
        expect(m.wrap('hello world foo', 11), ['hello world', 'foo']);
      });

      test('packs greedily up to the width', () {
        expect(m.wrap('aa bb cc dd', 5), ['aa bb', 'cc dd']);
      });

      test('hard-breaks a word longer than the width', () {
        expect(m.wrap('abcdefgh', 3), ['abc', 'def', 'gh']);
      });

      test('flushes the current line before a hard-broken word', () {
        expect(m.wrap('hi abcdefgh', 3), ['hi', 'abc', 'def', 'gh']);
      });

      test('respects explicit newlines', () {
        expect(m.wrap('a\nb', 10), ['a', 'b']);
      });

      test('a non-positive width returns the text unbroken', () {
        expect(m.wrap('abc', 0), ['abc']);
      });
    });
  });
}
