import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _context = LayoutContext(measurer: MonospaceMeasurer());

/// Lays [text] out under [constraints], places it at the origin, and returns the
/// draw intents it emits.
List<String> _paint(Text<String> text, BoxConstraints constraints) {
  final surface = RecordingSurface<String>();
  text
    ..layout(constraints, _context)
    ..place(Offset.zero)
    ..paint(surface);
  return surface.intents.map((intent) => '$intent').toList();
}

Size _size(Text<String> text, BoxConstraints constraints) => text.layout(constraints, _context);

void main() {
  group('Text layout', () {
    test('without wrapping stays on one line', () {
      final size = _size(Text<String>([const TextRun('hello world', 'x')]), const BoxConstraints(maxW: 100, maxH: 10));
      expect(size, const Size(11, 1));
    });

    test('with wrapping fills the width and grows in height', () {
      final size = _size(
        Text<String>([const TextRun('hello world foo', 'x')], softWrap: true),
        const BoxConstraints(maxW: 13, maxH: 100),
      );
      // 'hello world' (11) then 'foo'; fills the 13-wide box, two rows tall.
      expect(size, const Size(13, 2));
    });

    test('maxLines caps the height', () {
      final size = _size(
        Text<String>([const TextRun('a b c d e', 'x')], softWrap: true, maxLines: 2),
        const BoxConstraints(maxW: 3, maxH: 100),
      );
      expect(size.h, 2);
    });
  });

  group('Text paint', () {
    test('wraps a run across lines, keeping its style token', () {
      final intents = _paint(
        Text<String>([const TextRun('aaaa bbbb', 'red')], softWrap: true),
        const BoxConstraints(maxW: 4, maxH: 100),
      );
      expect(intents, [
        'drawText(0, 0, "aaaa", red)',
        'drawText(0, 1, "bbbb", red)',
      ]);
    });

    test('splits adjacent runs by style on one line', () {
      final intents = _paint(
        Text<String>([const TextRun('ab', 'red'), const TextRun('cd', 'blue')]),
        BoxConstraints.tight(const Size(4, 1)),
      );
      expect(intents, [
        'drawText(0, 0, "ab", red)',
        'drawText(2, 0, "cd", blue)',
      ]);
    });

    test('aligns a line to the center within the box width', () {
      final intents = _paint(
        Text<String>([const TextRun('hi', 'x')], align: TextAlign.center),
        BoxConstraints.tight(const Size(10, 1)),
      );
      expect(intents, ['drawText(4, 0, "hi", x)']);
    });

    test('aligns a line to the end within the box width', () {
      final intents = _paint(
        Text<String>([const TextRun('hi', 'x')], align: TextAlign.end),
        BoxConstraints.tight(const Size(10, 1)),
      );
      expect(intents, ['drawText(8, 0, "hi", x)']);
    });

    test('clips an overflowing line at the box edge', () {
      final intents = _paint(Text<String>([const TextRun('hello', 'x')]), BoxConstraints.tight(const Size(3, 1)));
      expect(intents, ['drawText(0, 0, "hel", x)']);
    });

    test('ellipsizes an overflowing line', () {
      final intents = _paint(
        Text<String>([const TextRun('hello', 'x')], overflow: TextOverflow.ellipsis),
        BoxConstraints.tight(const Size(3, 1)),
      );
      expect(intents, ['drawText(0, 0, "he…", x)']);
    });
  });
}
