// The kiko-vocabulary emit helpers are the intake translation
// (`eventToMsg`/`pointerFieldsFrom`) run in reverse: each helper builds the
// raw termparser event a real terminal would send, and this suite drives
// that event straight back through the real intake to check it lands on the
// kiko-typed value the helper name promises.
import 'package:kiko/kiko.dart';
import 'package:kiko/src/mvu/pointer_msg.dart' show pointerFieldsFrom;
import 'package:kiko/testing.dart';
import 'package:termparser/termparser_events.dart' as evt;
import 'package:test/test.dart';

/// [TestBackend.poll] is typed generically but declared to return the base
/// `evt.Event`, so every caller here narrows back to the concrete type it
/// asked to filter by.
T _poll<T extends evt.Event>(TestBackend backend) => backend.poll<T>()! as T;

void main() {
  group('emitKey', () {
    test('a plain letter round-trips to a KeyMsg with that key', () {
      final backend = TestBackend()..emitKey('q');

      final msg = eventToMsg(_poll<evt.KeyEvent>(backend));

      expect(msg, isA<KeyMsg>());
      expect((msg! as KeyMsg).key, 'q');
    });

    test('a chord round-trips through the same key spec', () {
      final backend = TestBackend()..emitKey('ctrl+a');

      final msg = eventToMsg(_poll<evt.KeyEvent>(backend))! as KeyMsg;

      expect(msg.key, 'ctrl+a');
      expect(msg.repeat, isFalse);
    });

    test('parses specs through the same grammar KeyBinding canonicalizes with', () {
      final backend = TestBackend()..emitKey('shift+a');

      final msg = eventToMsg(_poll<evt.KeyEvent>(backend))! as KeyMsg;
      final binding = KeyBinding<int>()..map(['shift+a'], 1);

      // 'shift+a' and 'A' fold to the same binding — proof the helper and
      // KeyBinding agree on canonicalization, not just on the raw spelling.
      expect(msg.key, 'A');
      expect(binding.resolve(msg), 1);
    });
  });

  group('emitClick', () {
    test('emits a down then an up at the same cell, mapping back to button and modifiers', () {
      final backend = TestBackend()..emitClick(3, 5, button: PointerButton.right, ctrl: true);

      final down = _poll<evt.MouseEvent>(backend);
      final up = _poll<evt.MouseEvent>(backend);

      expect(down.x, 3);
      expect(down.y, 5);
      final downFields = pointerFieldsFrom(down);
      expect(downFields.action, PointerAction.down);
      expect(downFields.button, PointerButton.right);
      expect(downFields.ctrl, isTrue);
      expect(downFields.shift, isFalse);
      expect(downFields.alt, isFalse);

      expect(up.x, 3);
      expect(up.y, 5);
      final upFields = pointerFieldsFrom(up);
      expect(upFields.action, PointerAction.up);
      expect(upFields.button, PointerButton.right);
      expect(upFields.ctrl, isTrue);
    });

    test('defaults to the left button with no modifiers', () {
      final backend = TestBackend()..emitClick(0, 0);

      final down = pointerFieldsFrom(_poll<evt.MouseEvent>(backend));

      expect(down.button, PointerButton.left);
      expect(down.shift, isFalse);
      expect(down.ctrl, isFalse);
      expect(down.alt, isFalse);
    });

    test("PointerButton.none maps to termparser's bare down/up", () {
      final backend = TestBackend()..emitClick(0, 0, button: PointerButton.none);

      final down = pointerFieldsFrom(_poll<evt.MouseEvent>(backend));

      expect(down.button, PointerButton.none);
    });
  });

  group('emitMove', () {
    test('is a move with no button', () {
      final backend = TestBackend()..emitMove(7, 2);

      final event = _poll<evt.MouseEvent>(backend);
      expect(event.x, 7);
      expect(event.y, 2);
      final fields = pointerFieldsFrom(event);
      expect(fields.action, PointerAction.move);
      expect(fields.button, PointerButton.none);
    });
  });

  group('emitDrag', () {
    test('is motion with the button held and modifiers set', () {
      final backend = TestBackend()..emitDrag(1, 1, button: PointerButton.middle, shift: true);

      final fields = pointerFieldsFrom(_poll<evt.MouseEvent>(backend));

      expect(fields.action, PointerAction.drag);
      expect(fields.button, PointerButton.middle);
      expect(fields.shift, isTrue);
    });
  });

  group('emitWheel', () {
    test('positive deltaY emits that many wheel-down notches', () {
      final backend = TestBackend()..emitWheel(2, 3, deltaY: 2);

      final first = pointerFieldsFrom(_poll<evt.MouseEvent>(backend));
      final second = pointerFieldsFrom(_poll<evt.MouseEvent>(backend));

      expect(first.action, PointerAction.wheelDown);
      expect(second.action, PointerAction.wheelDown);
      expect(backend.poll<evt.MouseEvent>(), isNull, reason: 'exactly two notches, no more');
    });

    test('negative deltaY emits wheel-up notches', () {
      final backend = TestBackend()..emitWheel(0, 0, deltaY: -1);

      final fields = pointerFieldsFrom(_poll<evt.MouseEvent>(backend));

      expect(fields.action, PointerAction.wheelUp);
    });

    test('positive deltaX emits wheel-right, negative emits wheel-left', () {
      final right = TestBackend()..emitWheel(0, 0, deltaX: 1);
      final left = TestBackend()..emitWheel(0, 0, deltaX: -1);

      expect(pointerFieldsFrom(_poll<evt.MouseEvent>(right)).action, PointerAction.wheelRight);
      expect(pointerFieldsFrom(_poll<evt.MouseEvent>(left)).action, PointerAction.wheelLeft);
    });

    test('carries the cell and the modifiers onto every notch', () {
      final backend = TestBackend()..emitWheel(4, 6, deltaY: 1, alt: true);

      final event = _poll<evt.MouseEvent>(backend);
      expect(event.x, 4);
      expect(event.y, 6);
      expect(pointerFieldsFrom(event).alt, isTrue);
    });

    test('asserts when both deltas are zero', () {
      final backend = TestBackend();

      expect(() => backend.emitWheel(0, 0), throwsA(isA<AssertionError>()));
    });
  });

  group('emitPaste', () {
    test('round-trips to a PasteMsg with the pasted text', () {
      final backend = TestBackend()..emitPaste('hello');

      final msg = eventToMsg(_poll<evt.PasteEvent>(backend));

      expect(msg, isA<PasteMsg>());
      expect((msg! as PasteMsg).text, 'hello');
    });
  });

  group('emitFocus', () {
    test('round-trips to a FocusMsg carrying hasFocus', () {
      final gained = TestBackend()..emitFocus(hasFocus: true);
      final lost = TestBackend()..emitFocus(hasFocus: false);

      final gainedMsg = eventToMsg(_poll<evt.FocusEvent>(gained));
      final lostMsg = eventToMsg(_poll<evt.FocusEvent>(lost));

      expect(gainedMsg, isA<FocusMsg>());
      expect((gainedMsg! as FocusMsg).hasFocus, isTrue);
      expect((lostMsg! as FocusMsg).hasFocus, isFalse);
    });
  });
}
