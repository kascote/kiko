import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

// The shared contract for every press-activated widget: a release activates
// only after the widget's own press. A release with no press behind it
// reaches a widget when the app intercepted the press (a modal dismissed on
// the press, an outside-close rule) or when the widget under the cursor
// changed between the press and the release. Neither is a click on this
// widget. Keep every press-activated widget in this file.

/// A pointer over a 6×1 widget at the origin, addressed to [id]. `local`
/// doubles as the in-widget position, so the release is `inside`.
PointerMsg _pointer(PointerAction action, String id) => PointerMsg(
  global: const Position(1, 0),
  action: action,
  local: const Position(1, 0),
  targetId: id,
  targetRect: Rect.create(x: 0, y: 0, width: 6, height: 1),
);

void main() {
  group('a release without the widget’s own press does nothing', () {
    test(
      'ButtonModel',
      () {
        final button = ButtonModel(id: 'btn', label: Line('OK'));

        final orphan = button.update(_pointer(PointerAction.up, 'btn'));

        expect(orphan, isA<Handled>().having((h) => h.events, 'events', isEmpty));
        expect(button.pressed, isFalse);

        // The real click still fires, so the guard is on the press, not on
        // the release.
        button.update(_pointer(PointerAction.down, 'btn'));
        final click = button.update(_pointer(PointerAction.up, 'btn'));
        expect(click, isA<Handled>().having((h) => h.events, 'events', [const ButtonPressEvent('btn')]));
      },
      skip: 'pending: a button fires on a release without having seen its own press',
    );

    test(
      'CheckboxModel',
      () {
        final checkbox = CheckboxModel(id: 'cb', label: Line('Agree'));

        final orphan = checkbox.update(_pointer(PointerAction.up, 'cb'));

        expect(orphan, isA<Handled>().having((h) => h.events, 'events', isEmpty));
        expect(checkbox.checked, isFalse, reason: 'an orphan release never toggles');

        checkbox.update(_pointer(PointerAction.down, 'cb'));
        final click = checkbox.update(_pointer(PointerAction.up, 'cb'));
        expect(
          click,
          isA<Handled>().having((h) => h.events, 'events', [const CheckboxChangeEvent('cb', checked: true)]),
        );
        expect(checkbox.checked, isTrue);
      },
      skip: 'pending: a checkbox toggles on a release without having seen its own press',
    );

    test('a cancel between the press and the release clears the press (ButtonModel)', () {
      final button = ButtonModel(id: 'btn', label: Line('OK'))..update(_pointer(PointerAction.down, 'btn'));
      expect(button.pressed, isTrue);

      button.update(const PointerCancelMsg('btn'));
      expect(button.pressed, isFalse);

      final release = button.update(_pointer(PointerAction.up, 'btn'));
      expect(
        release,
        isA<Handled>().having((h) => h.events, 'events', isEmpty),
        reason: 'the cancel ended the gesture, so the release cannot fire it',
        skip: 'pending: a button fires on a release without having seen its own press',
      );
    });
  });
}
