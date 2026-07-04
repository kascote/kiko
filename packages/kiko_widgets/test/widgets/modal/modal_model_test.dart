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
      final cmd = modal.update(const KeyMsg('enter'));
      expect(cmd, equals(const ModalConfirmCmd('m', 'delete')));
    });

    test('returns ModalCancelCmd on escape', () {
      final modal = ModalModel(id: 'm');
      final cmd = modal.update(const KeyMsg('escape'));
      expect(cmd, equals(const ModalCancelCmd('m')));
    });

    test('returns Unhandled for unbound keys', () {
      final modal = ModalModel(id: 'm');
      final cmd = modal.update(const KeyMsg('a'));
      expect(cmd, isA<Unhandled>());
    });

    test('returns null when not focused', () {
      final modal = ModalModel(id: 'm', focused: false);
      final cmd = modal.update(const KeyMsg('enter'));
      expect(cmd, isNull);
    });

    test('ignores non-key messages', () {
      final modal = ModalModel(id: 'm');
      final cmd = modal.update(const TickMsg(Duration.zero));
      expect(cmd, isNull);
    });
  });
}
