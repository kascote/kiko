import 'package:characters/characters.dart';
import 'package:kiko/iterators.dart';
import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

const _measurer = TermUnicodeMeasurer();

void main() {
  group('CharUtils', () {
    test('truncateLast with length greater than width', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(10, _measurer), '');
    });

    test('truncateLast with length less than width', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(2, _measurer), 'lo');
    });

    test('truncateLast with length exactly the width', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(5, _measurer), 'Hello');
    });

    test('truncateLast with length zero', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(0, _measurer), '');
    });

    test('truncateLast with negative length', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(-1, _measurer), '');
    });

    test('truncateLast with emoji characters', () {
      final chars = 'Hello 😊'.characters;
      expect(chars.truncateStart(2, _measurer), '😊');
      expect(chars.truncateStart(4, _measurer), 'o 😊');
      expect(chars.truncateStart(7, _measurer), 'ello 😊');
    });

    test('truncateLast never splits a multi-codepoint grapheme cluster', () {
      // A thumbs-up base codepoint followed by a skin-tone modifier codepoint;
      // the two form a single grapheme cluster that renders as one glyph.
      final chars = 'Hi👍🏽'.characters;
      expect(chars.length, 3, reason: 'base + modifier form one cluster');

      // A budget that fits the emoji keeps it whole — both codepoints, one
      // cluster — and counts its width as 2 (its rendered width), not 4 (the
      // sum of measuring each codepoint separately).
      final kept = chars.truncateStart(2, _measurer);
      expect(kept, '👍🏽');
      expect(kept.runes.length, 2, reason: 'skin-tone modifier is not lost');
      expect(_measurer.widthOf(kept), 2);

      // A budget too small for the cluster drops it whole rather than
      // splitting off just the base emoji.
      expect(chars.truncateStart(1, _measurer), '');
    });
  });
}
