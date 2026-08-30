import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// A pointer over a 6×1 checkbox at the origin, addressed to `'cb'`.
///
/// `local` doubles as the in-checkbox position, so `inside` follows from
/// [x]/[y]: an [x] past the 6-cell width models a captured release slid off
/// the checkbox.
PointerMsg pointerAt(PointerAction action, {int x = 0, int y = 0}) => PointerMsg(
  global: Position(x, y),
  action: action,
  local: Position(x, y),
  targetId: 'cb',
  targetRect: Rect.create(x: 0, y: 0, width: 6, height: 1),
);

void main() {
  group('CheckboxModel', () {
    test('default state', () {
      final checkbox = CheckboxModel(label: Line('Remember me'));
      expect(checkbox.id, startsWith('checkbox-'));
      expect(checkbox.state, equals(CheckState.unchecked));
      expect(checkbox.checked, isFalse);
      expect(checkbox.mixed, isFalse);
      expect(checkbox.disabled, isFalse);
      expect(checkbox.error, isFalse);
      expect(checkbox.focused, isFalse);
      expect(checkbox.labelFirst, isFalse);
      expect(checkbox.labelAlign, equals(TextAlign.start));
      expect(checkbox.glyphs, equals(CheckGlyphs.ascii));
      expect(checkbox.styles, equals(const CheckboxStyle()));
    });

    test('the checked setter clears mixed', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), state: CheckState.mixed)..checked = true;
      expect(checkbox.state, equals(CheckState.checked));
      expect(checkbox.mixed, isFalse);

      checkbox
        ..state = CheckState.mixed
        ..checked = false;
      expect(checkbox.state, equals(CheckState.unchecked));
    });

    test('a state write wins over an earlier checked write, and the reverse', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'))
        ..checked = true
        ..state = CheckState.mixed;
      expect(checkbox.state, equals(CheckState.mixed));

      checkbox
        ..state = CheckState.mixed
        ..checked = true;
      expect(checkbox.state, equals(CheckState.checked));
    });
  });

  group('CheckboxModel.toggle', () {
    test('unchecked becomes checked', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'))..toggle();
      expect(checkbox.state, equals(CheckState.checked));
    });

    test('checked becomes unchecked', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), state: CheckState.checked)..toggle();
      expect(checkbox.state, equals(CheckState.unchecked));
    });

    test('mixed becomes checked', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), state: CheckState.mixed)..toggle();
      expect(checkbox.state, equals(CheckState.checked));
    });

    test('a direct call is silent: it only flips state', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'))
        ..toggle()
        ..toggle();
      expect(checkbox.state, equals(CheckState.unchecked));
      expect(checkbox.pressed, isFalse);
      expect(checkbox.hovered, isFalse);
    });
  });

  group('CheckboxModel.update key', () {
    test('space toggles and emits with the new value', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), focused: true);
      final result = checkbox.update(const KeyMsg('space'));
      expect(checkbox.checked, isTrue);
      expect(result, isA<Handled>());
      final event = (result as Handled).events.single;
      expect(event, isA<CheckboxChangeEvent>());
      expect((event as CheckboxChangeEvent).id, equals('cb'));
      expect(event.checked, isTrue);
    });

    test('enter declines', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), focused: true);
      expect(checkbox.update(const KeyMsg('enter')), isA<Declined>());
      expect(checkbox.checked, isFalse);
    });

    test('disabled consumes space silently and keeps the value', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), focused: true, disabled: true);
      final result = checkbox.update(const KeyMsg('space'));
      expect(result, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(checkbox.checked, isFalse);
    });

    test('unfocused declines space', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'));
      expect(checkbox.update(const KeyMsg('space')), isA<Declined>());
      expect(checkbox.checked, isFalse);
    });

    test('custom key bindings work', () {
      final customBindings = KeyBinding<CheckboxAction>()..map(['enter'], CheckboxAction.toggle);
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), focused: true, keyBinding: customBindings);

      expect(
        checkbox.update(const KeyMsg('enter')),
        isA<Handled>().having((h) => h.events, 'events', [isA<CheckboxChangeEvent>()]),
      );
      expect(checkbox.update(const KeyMsg('space')), isA<Declined>());
    });
  });

  group('CheckboxModel.update pointer', () {
    // Unfocused throughout: a click works whether or not the checkbox has
    // focus (the app focuses it on the down); the pointer branch sits above
    // the gate.
    test('down then up inside toggles and emits', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'));

      final down = checkbox.update(pointerAt(PointerAction.down, x: 2));
      expect(down, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(checkbox.pressed, isTrue);

      final up = checkbox.update(pointerAt(PointerAction.up, x: 2));
      expect(checkbox.pressed, isFalse);
      expect(checkbox.checked, isTrue);
      expect(up, isA<Handled>());
      final event = (up as Handled).events.single;
      expect(event, isA<CheckboxChangeEvent>());
      expect((event as CheckboxChangeEvent).id, equals('cb'));
      expect(event.checked, isTrue);
    });

    test('down then up outside does not toggle', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'))..update(pointerAt(PointerAction.down, x: 2));
      expect(checkbox.pressed, isTrue);

      // Captured: the cursor left the 6-cell checkbox, so the up lands outside.
      final up = checkbox.update(pointerAt(PointerAction.up, x: 20));
      expect(checkbox.pressed, isFalse);
      expect(checkbox.checked, isFalse);
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));
    });

    test('cancel ends the gesture without toggling', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'))..update(pointerAt(PointerAction.down, x: 2));
      expect(checkbox.pressed, isTrue);

      final cancelled = checkbox.update(const PointerCancelMsg('cb'));
      expect(checkbox.pressed, isFalse);
      expect(checkbox.checked, isFalse);
      expect(cancelled, isA<Handled>().having((h) => h.events, 'events', isEmpty));
    });

    test('a move sets hover, a leave clears it', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'));
      expect(checkbox.hovered, isFalse);

      checkbox.update(pointerAt(PointerAction.move, x: 2));
      expect(checkbox.hovered, isTrue);

      checkbox.update(const PointerLeaveMsg('cb'));
      expect(checkbox.hovered, isFalse);
    });

    test('the wheel is declined so a scrollable ancestor gets it', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'));
      expect(checkbox.update(pointerAt(PointerAction.wheelDown)), isA<Declined>());
      expect(checkbox.update(pointerAt(PointerAction.wheelUp)), isA<Declined>());
      expect(checkbox.pressed, isFalse);
    });

    test('a disabled checkbox consumes the pointer and never hovers', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'), disabled: true);

      final down = checkbox.update(pointerAt(PointerAction.down, x: 2));
      expect(checkbox.pressed, isFalse);
      expect(down, isA<Handled>().having((h) => h.events, 'events', isEmpty));

      final up = checkbox.update(pointerAt(PointerAction.up, x: 2));
      expect(checkbox.checked, isFalse);
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));

      checkbox.update(pointerAt(PointerAction.move, x: 2));
      expect(checkbox.hovered, isFalse);
    });
  });

  group('CheckboxModel.width', () {
    test('ascii: a 3-cell box', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('Remember me'));
      // box '[ ]' (3) + gap (1) + label (11) = 15
      expect(checkbox.width(const TermUnicodeMeasurer()), equals(15));
    });

    test('ballot: a 1-cell box', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('Remember me'), glyphs: CheckGlyphs.ballot);
      // box '☐' (1) + gap (1) + label (11) = 13
      expect(checkbox.width(const TermUnicodeMeasurer()), equals(13));
    });

    test('emoji: a 2-cell box', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('Remember me'), glyphs: CheckGlyphs.emoji);
      // box '⬜' (2) + gap (1) + label (11) = 14
      expect(checkbox.width(const TermUnicodeMeasurer()), equals(14));
    });
  });

  group('CheckGlyphs.markWidth', () {
    test('pads to the widest mark', () {
      // The unchecked mark stays the one-cell default, so the box pads it
      // to the two-cell check mark.
      const glyphs = CheckGlyphs(checked: '✅');
      expect(glyphs.markWidth(const TermUnicodeMeasurer()), equals(2));
    });
  });

  group('CheckGlyphs presets', () {
    // Pinned against the spec's table so a glyph or width regression shows.
    const measurer = TermUnicodeMeasurer();

    void expectWidths(CheckGlyphs glyphs, {required int mark, required int box}) {
      expect(glyphs.markWidth(measurer), equals(mark));
      expect(glyphs.boxWidth(measurer), equals(box));
    }

    test('ascii: 1-cell marks, bracketed to a 3-cell box', () {
      expectWidths(CheckGlyphs.ascii, mark: 1, box: 3);
    });

    test('check: 1-cell marks, bracketed to a 3-cell box', () {
      expectWidths(CheckGlyphs.check, mark: 1, box: 3);
    });

    test('block: 1-cell marks, bracketed to a 3-cell box', () {
      expectWidths(CheckGlyphs.block, mark: 1, box: 3);
    });

    test('ballot: 1-cell marks, no brackets, a 1-cell box', () {
      expectWidths(CheckGlyphs.ballot, mark: 1, box: 1);
    });

    test('square: 1-cell marks, no brackets, a 1-cell box', () {
      expectWidths(CheckGlyphs.square, mark: 1, box: 1);
    });

    test('emoji: 2-cell marks, no brackets, a 2-cell box', () {
      expectWidths(CheckGlyphs.emoji, mark: 2, box: 2);
    });
  });

  group('CheckboxModel Focusable', () {
    test('implements Focusable', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'));
      expect(checkbox, isA<Focusable>());
    });

    test('focus can be set', () {
      final checkbox = CheckboxModel(id: 'cb', label: Line('x'));
      expect(checkbox.focused, isFalse);

      checkbox.focused = true;
      expect(checkbox.focused, isTrue);

      checkbox.focused = false;
      expect(checkbox.focused, isFalse);
    });
  });
}
