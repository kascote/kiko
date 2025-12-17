import 'package:characters/characters.dart';
import 'package:kiko_widgets/src/widgets/text_area/sanitizer.dart';
import 'package:test/test.dart';

void main() {
  test('empty text', () {
    expect(sanitizer(''.characters), ''.characters);
  });

  test('text', () {
    expect(sanitizer('x'.characters), 'x'.characters);
    expect(sanitizer('foo bar'.characters), 'foo bar'.characters);
  });

  test('new lines', () {
    expect(sanitizer('\n'.characters, replaceNewLine: 'XX'), 'XX'.characters);
    expect(sanitizer('\na\n'.characters, replaceNewLine: 'XX'), 'XXaXX'.characters);
    expect(sanitizer('\n\n'.characters, replaceNewLine: 'XX'), 'XXXX'.characters);
    expect(sanitizer('foo\nbar'.characters, replaceNewLine: 'XX'), 'fooXXbar'.characters);
    expect(sanitizer('foo\nbar'.characters, replaceNewLine: ''), 'foobar'.characters);
    expect(sanitizer('foo\rbar'.characters, replaceNewLine: 'XX'), 'fooXXbar'.characters);
  });

  test('tabs', () {
    expect(sanitizer('\t'.characters, replaceTab: 'XX'), 'XX'.characters);
    expect(sanitizer('\ta\t'.characters, replaceTab: 'XX'), 'XXaXX'.characters);
    expect(sanitizer('\t\t'.characters, replaceTab: 'XX'), 'XXXX'.characters);
    expect(sanitizer('foo\tbar'.characters, replaceTab: 'XX'), 'fooXXbar'.characters);
    expect(sanitizer('foo\tbar'.characters, replaceTab: ''), 'foobar'.characters);
  });

  test('mixed tabs newlines', () {
    expect(sanitizer('f\too\n\nba\tr'.characters, replaceNewLine: 'XX', replaceTab: ''), 'fooXXXXbar'.characters);
    expect(sanitizer('f\n\noo\tbar'.characters, replaceNewLine: 'XX', replaceTab: ''), 'fXXXXoobar'.characters);
  });

  test('control', () {
    expect(sanitizer('foo\x1bbar'.characters), 'foobar'.characters);
    expect(sanitizer('foo\x00bar'.characters), 'foobar'.characters);
  });

  test('emoji', () {
    expect(sanitizer('foo👨‍🦰bar'.characters), 'foo👨‍🦰bar'.characters);
    expect(sanitizer('fo\ro🌎b\tar'.characters), 'fo\no🌎b  ar'.characters);
  });
}
