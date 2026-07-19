import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// A pointer over a 6×1 button at the origin, addressed to `'btn'`.
///
/// `local` doubles as the in-button position, so `inside` follows from [x]/[y]:
/// an [x] past the 6-cell width models a captured release slid off the button.
PointerMsg pointerAt(MouseButton button, {int x = 0, int y = 0}) => PointerMsg(
  MouseEvent(x, y, button),
  local: Position(x, y),
  targetId: 'btn',
  targetRect: Rect.create(x: 0, y: 0, width: 6, height: 1),
);

void main() {
  group('ButtonModel', () {
    test('default state', () {
      final button = ButtonModel(id: 'btn', label: Line('Test'));
      expect(button.id, equals('btn'));
      expect(button.label.width(const TermUnicodeMeasurer()), equals(4));
      expect(button.disabled, isFalse);
      expect(button.loading, isFalse);
      expect(button.focused, isFalse);
      expect(button.padding, equals(1));
    });

    test('width includes padding', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), padding: 2);
      expect(button.width(const TermUnicodeMeasurer()), equals(6)); // 2 chars + 2*2 padding
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

    test('declines a message it does not know', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), focused: true);
      expect(button.update(const NoneMsg()), isA<Declined>());
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

  group('ButtonModel mouse', () {
    // Unfocused throughout: a click works whether or not the button has focus
    // (the app focuses it on the down); the pointer branch sits above the gate.
    test('down then up inside activates', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));

      final down = button.update(pointerAt(MouseButton.down(), x: 2));
      expect(down, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
      expect(button.pressed, isTrue);

      final up = button.update(pointerAt(MouseButton.up(), x: 2));
      expect(button.pressed, isFalse);
      expect(up, isA<Handled>());
      final cmd = (up as Handled).cmd;
      expect(cmd, isA<ButtonPressCmd>());
      expect((cmd! as ButtonPressCmd).id, equals('btn'));
    });

    test('down then up slid off does not activate', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'))..update(pointerAt(MouseButton.down(), x: 2));
      expect(button.pressed, isTrue);

      // Captured: the cursor left the 6-cell button, so the up lands outside.
      final up = button.update(pointerAt(MouseButton.up(), x: 20));
      expect(button.pressed, isFalse);
      expect(up, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('cancel ends the press without activating', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'))..update(pointerAt(MouseButton.down(), x: 2));
      expect(button.pressed, isTrue);

      final cancelled = button.update(const PointerCancelMsg('btn'));
      expect(button.pressed, isFalse);
      expect(cancelled, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a pointer sets hover, a leave clears it', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));
      expect(button.hovered, isFalse);

      button.update(pointerAt(MouseButton.moved(), x: 2));
      expect(button.hovered, isTrue);

      button.update(const PointerLeaveMsg('btn'));
      expect(button.hovered, isFalse);
    });

    test('a disabled button ignores the press', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), disabled: true);

      final down = button.update(pointerAt(MouseButton.down(), x: 2));
      expect(button.pressed, isFalse);
      expect(down, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));

      final up = button.update(pointerAt(MouseButton.up(), x: 2));
      expect(up, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a loading button ignores the press', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'), loading: true)
        ..update(pointerAt(MouseButton.down(), x: 2));
      expect(button.pressed, isFalse);
      final up = button.update(pointerAt(MouseButton.up(), x: 2));
      expect(up, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('the wheel is declined so a scrollable ancestor gets it', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'));
      expect(button.update(pointerAt(MouseButton.wheelDown())), isA<Declined>());
      expect(button.update(pointerAt(MouseButton.wheelUp())), isA<Declined>());
      expect(button.pressed, isFalse);
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
