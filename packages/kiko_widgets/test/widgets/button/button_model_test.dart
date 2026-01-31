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

    test('currentStyle returns correct style for state', () {
      const styles = ButtonStyles(
        normal: Style(fg: Color.white),
        focus: Style(fg: Color.green),
        disabled: Style(fg: Color.gray),
        loading: Style(fg: Color.yellow),
      );

      var button = ButtonModel(id: 'btn', label: Line('OK'), styles: styles);
      expect(button.currentStyle, equals(const Style(fg: Color.white)));

      button = button.copyWith(focused: true);
      expect(button.currentStyle, equals(const Style(fg: Color.green)));

      button = button.copyWith(disabled: true);
      expect(button.currentStyle, equals(const Style(fg: Color.gray)));

      button = button.copyWith(disabled: false, loading: true);
      expect(button.currentStyle, equals(const Style(fg: Color.yellow)));
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
    test('returns null when not focused', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));
      final cmd = button.update(const KeyMsg('enter'));
      expect(cmd, isNull);
    });

    test('returns ButtonPressCmd on enter when focused', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), focused: true);
      final cmd = button.update(const KeyMsg('enter'));
      expect(cmd, isA<ButtonPressCmd>());
      expect((cmd! as ButtonPressCmd).id, equals('btn'));
    });

    test('returns Unhandled for unhandled keys', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), focused: true);
      final cmd = button.update(const KeyMsg('a'));
      expect(cmd, isA<Unhandled>());
    });

    test('ignores activation when disabled', () {
      final button = ButtonModel(
        id: 'btn',
        label: Line('OK'),
        focused: true,
        disabled: true,
      );
      final cmd = button.update(const KeyMsg('enter'));
      expect(cmd, isNull); // silent ignore
    });

    test('ignores activation when loading', () {
      final button = ButtonModel(
        id: 'btn',
        label: Line('OK'),
        focused: true,
        loading: true,
      );
      final cmd = button.update(const KeyMsg('enter'));
      expect(cmd, isNull); // silent ignore
    });

    test('ignores non-key messages', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), focused: true);
      final cmd = button.update(const NoneMsg());
      expect(cmd, isNull);
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
      var cmd = button.update(const KeyMsg('space'));
      expect(cmd, isA<ButtonPressCmd>());

      // enter should not work with custom bindings
      cmd = button.update(const KeyMsg('enter'));
      expect(cmd, isA<Unhandled>());
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
