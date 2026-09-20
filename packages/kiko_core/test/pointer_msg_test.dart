import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

/// A concrete region naming a row, for equality tests.
@immutable
class _RowRegion implements Region {
  const _RowRegion(this.index);

  final int index;

  @override
  bool operator ==(Object other) => other is _RowRegion && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => '_RowRegion($index)';
}

void main() {
  group('PointerMsg equality', () {
    PointerMsg base({Region? region}) => PointerMsg(
      global: const Position(5, 1),
      action: PointerAction.down,
      local: const Position(1, 1),
      targetId: 'list',
      region: region,
    );

    test('two messages differing only in region are unequal', () {
      expect(base(region: const _RowRegion(0)), isNot(base(region: const _RowRegion(1))));
      expect(base(region: const _RowRegion(0)), isNot(base()));
    });

    test('two messages with the same region compare equal', () {
      expect(base(region: const _RowRegion(2)), base(region: const _RowRegion(2)));
      expect(base(region: const _RowRegion(2)).hashCode, base(region: const _RowRegion(2)).hashCode);
    });
  });

  group('PointerMsg click count', () {
    PointerMsg press({required int clickCount}) => PointerMsg(
      global: const Position(5, 1),
      action: PointerAction.down,
      local: const Position(1, 1),
      targetId: 'list',
      clickCount: clickCount,
    );

    test('two messages differing only in click count are unequal', () {
      expect(press(clickCount: 1), isNot(press(clickCount: 2)));
    });

    test('two messages with the same click count compare equal', () {
      expect(press(clickCount: 2), press(clickCount: 2));
      expect(press(clickCount: 2).hashCode, press(clickCount: 2).hashCode);
    });

    test('toString shows the count only when it is non-zero', () {
      expect(press(clickCount: 0).toString(), isNot(contains('clicks:')));
      expect(press(clickCount: 2).toString(), contains('clicks: 2'));
    });

    test('isDoubleClick is true only for a press with count 2', () {
      expect(press(clickCount: 2).isDoubleClick, isTrue);
      expect(press(clickCount: 1).isDoubleClick, isFalse);
      expect(press(clickCount: 3).isDoubleClick, isFalse);

      const release = PointerMsg(
        global: Position(5, 1),
        action: PointerAction.up,
        local: Position(1, 1),
        targetId: 'list',
        clickCount: 2,
      );
      expect(release.isDoubleClick, isFalse);
    });
  });
}
