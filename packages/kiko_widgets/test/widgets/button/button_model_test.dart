import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  group('ButtonModel', () {
    test('default state', () {
      final button = ButtonModel(id: 'btn', label: Line('Test'));
      expect(button.id, equals('btn'));
      expect(button.label.width, equals(4));
      expect(button.disabled, isFalse);
      expect(button.loading, isFalse);
      expect(button.focused, isFalse);
      expect(button.padding, equals(1));
    });

    test('width includes padding', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), padding: 2);
      expect(button.width, equals(6)); // 2 chars + 2*2 padding
    });

    test('copyWith creates modified copy', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));
      final copy = button.copyWith(disabled: true, loading: true);

      expect(copy.id, equals('btn'));
      expect(copy.disabled, isTrue);
      expect(copy.loading, isTrue);
      expect(button.disabled, isFalse); // original unchanged
    });
  });

  group('ButtonModel.update', () {
    test('declines when not focused', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));
      expect(button.update(const KeyMsg('enter')), isA<Declined>());
    });

    test('returns ButtonPressCmd on enter when focused', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), focused: true);
      final result = button.update(const KeyMsg('enter'));
      expect(result, isA<Handled>());
      final cmd = (result as Handled).cmd;
      expect(cmd, isA<ButtonPressCmd>());
      expect((cmd! as ButtonPressCmd).id, equals('btn'));
    });

    test('declines unhandled keys', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), focused: true);
      expect(button.update(const KeyMsg('a')), isA<Declined>());
    });

    test('ignores activation when disabled', () {
      final button = ButtonModel(
        id: 'btn',
        label: Line('OK'),
        focused: true,
        disabled: true,
      );
      // Silent ignore: consumed with no command.
      expect(
        button.update(const KeyMsg('enter')),
        isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
      );
    });

    test('ignores activation when loading', () {
      final button = ButtonModel(
        id: 'btn',
        label: Line('OK'),
        focused: true,
        loading: true,
      );
      // Silent ignore: consumed with no command.
      expect(
        button.update(const KeyMsg('enter')),
        isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
      );
    });

    test('ignores non-key messages', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), focused: true);
      expect(
        button.update(const NoneMsg()),
        isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
      );
    });

    test('custom key bindings work', () {
      final customBindings = KeyBinding<ButtonAction>()..map(['space'], ButtonAction.activate);
      final button = ButtonModel(
        id: 'btn',
        label: Line('OK'),
        focused: true,
        keyBinding: customBindings,
      );

      // space should work
      expect(
        button.update(const KeyMsg('space')),
        isA<Handled>().having((h) => h.cmd, 'cmd', isA<ButtonPressCmd>()),
      );

      // enter should not work with custom bindings
      expect(button.update(const KeyMsg('enter')), isA<Declined>());
    });
  });

  group('ButtonModel Focusable', () {
    test('implements Focusable interface', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));
      expect(button, isA<Focusable>());
    });

    test('focus can be set', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));
      expect(button.focused, isFalse);

      button.focused = true;
      expect(button.focused, isTrue);

      button.focused = false;
      expect(button.focused, isFalse);
    });
  });
}
