import 'package:characters/characters.dart';
import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart' as evt;

import '../widgets/hit_map.dart';
import 'pointer_msg.dart';

/// Base class for all messages in MVU architecture.
///
/// Messages trigger state updates in the update function.
abstract class Msg {
  /// Creates a Msg.
  const Msg();

  /// Whether this message can be dropped when stale.
  ///
  /// Droppable messages (e.g. FrameTickMsg) can be skipped when rendering
  /// falls behind. Input events should never be droppable.
  bool get droppable => false;

  /// Whether this message can be coalesced with others of the same key.
  ///
  /// Coalesceable messages (e.g. mouse moves, resizes) are merged between
  /// frames, keeping only the latest. This reduces processing for
  /// high-frequency events.
  bool get coalesceable => false;

  /// Key for grouping coalesceable messages.
  ///
  /// Messages with the same coalesceKey are coalesced together.
  /// Only meaningful when [coalesceable] is true.
  String get coalesceKey => '';
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

  /// The literal character this key would insert as typed text, or `null`
  /// if it names a shortcut/named key with no text form.
  ///
  /// `key` doubles as a `KeyBinding` spec string, and `KeyEvent.toSpec`
  /// aliases exactly three printable characters to word specs (`'space'`,
  /// `'plus'`, `'minus'`) so they can appear in a spec like `'ctrl+s'`
  /// without colliding with the `+` modifier separator. This reverses that
  /// aliasing through termparser's own spec parser — the same one
  /// `KeyBinding` uses to validate specs — rather than hardcoding the three
  /// names here, so it stays correct if termparser ever aliases more.
  String? get char {
    if (key.characters.length == 1) return key;
    try {
      final event = evt.KeyEvent.fromString(key);
      if (event.modifiers != evt.KeyModifiers.none) return null;
      return event.code.kind == evt.KeyCodeKind.char ? event.code.char : null;
      // KeyEvent.fromString throws ArgumentError for invalid specs
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is KeyMsg && key == other.key && type == other.type;

  @override
  int get hashCode => Object.hash(key, type);
}

/// A mouse event waiting in the queue, stamped with the frame it was aimed at.
///
/// This is what a mouse event *is* between the moment it arrives and the moment
/// the router resolves it. It never reaches `update`: the router replaces it
/// with a [PointerMsg] addressed to the widget under the pointer.
///
/// It carries [hits] because the pointer aims at cells, not at widgets. By the
/// time the queue drains, a frame tick may have painted a new layout — so the
/// event keeps the geometry it was aimed at and is resolved against that. The
/// map is immutable, so this costs one reference and no copy.
///
/// The pointer's *position* is what a move carries, so two moves collapse into
/// the later one. The pointer's *travel* is what a drag carries, and a drag is
/// coalesced the same way because a widget reads it as a position too. A wheel
/// notch is a delta, and merging two of those would silently eat one, so it is
/// never coalesced.
@internal
@immutable
class RawPointerMsg extends Msg {
  /// The event as the backend delivered it, in 0-based buffer cells.
  final evt.MouseEvent mouse;

  /// The tagged geometry of the frame that was on screen when it arrived.
  final HitMap hits;

  /// Stamps [mouse] with the [hits] it was aimed at.
  const RawPointerMsg(this.mouse, this.hits);

  /// Whether the pointer moved with no button held.
  bool get isMove => mouse.button.action == evt.MouseButtonAction.moved;

  /// Whether the pointer moved with a button held.
  bool get isDrag => mouse.button.action == evt.MouseButtonAction.drag;

  @override
  bool get coalesceable => isMove || isDrag;

  @override
  String get coalesceKey => 'mouse-move';

  @override
  String toString() => 'RawPointerMsg(${mouse.button.action.name} at ${mouse.x}, ${mouse.y})';
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

/// Internal frame tick message for render loop.
///
/// Sent automatically at the configured fps rate.
/// Unlike [TickMsg] (user-controlled), this drives the render cycle.
class FrameTickMsg extends Msg {
  /// Time since last frame.
  final Duration delta;

  /// Frame number since app start.
  final int frameNumber;

  /// Timestamp when this tick was created.
  final DateTime timestamp;

  /// Creates a FrameTickMsg.
  const FrameTickMsg({
    required this.delta,
    required this.frameNumber,
    required this.timestamp,
  });

  /// FrameTickMsg can be dropped when stale (rendering behind).
  @override
  bool get droppable => true;
}

/// Wrapper for unknown/unhandled events.
class UnknownMsg extends Msg {
  /// The underlying event.
  final evt.Event event;

  /// Creates an UnknownMsg from an Event.
  const UnknownMsg(this.event);
}

/// Converts a termparser Event to a Msg.
///
/// A mouse event is stamped with [hits], the geometry of the frame it was aimed
/// at. The runtime passes the map it last committed, so an event that waits in
/// the queue while a new frame is painted still resolves against the cells the
/// user was looking at. Before the first frame there is nothing to hit, and the
/// default empty map says so.
Msg eventToMsg(evt.Event event, {HitMap hits = const HitMap.empty()}) {
  return switch (event) {
    final evt.KeyEvent e => _keyEventToMsg(e),
    final evt.MouseEvent e => RawPointerMsg(e, hits),
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
