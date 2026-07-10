import 'package:kiko/src/backend/termlib_backend.dart';
import 'package:termparser/termparser_events.dart' as tle;
import 'package:test/test.dart';

const _left = tle.MouseButton(tle.MouseButtonKind.left, tle.MouseButtonAction.down);
const _up = tle.MouseButton(tle.MouseButtonKind.none, tle.MouseButtonAction.up);

void main() {
  group('toBufferCoords', () {
    test('moves a mouse event from the terminal origin to the buffer origin', () {
      final translated = toBufferCoords(const tle.MouseEvent(1, 1, _left));

      expect(translated, const tle.MouseEvent(0, 0, _left));
    });

    test('translates both axes independently', () {
      final translated = toBufferCoords(const tle.MouseEvent(11, 4, _left));

      expect(translated, const tle.MouseEvent(10, 3, _left));
    });

    test('carries the button and modifiers through untouched', () {
      final modifiers = tle.KeyModifiers.ctrl | tle.KeyModifiers.shift;

      final translated = toBufferCoords(tle.MouseEvent(3, 7, _left, modifiers: modifiers));

      expect(translated, tle.MouseEvent(2, 6, _left, modifiers: modifiers));
    });

    test('translates a release at the terminal origin', () {
      final translated = toBufferCoords(const tle.MouseEvent(1, 1, _up));

      expect(translated, const tle.MouseEvent(0, 0, _up));
    });

    test('translates a wheel event, whose button kind is meaningless', () {
      const wheel = tle.MouseButton(tle.MouseButtonKind.none, tle.MouseButtonAction.wheelUp);

      final translated = toBufferCoords(const tle.MouseEvent(1, 1, wheel));

      expect(translated, const tle.MouseEvent(0, 0, wheel));
    });

    test('translates a cursor-position reply, which the stream also broadcasts', () {
      final translated = toBufferCoords(const tle.CursorPositionEvent(1, 1));

      expect(translated, const tle.CursorPositionEvent(0, 0));
    });

    test('passes a key event through identically', () {
      const event = tle.KeyEvent(tle.KeyCode.named(tle.KeyCodeName.enter));

      expect(toBufferCoords(event), same(event));
    });

    test('passes a focus event through identically', () {
      const event = tle.FocusEvent();

      expect(toBufferCoords(event), same(event));
    });

    test('passes a paste event through identically', () {
      const event = tle.PasteEvent('hello');

      expect(toBufferCoords(event), same(event));
    });

    test('leaves a resize event alone, because sizes are counts not coordinates', () {
      const event = tle.WindowResizeEvent(24, 80);

      expect(toBufferCoords(event), same(event));
    });
  });
}
