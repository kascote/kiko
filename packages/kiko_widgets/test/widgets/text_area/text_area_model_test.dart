import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// A routed pointer message at a given local cell.
PointerMsg pointerAt(PointerAction action, {int x = 0, int y = 0}) =>
    PointerMsg(global: Position(x, y), action: action, local: Position(x, y));

void main() {
  group('TextAreaModel.update character input', () {
    test('character input inserts at cursor', () {
      final model = TextAreaModel(focused: true)..update(const KeyMsg('a', text: 'a'));
      expect(model.value, equals('a'));
    });

    test('space key inserts a literal space', () {
      final model = TextAreaModel(focused: true)
        ..update(const KeyMsg('a', text: 'a'))
        ..update(const KeyMsg('space', text: ' '))
        ..update(const KeyMsg('b', text: 'b'));
      expect(model.value, equals('a b'));
    });

    test('plus and minus keys insert their literal characters', () {
      final model = TextAreaModel(focused: true)
        ..update(const KeyMsg('plus', text: '+'))
        ..update(const KeyMsg('minus', text: '-'));
      expect(model.value, equals('+-'));
    });

    test('a dead-key composition (multi-codepoint, single grapheme) inserts as one grapheme', () {
      // 'e' + combining acute accent — a decomposed é, the shape a dead-key
      // sequence (or option+e then e on macOS) can produce as one kitty text
      // field, two UTF-16 code units, one grapheme cluster.
      const composed = 'é';
      final model = TextAreaModel(focused: true)..update(const KeyMsg('e', text: composed));
      expect(model.value, equals(composed));
      expect(model.length, equals(1), reason: 'the combining sequence is a single grapheme cluster');
    });

    test('a keystroke whose text is multiple graphemes inserts the whole string at once', () {
      // The kitty text field is not contractually one grapheme — a compose
      // sequence can hand back more than one character in a single keystroke.
      // textArea.insert splits on graphemes internally, so both land in one call.
      final model = TextAreaModel(focused: true)..update(const KeyMsg('a', text: 'ab'));
      expect(model.value, equals('ab'));
      expect(model.length, equals(2));
    });
  });

  group('TextAreaModel tab / shift+tab', () {
    test('tab is declined under default bindings', () {
      final model = TextAreaModel(focused: true);
      expect(model.update(const KeyMsg('tab')), isA<Declined>());
      expect(model.value, isEmpty);
    });

    test('shift+tab is declined under default bindings', () {
      final model = TextAreaModel(focused: true);
      expect(model.update(const KeyMsg('shift+tab')), isA<Declined>());
      expect(model.value, isEmpty);
    });

    test('opting in maps tab to inserting tabWidth spaces', () {
      final model = TextAreaModel(
        focused: true,
        keyBinding: defaultTextAreaBindings.copy()..map(['tab'], TextAreaAction.tab),
      );
      expect(model.update(const KeyMsg('tab')), isA<Handled>());
      expect(model.value, equals(' ' * model.tabWidth));
    });

    test('opting in still declines shift+tab (no action bound)', () {
      final model = TextAreaModel(
        focused: true,
        keyBinding: defaultTextAreaBindings.copy()..map(['tab'], TextAreaAction.tab),
      );
      expect(model.update(const KeyMsg('shift+tab')), isA<Declined>());
    });
  });

  group('TextAreaModel mouse click → caret', () {
    test('a click places the caret at the clicked (row, column)', () {
      final model = TextAreaModel(initial: 'foo\nbar\nbaz', focused: true);

      expect(model.update(pointerAt(PointerAction.down, x: 1)), isA<Handled>());
      expect(model.cursorRow, equals(0));
      expect(model.cursorCol, equals(1));

      model.update(pointerAt(PointerAction.down, x: 2, y: 2));
      expect(model.cursorRow, equals(2));
      expect(model.cursorCol, equals(2));
    });

    test('a click consumes without emitting a command', () {
      final model = TextAreaModel(initial: 'foo\nbar', focused: true);
      final result = model.update(pointerAt(PointerAction.down, x: 1, y: 1));
      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a click past a line end clamps to the line length', () {
      final model = TextAreaModel(initial: 'foo\nbar', focused: true)..update(pointerAt(PointerAction.down, x: 20));
      expect(model.cursorRow, equals(0));
      expect(model.cursorCol, equals(3), reason: "'foo' has length 3");
    });

    test('a click below the last line lands at the document end', () {
      final model = TextAreaModel(initial: 'foo\nbar\nbaz', focused: true)
        ..update(pointerAt(PointerAction.down, y: 10));
      expect(model.cursorRow, equals(2));
      expect(model.cursorCol, equals(3));
    });

    test('a click on the right cell of a 2-wide grapheme resolves to it', () {
      // Columns on the single line: a=0, あ=1-2, b=3.
      final model = TextAreaModel(initial: 'aあb', focused: true)..update(pointerAt(PointerAction.down, x: 2));
      expect(model.cursorCol, equals(1), reason: 'right cell still lands on あ');

      model.update(pointerAt(PointerAction.down, x: 3));
      expect(model.cursorCol, equals(2), reason: 'b');
    });

    test('a click maps through the vertical scroll offset', () {
      final model = TextAreaModel(initial: 'l0\nl1\nl2\nl3\nl4', focused: true)
        // Cursor sits on the last line after init; window to 2 rows → scroll 3.
        ..adjustScroll(2)
        ..update(pointerAt(PointerAction.down, x: 1));
      expect(model.cursorRow, equals(3), reason: 'local row 0 is visual row 3');
      expect(model.cursorCol, equals(1));
    });

    test('a click on an unfocused area still places the caret', () {
      final model = TextAreaModel(initial: 'foo\nbar');
      final result = model.update(pointerAt(PointerAction.down, x: 1, y: 1));
      expect(result, isA<Handled>());
      expect(model.cursorRow, equals(1));
      expect(model.cursorCol, equals(1));
    });

    test('a wheel is declined so a scrollable ancestor gets it', () {
      final model = TextAreaModel(initial: 'foo\nbar', focused: true);
      expect(model.update(pointerAt(PointerAction.wheelDown)), isA<Declined>());
      expect(model.update(pointerAt(PointerAction.wheelUp)), isA<Declined>());
    });

    test('non-consuming pointer traffic is declined', () {
      final model = TextAreaModel(initial: 'foo', focused: true);
      expect(model.update(pointerAt(PointerAction.move, x: 1)), isA<Declined>());
      expect(model.update(pointerAt(PointerAction.up, x: 1)), isA<Declined>());
      expect(model.update(const PointerLeaveMsg('x')), isA<Declined>());
      expect(model.update(const PointerCancelMsg('x')), isA<Declined>());
    });
  });

  group('TextAreaModel.update key release / bare modifier', () {
    test('a release of the just-pressed key is declined and never doubles the character', () {
      // The regression this whole delivery kills: KeyMsg and KeyReleaseMsg
      // are siblings, not variants of one class, so a release can never
      // pattern-match as a keystroke and reach the insert path.
      final model = TextAreaModel(focused: true)..update(const KeyMsg('a', text: 'a'));
      expect(model.value, equals('a'));

      final result = model.update(const KeyReleaseMsg('a'));

      expect(result, isA<Declined>());
      expect(model.value, equals('a'), reason: 'a release must never insert a second character');
    });

    test('a bare modifier key edge is declined and inserts nothing', () {
      final model = TextAreaModel(focused: true);

      final result = model.update(const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true));

      expect(result, isA<Declined>());
      expect(model.value, isEmpty);
    });
  });
}
