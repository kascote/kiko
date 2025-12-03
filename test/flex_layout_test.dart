import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// A simple widget that fills its area with a character.
class _FillWidget implements Widget {
  final String char;

  const _FillWidget(this.char);

  @override
  void render(Rect area, Frame frame) {
    for (var y = area.y; y < area.y + area.height; y++) {
      for (var x = area.x; x < area.x + area.width; x++) {
        frame.buffer.setCellAtPos(x: x, y: y, char: char);
      }
    }
  }
}

void main() {
  group('LayoutChild', () {
    test('Fixed creates ConstraintLength', () {
      final child = Fixed(10, child: const _FillWidget('X'));
      expect(child.constraint, isA<ConstraintLength>());
      expect((child.constraint as ConstraintLength).value, 10);
    });

    test('MinSize creates ConstraintMin', () {
      final child = MinSize(5, child: const _FillWidget('X'));
      expect(child.constraint, isA<ConstraintMin>());
      expect((child.constraint as ConstraintMin).value, 5);
    });

    test('Percent creates ConstraintPercentage', () {
      final child = Percent(50, child: const _FillWidget('X'));
      expect(child.constraint, isA<ConstraintPercentage>());
      expect((child.constraint as ConstraintPercentage).value, 50);
    });

    test('Expanded creates ConstraintFill', () {
      final child = Expanded(child: const _FillWidget('X'));
      expect(child.constraint, isA<ConstraintFill>());
      expect((child.constraint as ConstraintFill).value, 1);
    });

    test('Expanded with weight', () {
      final child = Expanded(child: const _FillWidget('X'), weight: 3);
      expect((child.constraint as ConstraintFill).value, 3);
    });
  });

  group('FlexLayout', () {
    test('renders empty children without error', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
      FlexLayout(
        direction: Direction.horizontal,
        children: const [],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      // Buffer should remain empty
      expect(buffer.eq(Buffer.empty(buffer.area)), isTrue);
    });

    test('renders single child filling area', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 1));
      FlexLayout(
        direction: Direction.horizontal,
        children: [Expanded(child: const _FillWidget('A'))],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(Buffer.fromStringLines(['AAAAA'])), isTrue);
    });

    test('splits horizontally with fixed sizes', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 1));
      FlexLayout(
        direction: Direction.horizontal,
        children: [
          Fixed(2, child: const _FillWidget('A')),
          Fixed(2, child: const _FillWidget('B')),
          Fixed(2, child: const _FillWidget('C')),
        ],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(Buffer.fromStringLines(['AABBCC'])), isTrue);
    });

    test('splits vertically with fixed sizes', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 3, height: 3));
      FlexLayout(
        direction: Direction.vertical,
        children: [
          Fixed(1, child: const _FillWidget('A')),
          Fixed(1, child: const _FillWidget('B')),
          Fixed(1, child: const _FillWidget('C')),
        ],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(
        buffer.eq(Buffer.fromStringLines(['AAA', 'BBB', 'CCC'])),
        isTrue,
      );
    });

    test('expanded children share remaining space', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 1));
      FlexLayout(
        direction: Direction.horizontal,
        children: [
          Fixed(2, child: const _FillWidget('A')),
          Expanded(child: const _FillWidget('B')),
          Expanded(child: const _FillWidget('C')),
        ],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(Buffer.fromStringLines(['AABBBCCC'])), isTrue);
    });

    test('respects spacing between children', () {
      // 2 + 1 (space) + 2 + 1 (space) + 2 = 8
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 1));
      FlexLayout(
        direction: Direction.horizontal,
        spacing: Space(1),
        children: [
          Fixed(2, child: const _FillWidget('A')),
          Fixed(2, child: const _FillWidget('B')),
          Fixed(2, child: const _FillWidget('C')),
        ],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(Buffer.fromStringLines(['AA BB CC'])), isTrue);
    });
  });

  group('Row', () {
    test('is horizontal FlexLayout', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 1));
      Row(
        children: [
          Fixed(2, child: const _FillWidget('A')),
          Fixed(2, child: const _FillWidget('B')),
        ],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(Buffer.fromStringLines(['AABB'])), isTrue);
    });
  });

  group('Column', () {
    test('is vertical FlexLayout', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 2, height: 2));
      Column(
        children: [
          Fixed(1, child: const _FillWidget('A')),
          Fixed(1, child: const _FillWidget('B')),
        ],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(Buffer.fromStringLines(['AA', 'BB'])), isTrue);
    });

    test('nested Row in Column', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 2));
      Column(
        children: [
          Fixed(
            1,
            child: Row(
              children: [
                Fixed(2, child: const _FillWidget('A')),
                Fixed(2, child: const _FillWidget('B')),
              ],
            ),
          ),
          Fixed(
            1,
            child: Row(
              children: [
                Fixed(2, child: const _FillWidget('C')),
                Fixed(2, child: const _FillWidget('D')),
              ],
            ),
          ),
        ],
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(Buffer.fromStringLines(['AABB', 'CCDD'])), isTrue);
    });
  });
}
