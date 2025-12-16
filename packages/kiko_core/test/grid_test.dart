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
  group('ConstraintChild', () {
    test('accepts any constraint', () {
      const child = ConstraintChild(
        ConstraintRatio(1, 2),
        child: _FillWidget('X'),
      );
      expect(child.constraint, isA<ConstraintRatio>());
    });
  });

  group('Grid', () {
    test('renders 2x2 grid', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 2));
      Grid(
        rows: 2,
        columns: 2,
        rowConstraint: const ConstraintLength(1),
        columnConstraint: const ConstraintLength(2),
        cellBuilder: (row, col) {
          final chars = ['A', 'B', 'C', 'D'];
          return _FillWidget(chars[row * 2 + col]);
        },
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(
        buffer.eq(Buffer.fromStringLines(['AABB', 'CCDD'])),
        isTrue,
      );
    });

    test('renders 3x3 grid', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 3, height: 3));
      Grid(
        rows: 3,
        columns: 3,
        rowConstraint: const ConstraintLength(1),
        columnConstraint: const ConstraintLength(1),
        cellBuilder: (row, col) => _FillWidget('${row * 3 + col + 1}'),
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(
        buffer.eq(Buffer.fromStringLines(['123', '456', '789'])),
        isTrue,
      );
    });

    test('cellBuilder receives correct row/col indices', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 2));
      final captured = <(int, int)>[];

      Grid(
        rows: 2,
        columns: 3,
        rowConstraint: const ConstraintLength(1),
        columnConstraint: const ConstraintLength(2),
        cellBuilder: (row, col) {
          captured.add((row, col));
          return const _FillWidget('.');
        },
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(captured, [
        (0, 0),
        (0, 1),
        (0, 2),
        (1, 0),
        (1, 1),
        (1, 2),
      ]);
    });

    test('respects different constraints', () {
      // Use even width for predictable Fill split
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 4));
      Grid(
        rows: 2,
        columns: 2,
        rowConstraint: const ConstraintLength(2),
        columnConstraint: const ConstraintFill(1),
        cellBuilder: (row, col) {
          if (row == 0 && col == 0) return const _FillWidget('A');
          if (row == 0 && col == 1) return const _FillWidget('B');
          if (row == 1 && col == 0) return const _FillWidget('C');
          return const _FillWidget('D');
        },
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      // 6 width split evenly: 3 + 3
      expect(
        buffer.eq(
          Buffer.fromStringLines([
            'AAABBB',
            'AAABBB',
            'CCCDDD',
            'CCCDDD',
          ]),
        ),
        isTrue,
      );
    });

    test('empty grid renders nothing', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 5));
      final empty = Buffer.empty(buffer.area);

      Grid(
        rows: 0,
        columns: 0,
        rowConstraint: const ConstraintLength(1),
        columnConstraint: const ConstraintLength(1),
        cellBuilder: (row, col) => const _FillWidget('X'),
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(buffer.eq(empty), isTrue);
    });

    test('works with nested widgets in cells', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 2));

      Grid(
        rows: 1,
        columns: 2,
        rowConstraint: const ConstraintLength(2),
        columnConstraint: const ConstraintLength(4),
        cellBuilder: (row, col) => Row(
          children: [
            Fixed(2, child: _FillWidget(col == 0 ? 'A' : 'C')),
            Fixed(2, child: _FillWidget(col == 0 ? 'B' : 'D')),
          ],
        ),
      ).render(buffer.area, Frame(buffer.area, buffer, 0));

      expect(
        buffer.eq(Buffer.fromStringLines(['AABBCCDD', 'AABBCCDD'])),
        isTrue,
      );
    });
  });
}
