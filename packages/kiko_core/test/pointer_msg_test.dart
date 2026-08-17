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
}
