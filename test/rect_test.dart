import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

const u16Max = 65535;

void main() {
  group('Rect', () {
    test('toString', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      expect(r.toString(), 'Rect(1x2+3+4)');

      final r1 = Rect.create(x: 0, y: 0, width: 12, height: 1);
      expect(r1.toString(), 'Rect(0x0+12+1)');
    });

    test('toString', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      expect(r.x, 1);
      expect(r.y, 2);
      expect(r.width, 3);
      expect(r.height, 4);
    });

    test('zero', () {
      const r = Rect.zero;
      expect(r.x, 0);
      expect(r.y, 0);
      expect(r.width, 0);
      expect(r.height, 0);
      expect(r.toString(), 'Rect(0x0+0+0)');
    });

    test('area', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      expect(r.area, 12);
    });

    test('isEmpty', () {
      expect(Rect.create(x: 1, y: 2, width: 3, height: 4).isEmpty, false);
      expect(Rect.create(x: 1, y: 2, width: 0, height: 4).isEmpty, true);
      expect(Rect.create(x: 1, y: 2, width: 3, height: 0).isEmpty, true);
    });

    test('left', () {
      expect(Rect.create(x: 1, y: 2, width: 3, height: 4).left, 1);
    });

    test('right', () {
      expect(Rect.create(x: 1, y: 2, width: 3, height: 4).right, 4);
    });

    test('top', () {
      expect(Rect.create(x: 1, y: 2, width: 3, height: 4).top, 2);
    });

    test('bottom', () {
      expect(Rect.create(x: 1, y: 2, width: 3, height: 4).bottom, 6);
    });

    test('inner', () {
      expect(
        Rect.create(x: 1, y: 2, width: 3, height: 4).inner(const Margin(1, 2)),
        Rect.create(x: 2, y: 4, width: 1, height: 0),
      );
    });

    test('offset', () {
      expect(
        Rect.create(x: 1, y: 2, width: 3, height: 4).offset(const Offset(5, 6)),
        Rect.create(x: 6, y: 8, width: 3, height: 4),
      );
    });

    test('negative offset', () {
      expect(
        Rect.create(
          x: 4,
          y: 3,
          width: 3,
          height: 4,
        ).offset(const Offset(-2, -1)),
        Rect.create(x: 2, y: 2, width: 3, height: 4),
      );
    });

    test('negative offset saturate', () {
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).offset(const Offset(-5, -6)),
        Rect.create(x: 0, y: 0, width: 3, height: 4),
      );
    });

    test('offset saturate max', () {
      expect(
        Rect.create(
          x: u16Max - 500,
          y: u16Max - 500,
          width: 100,
          height: 100,
        ).offset(const Offset(1000, 100)),
        Rect.create(
          x: u16Max - 100,
          y: u16Max - 400,
          width: 100,
          height: 100,
        ),
      );
    });

    test('union', () {
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).union(Rect.create(x: 2, y: 3, width: 4, height: 5)),
        Rect.create(x: 1, y: 2, width: 5, height: 6),
      );
    });

    test('intersection', () {
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).intersection(Rect.create(x: 2, y: 3, width: 4, height: 5)),
        Rect.create(x: 2, y: 3, width: 2, height: 3),
      );
    });

    test('intersection underflow', () {
      expect(
        Rect.create(
          x: 1,
          y: 1,
          width: 2,
          height: 2,
        ).intersection(Rect.create(x: 4, y: 4, width: 2, height: 2)),
        Rect.create(x: 4, y: 4, width: 0, height: 0),
      );
    });

    test('intersects', () {
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).intersects(Rect.create(x: 2, y: 3, width: 4, height: 5)),
        true,
      );
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).intersects(Rect.create(x: 5, y: 6, width: 7, height: 8)),
        false,
      );
    });

    test('contains', () {
      // top left
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(1, 2)),
        true,
      );
      // top right
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(3, 2)),
        true,
      );
      // bottom left
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(1, 5)),
        true,
      );
      // bottom right
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(3, 5)),
        true,
      );
      // outside left
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(0, 2)),
        false,
      );
      // outside right
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(4, 2)),
        false,
      );
      // outside top
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(1, 1)),
        false,
      );
      // outside bottom
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(1, 6)),
        false,
      );
      // outside top left
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(0, 1)),
        false,
      );
      // outside bottom right
      expect(
        Rect.create(
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ).contains(const Position(4, 6)),
        false,
      );
    });

    test('size truncation', () {
      expect(
        Rect.create(x: u16Max - 100, y: u16Max - 1000, width: 200, height: 200),
        Rect.create(x: u16Max - 100, y: u16Max - 1000, width: 200, height: 200),
      );
    });

    test('size preservation', () {
      for (var width = 0; width <= 255; width++) {
        for (var height = 0; height <= 255; height++) {
          final r = Rect.create(x: 0, y: 0, width: width, height: height);
          expect(r.width == width, true);
          expect(r.height == height, true);
        }
      }

      // One dimension below 255, one above. Area below max u16Max
      final r = Rect.create(x: 0, y: 0, width: 300, height: 100);
      expect(r.width, 300);
      expect(r.height, 100);
    });

    test('clamp', () {
      final cases = [
        [
          Rect.create(x: 20, y: 20, width: 10, height: 10),
          Rect.create(x: 20, y: 20, width: 10, height: 10),
        ],
        [
          Rect.create(x: 5, y: 5, width: 10, height: 10),
          Rect.create(x: 10, y: 10, width: 10, height: 10),
        ],
        [
          Rect.create(x: 20, y: 5, width: 10, height: 10),
          Rect.create(x: 20, y: 10, width: 10, height: 10),
        ],
        [
          Rect.create(x: 105, y: 5, width: 10, height: 10),
          Rect.create(x: 100, y: 10, width: 10, height: 10),
        ],
        [
          Rect.create(x: 5, y: 20, width: 10, height: 10),
          Rect.create(x: 10, y: 20, width: 10, height: 10),
        ],
        [
          Rect.create(x: 105, y: 20, width: 10, height: 10),
          Rect.create(x: 100, y: 20, width: 10, height: 10),
        ],
        [
          Rect.create(x: 5, y: 105, width: 10, height: 10),
          Rect.create(x: 10, y: 100, width: 10, height: 10),
        ],
        [
          Rect.create(x: 20, y: 105, width: 10, height: 10),
          Rect.create(x: 20, y: 100, width: 10, height: 10),
        ],
        [
          Rect.create(x: 105, y: 105, width: 10, height: 10),
          Rect.create(x: 100, y: 100, width: 10, height: 10),
        ],
        [
          Rect.create(x: 5, y: 20, width: 200, height: 10),
          Rect.create(x: 10, y: 20, width: 100, height: 10),
        ],
        [
          Rect.create(x: 20, y: 5, width: 10, height: 100),
          Rect.create(x: 20, y: 10, width: 10, height: 100),
        ],
        [
          Rect.create(x: 0, y: 0, width: 200, height: 200),
          Rect.create(x: 10, y: 10, width: 100, height: 100),
        ],
      ];

      final other = Rect.create(x: 10, y: 10, width: 100, height: 100);
      for (final c in cases) {
        final r = c[0];
        final expected = c[1];
        expect(r.clamp(other), expected);
      }
    });

    test('rows', () {
      final r = Rect.create(x: 0, y: 0, width: 3, height: 2);
      final rows = r.rows.iterator;
      while (rows.moveNext()) {
        final row = rows.current;
        expect(row, Rect.create(x: 0, y: row.top, width: 3, height: 1));
      }
    });

    test('columns', () {
      final r = Rect.create(x: 0, y: 0, width: 3, height: 2);
      final columns = r.columns.iterator;
      while (columns.moveNext()) {
        final column = columns.current;
        expect(column, Rect.create(x: column.left, y: 0, width: 1, height: 2));
      }
    });

    test('asPosition', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      expect(r.asPosition, const Position(1, 2));
    });

    test('asSize', () {
      final r = Rect.create(x: 1, y: 2, width: 3, height: 4);
      expect(r.asSize, const Size(3, 4));
    });

    test('fromPositionSize', () {
      final r = Rect.fromPositionSize(const Position(1, 2), const Size(3, 4));
      expect(r, Rect.create(x: 1, y: 2, width: 3, height: 4));
    });

    test('get positions Iterable', () {
      final r = Rect.create(x: 0, y: 0, width: 1, height: 2);
      expect(r.positions.length, 4);
      expect(r.positions.first, Position.origin);
      expect(r.positions.last, const Position(1, 1));
    });
  });
}
