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
    test('returns ModalConfirmCmd with payload on enter', () {
      final modal = ModalModel(id: 'm', confirmPayload: 'delete');
      expect(
        modal.update(const KeyMsg('enter')),
        isA<Handled>().having((h) => h.cmd, 'cmd', equals(const ModalConfirmCmd('m', 'delete'))),
      );
    });

    test('returns ModalCancelCmd on escape', () {
      final modal = ModalModel(id: 'm');
      expect(
        modal.update(const KeyMsg('escape')),
        isA<Handled>().having((h) => h.cmd, 'cmd', equals(const ModalCancelCmd('m'))),
      );
    });

    test('declines unbound keys', () {
      final modal = ModalModel(id: 'm');
      expect(modal.update(const KeyMsg('a')), isA<Declined>());
    });

    test('declines when not focused', () {
      final modal = ModalModel(id: 'm', focused: false);
      expect(modal.update(const KeyMsg('enter')), isA<Declined>());
    });

    test('declines a message it does not know', () {
      final modal = ModalModel(id: 'm');
      expect(modal.update(const TickMsg(Duration.zero)), isA<Declined>());
    });
  });

  group('ModalModel.dismiss', () {
    test('a click outside dismisses via the same cancel command as Escape', () {
      final modal = ModalModel(id: 'm');
      // The app detects the outside click (an app-side hitPath decision) and
      // fires this — the same event, same id, that Escape emits.
      final escapeCmd = (modal.update(const KeyMsg('escape')) as Handled).cmd;
      expect(modal.dismiss(), equals(const ModalCancelCmd('m')));
      expect(modal.dismiss(), equals(escapeCmd));
    });
  });
}
