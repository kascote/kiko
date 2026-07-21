import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('TermUnicodeMeasurer', () {
    const measurer = TermUnicodeMeasurer();

    test('counts ASCII as one cell each', () {
      expect(measurer.widthOf('hello'), 5);
    });

    test('an empty string is zero cells', () {
      expect(measurer.widthOf(''), 0);
    });

    test('a wide glyph is two cells', () {
      expect(measurer.widthOf('🦀'), 2);
      expect(measurer.widthOf('a🦀b'), 4);
    });

    test('CJK characters are two cells each', () {
      expect(measurer.widthOf('你好'), 4);
    });

    test('a combining mark adds no width', () {
      // 'e' + combining acute accent is one grapheme cluster, one cell wide.
      expect(measurer.widthOf('é'), 1);
    });

    test('a ZWJ family emoji is one cluster, two cells', () {
      // Man + ZWJ + woman + ZWJ + girl is one grapheme cluster.
      expect(measurer.widthOf('\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}'), 2);
    });

    test('a regional-indicator flag pair is one cluster, two cells', () {
      // Regional indicators A + R (Argentina) form one grapheme cluster.
      expect(measurer.widthOf('\u{1F1E6}\u{1F1F7}'), 2);
    });

    test('stacked combining marks add no width', () {
      // 'e' + combining acute + combining cedilla is one grapheme cluster.
      expect(measurer.widthOf('ȩ́'), 1);
    });

    test('a bare non-Emoji_Presentation character is narrow', () {
      // U+2602 UMBRELLA is emoji-capable but not Emoji_Presentation, so it
      // measures as ordinary text width.
      expect(measurer.widthOf('☂'), 1);
    });

    test('VS16 forces emoji presentation, widening it', () {
      expect(measurer.widthOf('☂️'), 2);
    });

    test('an Emoji_Presentation character is wide by default', () {
      expect(measurer.widthOf('⌚'), 2);
    });

    test('VS15 forces text presentation, narrowing it', () {
      expect(measurer.widthOf('⌚︎'), 1);
    });

    test('a lone variation selector with no base is zero width', () {
      expect(measurer.widthOf('\u{FE0F}'), 0);
      expect(measurer.widthOf('\u{FE0E}'), 0);
    });

    group('additivity precondition (spec 0053)', () {
      // The width of a string must equal the sum of the widths of its grapheme
      // clusters — plume's Text widget measures cluster-by-cluster and would
      // paint past the box if the whole-string width exceeded that sum.
      for (final text in <String>[
        'hello',
        'a🦀b',
        '你好world',
        'éfg',
        'mix 日本語 🦀 text',
        'a\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}b',
        '你\u{1F1E6}\u{1F1F7}好',
        'a☂️b⌚︎c',
        '你ȩ́好',
      ]) {
        test('holds for "$text"', () {
          final sumOfClusters = text.characters.fold<int>(0, (total, cluster) => total + measurer.widthOf(cluster));
          expect(measurer.widthOf(text), sumOfClusters);
        });
      }
    });

    group('cjk', () {
      test('treats ambiguous-width characters as wide when enabled', () {
        // U+00B1 (±) is ambiguous width: one cell normally, two under CJK.
        expect(const TermUnicodeMeasurer().widthOf('±'), 1);
        expect(const TermUnicodeMeasurer(cjk: true).widthOf('±'), 2);
      });

      test('leaves unambiguous characters unchanged', () {
        expect(const TermUnicodeMeasurer(cjk: true).widthOf('a🦀'), 3);
      });
    });
  });
}
