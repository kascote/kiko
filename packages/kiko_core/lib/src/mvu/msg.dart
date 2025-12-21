import 'package:characters/characters.dart';
import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart' as evt;

/// Base class for all messages in MVU architecture.
///
/// Messages trigger state updates in the update function.
abstract class Msg {
  /// Creates a Msg.
  const Msg();
}

/// Key event types.
enum KeyEventType {
  /// Key was pressed.
  press,

  /// Key is being held (repeat).
  repeat,

  /// Key was released.
  release,
}

/// Wrapper for keyboard events.
@immutable
class KeyMsg extends Msg {
  /// The key string (e.g., 'ctrl+a', 'enter', 'q').
  final String key;

  /// The event type.
  final KeyEventType type;

  /// Creates a KeyMsg for key press (default).
  const KeyMsg(this.key, {this.type = KeyEventType.press});

  /// Creates a KeyMsg for key release.
  const KeyMsg.release(this.key) : type = KeyEventType.release;

  /// Creates a KeyMsg for key repeat.
  const KeyMsg.repeat(this.key) : type = KeyEventType.repeat;

  /// Returns the character if key is a single grapheme, null otherwise.
  String? get char => key.characters.length == 1 ? key : null;

  @override
  bool operator ==(Object other) => identical(this, other) || other is KeyMsg && key == other.key && type == other.type;

  @override
  int get hashCode => Object.hash(key, type);
}

/// Wrapper for mouse events.
@immutable
class MouseMsg extends Msg {
  /// The underlying mouse event.
  final evt.MouseEvent mouse;

  /// Creates a MouseMsg from a MouseEvent.
  const MouseMsg(this.mouse);

  /// X coordinate of mouse event.
  int get x => mouse.x;

  /// Y coordinate of mouse event.
  int get y => mouse.y;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MouseMsg && mouse == other.mouse;

  @override
  int get hashCode => mouse.hashCode;
}

/// Wrapper for focus events.
@immutable
class FocusMsg extends Msg {
  /// The underlying focus event.
  final evt.FocusEvent focus;

  /// Creates a FocusMsg from a FocusEvent.
  const FocusMsg(this.focus);

  /// Whether the terminal has focus.
  bool get hasFocus => focus.hasFocus;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FocusMsg && focus == other.focus;

  @override
  int get hashCode => focus.hashCode;
}

/// Wrapper for paste events.
@immutable
class PasteMsg extends Msg {
  /// The underlying paste event.
  final evt.PasteEvent paste;

  /// Creates a PasteMsg from a PasteEvent.
  const PasteMsg(this.paste);

  /// The pasted text.
  String get text => paste.text;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PasteMsg && paste == other.paste;

  @override
  int get hashCode => paste.hashCode;
}

/// Message sent when event polling times out (no input).
class NoneMsg extends Msg {
  /// Creates a NoneMsg.
  const NoneMsg();
}

/// Message sent once at application startup before first render.
///
/// Allows update function to return initial commands (fetch data, start timer).
class InitMsg extends Msg {
  /// Creates an InitMsg.
  const InitMsg();
}

/// Message sent on each tick interval.
class TickMsg extends Msg {
  /// Total time elapsed since Tick command was issued.
  final Duration elapsed;

  /// Creates a TickMsg.
  const TickMsg(this.elapsed);
}

/// Wrapper for unknown/unhandled events.
class UnknownMsg extends Msg {
  /// The underlying event.
  final evt.Event event;

  /// Creates an UnknownMsg from an Event.
  const UnknownMsg(this.event);
}

/// Converts a termparser Event to a Msg.
Msg eventToMsg(evt.Event event) {
  return switch (event) {
    final evt.KeyEvent e => _keyEventToMsg(e),
    final evt.MouseEvent e => MouseMsg(e),
    final evt.FocusEvent e => FocusMsg(e),
    final evt.PasteEvent e => PasteMsg(e),
    evt.NoneEvent() => const NoneMsg(),
    final e => UnknownMsg(e),
  };
}

KeyMsg _keyEventToMsg(evt.KeyEvent e) {
  final key = e.toSpec();
  return switch (e.eventType) {
    evt.KeyEventType.keyPress => KeyMsg(key),
    evt.KeyEventType.keyRepeat => KeyMsg.repeat(key),
    evt.KeyEventType.keyRelease => KeyMsg.release(key),
  };
}
