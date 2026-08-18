import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg for a named key.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// Helper to create a KeyMsg for a plain typed character.
KeyMsg charMsg(String c) => KeyMsg(c, text: c);

/// A routed button-down addressed to [targetId], on no marked part.
PointerMsg pressOn(String targetId) =>
    PointerMsg(global: Position.origin, action: PointerAction.down, local: Position.origin, targetId: targetId);

/// A routed move addressed to [targetId] — not a press.
PointerMsg moveOn(String targetId) =>
    PointerMsg(global: Position.origin, action: PointerAction.move, local: Position.origin, targetId: targetId);

void main() {
  group('ComboboxModel', () {
    ComboboxModel<String> fruitBox({
      List<String> options = const ['Apple', 'Banana', 'Cherry', 'Date'],
      String? value,
      bool focused = true,
    }) => ComboboxModel<String>(
      id: 'combo',
      fieldId: 'combo-field',
      toggleId: 'combo-toggle',
      label: (s) => s,
      options: options,
      value: value,
      focused: focused,
    );

    group('construction', () {
      test('default state is closed with an empty field', () {
        final combo = fruitBox();
        expect(combo.isOpen, isFalse);
        expect(combo.value, isNull);
        expect(combo.field.value, isEmpty);
        expect(combo.maxVisibleRows, equals(5));
      });

      test('a preselected value seeds the field with its label', () {
        final combo = fruitBox(value: 'Cherry');
        expect(combo.field.value, equals('Cherry'));
        expect(combo.value, equals('Cherry'));
      });

      test('a custom matches override replaces the default contains rule', () {
        final combo = ComboboxModel<int>(
          id: 'nums',
          fieldId: 'nums-field',
          toggleId: 'nums-toggle',
          label: (n) => n.toString(),
          matches: (n, query) => query.isNotEmpty && n.toString().endsWith(query),
          options: const [1, 21, 31, 42],
          focused: true,
        )..update(charMsg('1'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals(1), reason: '1, 21 and 31 all end with "1"; the first match commits');
      });
    });

    group('opening', () {
      test('a text-editing key while closed opens the popup and inserts', () {
        final combo = fruitBox();
        final result = combo.update(charMsg('a'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
        expect(combo.field.value, equals('a'));
      });

      test('down while closed opens unfiltered, leaving the field untouched', () {
        final combo = fruitBox();
        final result = combo.update(keyMsg('down'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
        expect(combo.field.value, isEmpty);
      });

      test('a toggle press opens the popup while closed', () {
        final combo = fruitBox();
        final result = combo.update(pressOn('combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
      });

      test('a toggle press works even when the combobox itself is unfocused', () {
        final combo = fruitBox(focused: false);
        final result = combo.update(pressOn('combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
      });

      test('a toggle press resolves through a scoped path by its leaf id', () {
        final combo = fruitBox();
        final result = combo.update(pressOn('combo/combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
      });

      test('a non-down pointer on the toggle is declined', () {
        expect(fruitBox().update(moveOn('combo-toggle')), isA<Declined>());
      });

      test('a navigation key with nothing bound (e.g. tab) is declined while closed', () {
        expect(fruitBox().update(keyMsg('tab')), isA<Declined>());
      });
    });

    group('closed keys the app keeps', () {
      test('enter is declined while closed', () {
        expect(fruitBox().update(keyMsg('enter')), isA<Declined>());
      });

      test('escape is declined while closed', () {
        expect(fruitBox().update(keyMsg('escape')), isA<Declined>());
      });
    });

    group('toggle closes an open popup', () {
      test('a toggle press while open closes and restores the committed label', () {
        final combo = fruitBox(value: 'Banana')..update(keyMsg('down'));

        final result = combo.update(pressOn('combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isFalse);
        expect(combo.field.value, equals('Banana'));
      });
    });

    group('open-key forwarding', () {
      test('down moves the popup cursor forward', () {
        final combo = fruitBox()
          ..update(keyMsg('down')) // opens, cursor on row 0 (Apple)
          ..update(keyMsg('down')); // cursor on row 1 (Banana)

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Banana'));
      });

      test('up moves the popup cursor back', () {
        final combo = fruitBox()
          ..update(keyMsg('down'))
          ..update(keyMsg('down'))
          ..update(keyMsg('down')) // cursor on row 2 (Cherry)
          ..update(keyMsg('up')) // cursor on row 1 (Banana)
          ..update(keyMsg('enter'));

        expect(combo.value, equals('Banana'));
      });

      test('pageDown moves the cursor by the seeded visible count', () {
        final combo = fruitBox()
          ..update(keyMsg('down'))
          ..setVisibleCount(2)
          ..update(keyMsg('pageDown')) // cursor row 0 + 2 = row 2 (Cherry)
          ..update(keyMsg('enter'));

        expect(combo.value, equals('Cherry'));
      });

      test('pageUp moves the cursor back by the seeded visible count', () {
        final combo = fruitBox()
          ..update(keyMsg('down'))
          ..setVisibleCount(2)
          ..update(keyMsg('pageDown')) // row 2
          ..update(keyMsg('pageUp')) // row 0
          ..update(keyMsg('enter'));

        expect(combo.value, equals('Apple'));
      });
    });

    group('filtering', () {
      test('typing narrows the popup and re-seeds with the cursor on the first match', () {
        final combo = fruitBox()
          ..update(charMsg('C'))
          ..update(charMsg('h'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Cherry'));
        expect(combo.field.value, equals('Cherry'));
        expect(combo.isOpen, isFalse);
      });

      test('a filter change resets the cursor to the first match, even with a value selected', () {
        final combo = fruitBox(value: 'Date')..update(charMsg('a'));

        // Case-insensitive contains 'a': Apple, Banana, Date all match, in list
        // order — the filter ignores the prior value entirely.
        final result = combo.update(keyMsg('enter'));
        expect(combo.value, equals('Apple'));
        expect(result, isA<Handled>());
      });
    });

    group('opening without editing', () {
      test('places the cursor on the current value, not the first row', () {
        final combo = fruitBox(value: 'Cherry')..update(keyMsg('down'));

        // An unmoved commit lands on whatever row the cursor opened on.
        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Cherry'));
      });

      test('lands on the first row when no value stands', () {
        final combo = fruitBox()..update(keyMsg('down'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>());
        expect(combo.value, equals('Apple'));
      });
    });

    group('commit', () {
      test('commit with no cursor row (empty options) is a bare Handled', () {
        final combo = fruitBox(options: const [])..update(keyMsg('down'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(combo.value, isNull);
        expect(combo.isOpen, isTrue, reason: 'nothing was committed, so nothing closes');
      });

      test('the emitted command addresses the combobox, never the embedded list', () {
        final combo = fruitBox()..update(keyMsg('down'));

        final result = combo.update(keyMsg('enter')) as Handled;
        final cmd = result.cmd! as ComboboxSelectCmd;
        expect(cmd.id, equals('combo'));
        expect(cmd, isNot(isA<ListActionCmd>()));
      });
    });

    group('escape restores', () {
      test('esc while open restores the committed label and closes, committing nothing', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(keyMsg('down')); // cursor now on Cherry, uncommitted

        final result = combo.update(keyMsg('escape'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isFalse);
        expect(combo.field.value, equals('Banana'));
        expect(combo.value, equals('Banana'));
      });

      test('esc with no prior value restores the field to empty', () {
        final combo = fruitBox()
          ..update(charMsg('a'))
          ..update(keyMsg('escape'));

        expect(combo.field.value, isEmpty);
        expect(combo.value, isNull);
      });
    });

    group('first edit over a committed label', () {
      test('replaces the label instead of appending to it, while closed', () {
        final combo = fruitBox(value: 'Banana');

        final result = combo.update(charMsg('x'));

        expect(result, isA<Handled>());
        expect(combo.field.value, equals('x'));
      });

      test('replaces the label instead of appending to it, once opened unfiltered', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(charMsg('x'));

        expect(combo.field.value, equals('x'));
      });

      test('a second edit appends normally', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(charMsg('x'))
          ..update(charMsg('y'));

        expect(combo.field.value, equals('xy'));
      });
    });

    group('focus loss', () {
      test('closes the popup and restores the committed label without committing', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(keyMsg('down')) // cursor moved, nothing committed
          ..focused = false;

        expect(combo.isOpen, isFalse);
        expect(combo.field.value, equals('Banana'));
        expect(combo.value, equals('Banana'));
        expect(combo.field.focused, isFalse);
      });

      test('regaining focus mirrors onto the field', () {
        final combo = fruitBox()
          ..focused = false
          ..focused = true;

        expect(combo.field.focused, isTrue);
      });
    });

    group('clear', () {
      test('clears the value and empties the field', () {
        final combo = fruitBox(value: 'Banana')..clear();

        expect(combo.value, isNull);
        expect(combo.field.value, isEmpty);
      });
    });

    group('field pointer forwarding', () {
      test('a press addressed to the field leaf places the caret', () {
        final combo = fruitBox(value: 'Banana');
        final press = PointerMsg(
          global: const Position(2, 0),
          action: PointerAction.down,
          local: const Position(2, 0),
          targetId: 'combo-field',
          targetRect: Rect.create(x: 0, y: 0, width: 10, height: 1),
        );

        final result = combo.update(press);

        expect(result, isA<Handled>());
        expect(combo.field.cursor, equals(2));
      });

      test('a pointer addressed to neither part is declined', () {
        expect(fruitBox().update(pressOn('somewhere-else')), isA<Declined>());
      });

      test('a pointer with no target at all is declined', () {
        final combo = fruitBox();
        const noTarget = PointerMsg(global: Position.origin, action: PointerAction.down, local: Position.origin);
        expect(combo.update(noTarget), isA<Declined>());
      });
    });

    group('unfocused', () {
      test('declines a key', () {
        expect(fruitBox(focused: false).update(keyMsg('down')), isA<Declined>());
      });
    });

    group('unknown messages', () {
      test('declines a message it does not know', () {
        expect(fruitBox().update(const NoneMsg()), isA<Declined>());
      });

      test('declines a pointer leave and a pointer cancel', () {
        final combo = fruitBox();
        expect(combo.update(const PointerLeaveMsg('combo-field')), isA<Declined>());
        expect(combo.update(const PointerCancelMsg('combo-field')), isA<Declined>());
      });
    });
  });
}
