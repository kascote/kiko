import 'package:characters/characters.dart';
import 'package:kiko/iterators.dart';
import 'package:test/test.dart';

void main() {
  group('CharUtils', () {
    test('truncateLast with length greater than width', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(10), '');
    });

    test('truncateLast with length less than width', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(2), 'lo');
    });

    test('truncateLast with length exactly the width', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(5), 'Hello');
    });

    test('truncateLast with length zero', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(0), '');
    });

    test('truncateLast with negative length', () {
      final chars = 'Hello'.characters;
      expect(chars.truncateStart(-1), '');
    });

    test('truncateLast with emoji characters', () {
      final chars = 'Hello 😊'.characters;
      expect(chars.truncateStart(2), '😊');
      expect(chars.truncateStart(4), 'o 😊');
      expect(chars.truncateStart(7), 'ello 😊');
    });
  });
}
