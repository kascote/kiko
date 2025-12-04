import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Padding', () {
    test('insets child by padding', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 5));
      const Padding(
        padding: EdgeInsets(left: 2, right: 2, top: 1, bottom: 1),
        child: _FillWidget('X'),
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      final expected = Buffer.fromStringLines([
        '          ',
        '  XXXXXX  ',
        '  XXXXXX  ',
        '  XXXXXX  ',
        '          ',
      ]);
      expect(buffer.eq(expected), isTrue);
    });

    test('uniform padding', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 4));
      const Padding(
        padding: EdgeInsets.all(1),
        child: _FillWidget('O'),
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      final expected = Buffer.fromStringLines([
        '      ',
        ' OOOO ',
        ' OOOO ',
        '      ',
      ]);
      expect(buffer.eq(expected), isTrue);
    });

    test('zero padding renders child at full size', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 2));
      const Padding(
        padding: EdgeInsets.zero(),
        child: _FillWidget('Z'),
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      final expected = Buffer.fromStringLines([
        'ZZZZ',
        'ZZZZ',
      ]);
      expect(buffer.eq(expected), isTrue);
    });

    test('does not render child if padding exceeds area', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 2));
      const Padding(
        padding: EdgeInsets(left: 3, right: 3),
        child: _FillWidget('X'),
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      // Child not rendered, buffer stays empty
      final expected = Buffer.fromStringLines([
        '    ',
        '    ',
      ]);
      expect(buffer.eq(expected), isTrue);
    });
  });
}

class _FillWidget implements Widget {
  final String char;
  const _FillWidget(this.char);

  @override
  void render(Rect area, Frame frame) {
    for (var y = area.top; y < area.bottom; y++) {
      for (var x = area.left; x < area.right; x++) {
        frame.buffer[(x: x, y: y)] = frame.buffer[(x: x, y: y)].copyWith(char: char);
      }
    }
  }
}
