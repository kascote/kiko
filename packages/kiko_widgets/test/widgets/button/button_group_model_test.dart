// Tests often use explicit statements for clarity rather than cascades.
// ignore_for_file: cascade_invocations

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  group('ButtonGroupModel', () {
    late List<ButtonModel> buttons;

    setUp(() {
      buttons = [
        ButtonModel(id: 'a', label: Line('A')),
        ButtonModel(id: 'b', label: Line('B')),
        ButtonModel(id: 'c', label: Line('C')),
      ];
    });

    test('default state', () {
      final group = ButtonGroupModel(buttons: buttons);
      expect(group.focused, isFalse);
      expect(group.focusedIndex, equals(0));
      expect(group.wrapNavigation, isFalse);
    });

    test('focuses first button when group focused', () {
      ButtonGroupModel(buttons: buttons, focused: true);
      expect(buttons[0].focused, isTrue);
      expect(buttons[1].focused, isFalse);
      expect(buttons[2].focused, isFalse);
    });

    test('focusedButton returns current button', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      expect(group.focusedButton?.id, equals('a'));
    });

    test('focusedButton returns null for empty list', () {
      final group = ButtonGroupModel(buttons: []);
      expect(group.focusedButton, isNull);
    });
  });

  group('ButtonGroupModel.update navigation', () {
    late List<ButtonModel> buttons;

    setUp(() {
      buttons = [
        ButtonModel(id: 'a', label: Line('A')),
        ButtonModel(id: 'b', label: Line('B')),
        ButtonModel(id: 'c', label: Line('C')),
      ];
    });

    test('returns null when not focused', () {
      final group = ButtonGroupModel(buttons: buttons);
      expect(group.update(const KeyMsg('right')), isNull);
    });

    test('right moves focus to next button', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      expect(group.focusedIndex, equals(0));
      group.update(const KeyMsg('right'));
      expect(group.focusedIndex, equals(1));
      expect(buttons[0].focused, isFalse);
      expect(buttons[1].focused, isTrue);
    });

    test('left moves focus to prev button', () {
      final group = ButtonGroupModel(
        buttons: buttons,
        focused: true,
        initialFocusIndex: 1,
      );
      group.update(const KeyMsg('left'));
      expect(group.focusedIndex, equals(0));
    });

    test('l/h keys work for navigation', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.update(const KeyMsg('l'));
      expect(group.focusedIndex, equals(1));
      group.update(const KeyMsg('h'));
      expect(group.focusedIndex, equals(0));
    });

    test('up/down keys work for navigation', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.update(const KeyMsg('down'));
      expect(group.focusedIndex, equals(1));
      group.update(const KeyMsg('up'));
      expect(group.focusedIndex, equals(0));
    });

    test('j/k keys work for navigation', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.update(const KeyMsg('j'));
      expect(group.focusedIndex, equals(1));
      group.update(const KeyMsg('k'));
      expect(group.focusedIndex, equals(0));
    });

    test('returns Unhandled at boundary without wrap', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      expect(group.update(const KeyMsg('left')), isA<Unhandled>());
      expect(group.focusedIndex, equals(0));
      group.focusIndex(2);
      expect(group.update(const KeyMsg('right')), isA<Unhandled>());
      expect(group.focusedIndex, equals(2));
    });

    test('wraps at boundary with wrapNavigation', () {
      final group = ButtonGroupModel(
        buttons: buttons,
        focused: true,
        wrapNavigation: true,
      );
      group.update(const KeyMsg('left'));
      expect(group.focusedIndex, equals(2));
      group.update(const KeyMsg('right'));
      expect(group.focusedIndex, equals(0));
    });
  });

  group('ButtonGroupModel.update button activation', () {
    late List<ButtonModel> buttons;

    setUp(() {
      buttons = [
        ButtonModel(id: 'a', label: Line('A')),
        ButtonModel(id: 'b', label: Line('B')),
      ];
    });

    test('delegates enter to focused button', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      final cmd = group.update(const KeyMsg('enter'));
      expect(cmd, isA<ButtonPressCmd>());
      expect((cmd! as ButtonPressCmd).id, equals('a'));
    });

    test('delegates to second button when focused', () {
      final group = ButtonGroupModel(
        buttons: buttons,
        focused: true,
        initialFocusIndex: 1,
      );
      final cmd = group.update(const KeyMsg('enter'));
      expect(cmd, isA<ButtonPressCmd>());
      expect((cmd! as ButtonPressCmd).id, equals('b'));
    });
  });

  group('ButtonGroupModel focus methods', () {
    late List<ButtonModel> buttons;

    setUp(() {
      buttons = [
        ButtonModel(id: 'a', label: Line('A')),
        ButtonModel(id: 'b', label: Line('B')),
        ButtonModel(id: 'c', label: Line('C')),
      ];
    });

    test('focusButton focuses by id', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.focusButton('b');
      expect(group.focusedIndex, equals(1));
      expect(buttons[1].focused, isTrue);
    });

    test('focusButton ignores unknown id', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.focusButton('unknown');
      expect(group.focusedIndex, equals(0));
    });

    test('focusIndex focuses by index', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.focusIndex(2);
      expect(group.focusedIndex, equals(2));
      expect(buttons[2].focused, isTrue);
    });

    test('focusIndex ignores out of bounds', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.focusIndex(-1);
      expect(group.focusedIndex, equals(0));
      group.focusIndex(10);
      expect(group.focusedIndex, equals(0));
    });
  });

  group('ButtonGroupModel focus state', () {
    late List<ButtonModel> buttons;

    setUp(() {
      buttons = [
        ButtonModel(id: 'a', label: Line('A')),
        ButtonModel(id: 'b', label: Line('B')),
      ];
    });

    test('remembers focused index when unfocused', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.focusIndex(1);
      expect(group.focusedIndex, equals(1));
      group.focused = false;
      expect(group.focusedIndex, equals(1));
      expect(buttons[1].focused, isFalse);
    });

    test('restores focus when refocused', () {
      final group = ButtonGroupModel(buttons: buttons, focused: true);
      group.focusIndex(1);
      group.focused = false;
      group.focused = true;
      expect(group.focusedIndex, equals(1));
      expect(buttons[1].focused, isTrue);
    });
  });
}
