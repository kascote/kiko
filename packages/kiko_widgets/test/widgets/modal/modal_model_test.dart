import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  group('ModalModel', () {
    test('default state is focused with the given id', () {
      final modal = ModalModel(id: 'confirm-quit');
      expect(modal.id, equals('confirm-quit'));
      expect(modal.focused, isTrue);
      expect(modal.confirmPayload, isNull);
    });

    test('auto-generates an id when none is given', () {
      final modal = ModalModel();
      expect(modal.id, isNotEmpty);
    });
  });

  group('ModalModel.update', () {
    test('returns ModalConfirmEvent with payload on enter', () {
      final modal = ModalModel(id: 'm', confirmPayload: 'delete');
      expect(
        modal.update(const KeyMsg('enter')),
        isA<Handled>().having((h) => h.events, 'events', equals([const ModalConfirmEvent('m', 'delete')])),
      );
    });

    test('returns ModalCancelEvent on escape', () {
      final modal = ModalModel(id: 'm');
      expect(
        modal.update(const KeyMsg('escape')),
        isA<Handled>().having((h) => h.events, 'events', equals([const ModalCancelEvent('m')])),
      );
    });

    test('absorbs unbound keys', () {
      final modal = ModalModel(id: 'm');
      expect(modal.update(const KeyMsg('a')), isA<Handled>().having((h) => h.events, 'events', isEmpty));
    });

    test('declines when not focused', () {
      final modal = ModalModel(id: 'm', focused: false);
      expect(modal.update(const KeyMsg('enter')), isA<Declined>());
    });

    test('declines a message it does not know', () {
      final modal = ModalModel(id: 'm');
      expect(modal.update(const TickMsg('elsewhere', elapsed: Duration.zero)), isA<Declined>());
    });
  });

  group('ModalModel barrier press', () {
    PointerMsg barrierDown(String id) => PointerMsg(
      global: Position.origin,
      local: Position.origin,
      action: PointerAction.down,
      targetId: id,
      region: const ModalBarrierRegion(),
    );

    test('emits ModalCancelEvent, the same event Escape emits', () {
      final modal = ModalModel(id: 'm');
      expect(
        modal.update(barrierDown('m')),
        isA<Handled>().having((h) => h.events, 'events', equals([const ModalCancelEvent('m')])),
      );
    });

    test('a press on the dialog’s own cells is absorbed with no event', () {
      final modal = ModalModel(id: 'm');
      final onDialog = PointerMsg(
        global: Position.origin,
        local: Position.origin,
        action: PointerAction.down,
        targetId: 'm',
        targetRect: Rect.create(x: 0, y: 0, width: 4, height: 2),
      );
      expect(modal.update(onDialog), isA<Handled>().having((h) => h.events, 'events', isEmpty));
    });

    test('emits nothing when dismissOnBarrierPress is off', () {
      final modal = ModalModel(id: 'm', dismissOnBarrierPress: false);
      expect(modal.update(barrierDown('m')), isA<Handled>().having((h) => h.events, 'events', isEmpty));
    });
  });
}
