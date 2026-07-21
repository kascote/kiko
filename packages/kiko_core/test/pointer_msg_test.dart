import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

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
  });
}
