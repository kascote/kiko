import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

/// A concrete region naming a row, for equality and carry-over tests.
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
  group('PointerMsg.retarget', () {
    test('carries the physical event unchanged and re-addresses it', () {
      final original = PointerMsg(
        global: const Position(12, 7),
        action: PointerAction.down,
        button: PointerButton.right,
        shift: true,
        ctrl: true,
        alt: true,
        local: const Position(2, 1),
        targetId: 'border',
        targetRect: Rect.create(x: 10, y: 6, width: 4, height: 2),
        captured: true,
      );

      final retargeted = original.retarget(
        targetId: 'member',
        targetRect: Rect.create(x: 8, y: 5, width: 6, height: 4),
      );

      expect(retargeted.global, original.global, reason: 'the physical position is unchanged');
      expect(retargeted.action, original.action);
      expect(retargeted.button, original.button);
      expect(retargeted.shift, isTrue);
      expect(retargeted.ctrl, isTrue);
      expect(retargeted.alt, isTrue);
      expect(retargeted.captured, isTrue);

      expect(retargeted.targetId, 'member');
      expect(retargeted.targetRect, Rect.create(x: 8, y: 5, width: 6, height: 4));
      expect(retargeted.local, const Position(4, 2), reason: 'global (12, 7) minus the new rect origin (8, 5)');
    });

    test('does not carry the incoming region — it defaults to null', () {
      const original = PointerMsg(
        global: Position(12, 7),
        action: PointerAction.down,
        local: Position(2, 1),
        targetId: 'border',
        region: _RowRegion(3),
      );

      final retargeted = original.retarget(
        targetId: 'member',
        targetRect: Rect.create(x: 8, y: 5, width: 6, height: 4),
      );

      expect(
        retargeted.region,
        isNull,
        reason: "the chrome's region means nothing under the member, so it is dropped, not copied",
      );
    });

    test('takes a freshly resolved region for the new target', () {
      const original = PointerMsg(
        global: Position(12, 7),
        action: PointerAction.down,
        local: Position(2, 1),
        targetId: 'border',
      );

      final retargeted = original.retarget(
        targetId: 'member',
        targetRect: Rect.create(x: 8, y: 5, width: 6, height: 4),
        region: const _RowRegion(1),
      );

      expect(retargeted.region, const _RowRegion(1));
    });
  });

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
