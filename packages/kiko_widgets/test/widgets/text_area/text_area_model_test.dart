import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// A routed pointer message at a given local cell.
PointerMsg pointerAt(MouseButton button, {int x = 0, int y = 0}) =>
    PointerMsg(MouseEvent(x, y, button), local: Position(x, y));

void main() {
  group('TextAreaModel mouse click → caret', () {
    test('a click places the caret at the clicked (row, column)', () {
      final model = TextAreaModel(initial: 'foo\nbar\nbaz', focused: true);

      expect(model.update(pointerAt(MouseButton.down(), x: 1)), isA<Handled>());
      expect(model.cursorRow, equals(0));
      expect(model.cursorCol, equals(1));

      model.update(pointerAt(MouseButton.down(), x: 2, y: 2));
      expect(model.cursorRow, equals(2));
      expect(model.cursorCol, equals(2));
    });

    test('a click consumes without emitting a command', () {
      final model = TextAreaModel(initial: 'foo\nbar', focused: true);
      final result = model.update(pointerAt(MouseButton.down(), x: 1, y: 1));
      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a click past a line end clamps to the line length', () {
      final model = TextAreaModel(initial: 'foo\nbar', focused: true)..update(pointerAt(MouseButton.down(), x: 20));
      expect(model.cursorRow, equals(0));
      expect(model.cursorCol, equals(3), reason: "'foo' has length 3");
    });

    test('a click below the last line lands at the document end', () {
      final model = TextAreaModel(initial: 'foo\nbar\nbaz', focused: true)
        ..update(pointerAt(MouseButton.down(), y: 10));
      expect(model.cursorRow, equals(2));
      expect(model.cursorCol, equals(3));
    });

    test('a click on the right cell of a 2-wide grapheme resolves to it', () {
      // Columns on the single line: a=0, あ=1-2, b=3.
      final model = TextAreaModel(initial: 'aあb', focused: true)..update(pointerAt(MouseButton.down(), x: 2));
      expect(model.cursorCol, equals(1), reason: 'right cell still lands on あ');

      model.update(pointerAt(MouseButton.down(), x: 3));
      expect(model.cursorCol, equals(2), reason: 'b');
    });

    test('a click maps through the vertical scroll offset', () {
      final model = TextAreaModel(initial: 'l0\nl1\nl2\nl3\nl4', focused: true)
        // Cursor sits on the last line after init; window to 2 rows → scroll 3.
        ..adjustScroll(2)
        ..update(pointerAt(MouseButton.down(), x: 1));
      expect(model.cursorRow, equals(3), reason: 'local row 0 is visual row 3');
      expect(model.cursorCol, equals(1));
    });

    test('a click on an unfocused area still places the caret', () {
      final model = TextAreaModel(initial: 'foo\nbar');
      final result = model.update(pointerAt(MouseButton.down(), x: 1, y: 1));
      expect(result, isA<Handled>());
      expect(model.cursorRow, equals(1));
      expect(model.cursorCol, equals(1));
    });

    test('a wheel is declined so a scrollable ancestor gets it', () {
      final model = TextAreaModel(initial: 'foo\nbar', focused: true);
      expect(model.update(pointerAt(MouseButton.wheelDown())), isA<Declined>());
      expect(model.update(pointerAt(MouseButton.wheelUp())), isA<Declined>());
    });

    test('non-consuming pointer traffic is declined', () {
      final model = TextAreaModel(initial: 'foo', focused: true);
      expect(model.update(pointerAt(MouseButton.moved(), x: 1)), isA<Declined>());
      expect(model.update(pointerAt(MouseButton.up(), x: 1)), isA<Declined>());
      expect(model.update(const PointerLeaveMsg('x')), isA<Declined>());
      expect(model.update(const PointerCancelMsg('x')), isA<Declined>());
    });
  });
}
