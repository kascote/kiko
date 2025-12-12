import 'package:termparser/termparser_events.dart' as evt;

/// Base class for all messages in MVU architecture.
///
/// Messages trigger state updates in the update function.
abstract class Msg {
  /// Creates a Msg.
  const Msg();
}

/// Wrapper for keyboard events.
class KeyMsg extends Msg {
  /// The underlying key event.
  final evt.KeyEvent key;

  /// Creates a KeyMsg from a KeyEvent.
  const KeyMsg(this.key);
}

/// Wrapper for mouse events.
class MouseMsg extends Msg {
  /// The underlying mouse event.
  final evt.MouseEvent mouse;

  /// Creates a MouseMsg from a MouseEvent.
  const MouseMsg(this.mouse);

  /// X coordinate of mouse event.
  int get x => mouse.x;

  /// Y coordinate of mouse event.
  int get y => mouse.y;
}

/// Wrapper for focus events.
class FocusMsg extends Msg {
  /// The underlying focus event.
  final evt.FocusEvent focus;

  /// Creates a FocusMsg from a FocusEvent.
  const FocusMsg(this.focus);

  /// Whether the terminal has focus.
  bool get hasFocus => focus.hasFocus;
}

/// Wrapper for paste events.
class PasteMsg extends Msg {
  /// The underlying paste event.
  final evt.PasteEvent paste;

  /// Creates a PasteMsg from a PasteEvent.
  const PasteMsg(this.paste);

  /// The pasted text.
  String get text => paste.text;
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
  /// Time elapsed since last tick.
  final Duration delta;

  /// Creates a TickMsg.
  const TickMsg(this.delta);
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
    final evt.KeyEvent e => KeyMsg(e),
    final evt.MouseEvent e => MouseMsg(e),
    final evt.FocusEvent e => FocusMsg(e),
    final evt.PasteEvent e => PasteMsg(e),
    evt.NoneEvent() => const NoneMsg(),
    final e => UnknownMsg(e),
  };
}
