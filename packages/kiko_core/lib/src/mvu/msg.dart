import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart' as evt;

import '../widgets/hit_map.dart';
import 'addressed.dart';
import 'pointer_msg.dart';

/// Base class for all messages in MVU architecture.
///
/// Messages trigger state updates in the update function.
abstract class Msg {
  /// Creates a Msg.
  const Msg();

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

/// Which modifier a bare [ModifierKeyMsg] reports.
enum ModifierKey {
  /// Shift.
  shift,

  /// Control.
  ctrl,

  /// Alt (Option on macOS).
  alt,

  /// Super (the Windows key, or Command on macOS).
  superKey,

  /// Hyper.
  hyper,

  /// Meta.
  meta,
}

/// Which physical copy of a modifier produced a [ModifierKeyMsg].
///
/// Most keyboards have a left and a right copy of shift, ctrl, alt, super,
/// hyper and meta, and a terminal that reports bare modifier keys tells them
/// apart. Two kitty-specific shift keys — ISO Level 3 Shift and ISO Level 5
/// Shift — have no left/right identity of their own, so they report
/// [unsided] instead.
enum ModifierSide {
  /// The left-hand key.
  left,

  /// The right-hand key.
  right,

  /// No left/right distinction.
  unsided,
}

/// A bare modifier key going down or coming back up, with no other key
/// involved.
///
/// A plain terminal cannot see this at all — it only ever reports a modifier
/// as a bit set on some other keystroke. Seeing a modifier key on its own
/// (someone tapped Shift and let go, pressing nothing else) requires the
/// kitty keyboard enhancement. [modifier] says which key it was, [side]
/// which physical copy (see [ModifierSide]), and [down] which edge — both
/// the press and the release arrive as this same class. A held modifier does
/// not repeat: an auto-repeated modifier carries no new information, so
/// intake drops it instead of delivering a message (see [eventToMsg]).
@immutable
class ModifierKeyMsg extends Msg {
  /// Which modifier this is.
  final ModifierKey modifier;

  /// Which physical copy of that modifier.
  final ModifierSide side;

  /// True when the key went down; false when it came back up.
  final bool down;

  /// Creates a ModifierKeyMsg.
  const ModifierKeyMsg(this.modifier, this.side, {required this.down});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModifierKeyMsg && modifier == other.modifier && side == other.side && down == other.down;

  @override
  int get hashCode => Object.hash(modifier, side, down);

  @override
  String toString() => 'ModifierKeyMsg($modifier $side ${down ? 'down' : 'up'})';
}

/// The key-up of a keystroke-capable key.
///
/// A plain terminal only ever sends presses; seeing the matching release for
/// a key requires the kitty keyboard enhancement. [key] is the same spec
/// string the press for this key carried.
@immutable
class KeyReleaseMsg extends Msg {
  /// The key spec that was released — the same string a press of this key
  /// carries as [KeyMsg.key].
  final String key;

  /// Creates a KeyReleaseMsg.
  const KeyReleaseMsg(this.key);

  @override
  bool operator ==(Object other) => identical(this, other) || other is KeyReleaseMsg && key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'KeyReleaseMsg($key)';
}

/// Wrapper for a key press or repeat.
///
/// A release or a bare modifier key never arrives as a [KeyMsg] — they are
/// [KeyReleaseMsg] and [ModifierKeyMsg], siblings under [Msg] rather than
/// variants of this class. That is what makes `case KeyMsg(key: 'q')` mean
/// exactly "any keystroke that types q": there is no separate check needed
/// to exclude a release or a lone modifier, because they are not this type.
@immutable
class KeyMsg extends Msg {
  /// The key string (e.g., 'ctrl+a', 'enter', 'q').
  final String key;

  /// True when the terminal reported this as auto-repeat — the key was held
  /// down and is resending, rather than a fresh press.
  ///
  /// Not every terminal can tell the difference: one without the kitty
  /// keyboard enhancement simply resends synthetic presses for a held key,
  /// so [repeat] reads false there even though the key is, physically, being
  /// held. Do not build behavior that depends on ever seeing `true` — a held
  /// arrow key or a held backspace must keep working as plain presses.
  final bool repeat;

  /// The literal text this keystroke types, or null if it names a
  /// shortcut/named key with no text form. See [eventToMsg] for how this is
  /// derived from the terminal event.
  final String? text;

  /// This keystroke's spec projected onto the standard US layout key, or
  /// null when the terminal did not report one (most do not) or the key is
  /// a named key. Lets an app match a physical key position instead of
  /// whatever character a non-US layout produces there.
  final String? baseKey;

  /// Creates a KeyMsg for a key press (default) or repeat.
  const KeyMsg(this.key, {this.repeat = false, this.text, this.baseKey});

  /// Creates a KeyMsg for a key repeat — a held key resending.
  const KeyMsg.repeat(this.key, {this.text, this.baseKey}) : repeat = true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyMsg && key == other.key && repeat == other.repeat && text == other.text && baseKey == other.baseKey;

  @override
  int get hashCode => Object.hash(key, repeat, text, baseKey);

  @override
  String toString() => 'KeyMsg($key${repeat ? ', repeat' : ''})';
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
  /// Whether the terminal has focus.
  final bool hasFocus;

  /// Creates a FocusMsg.
  const FocusMsg({required this.hasFocus});

  @override
  bool operator ==(Object other) => identical(this, other) || other is FocusMsg && hasFocus == other.hasFocus;

  @override
  int get hashCode => hasFocus.hashCode;

  @override
  String toString() => 'FocusMsg(hasFocus: $hasFocus)';
}

/// Wrapper for paste events.
@immutable
class PasteMsg extends Msg {
  /// The pasted text.
  final String text;

  /// Creates a PasteMsg.
  const PasteMsg(this.text);

  @override
  bool operator ==(Object other) => identical(this, other) || other is PasteMsg && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'PasteMsg($text)';
}

/// Message sent once at application startup before first render.
///
/// Allows update function to return initial commands (fetch data, start timer).
class InitMsg extends Msg {
  /// Creates an InitMsg.
  const InitMsg({this.hasDarkBackground});

  /// Whether the startup probe found the terminal's background dark.
  ///
  /// `true` means dark, `false` means light, `null` means the terminal never
  /// answered — treat `null` as dark by convention. Kiko never picks a theme
  /// from this itself; the app reads it and decides.
  final bool? hasDarkBackground;
}

/// The one message a `Tick` command delivers, after its interval.
///
/// Addressed to the owner that armed the tick: a focus router delivers it by
/// [id], and the owner compares [key] to its current generation before
/// re-arming. [elapsed] is the time since the tick was armed — the animation
/// delta.
class TickMsg extends Msg implements Addressed {
  /// The stable id of the owner the tick was armed for.
  @override
  final String id;

  /// The generation the owner armed the tick with.
  final Object? key;

  /// Time elapsed since the `Tick` command was armed.
  final Duration elapsed;

  /// Creates a TickMsg for the owner registered under [id].
  const TickMsg(this.id, {required this.elapsed, this.key});

  @override
  String toString() => 'TickMsg($id, key: $key, elapsed: $elapsed)';
}

/// Wrapper for terminal resize events.
///
/// Sent when the terminal window changes size. Carries the new size in
/// cells, plus a pixel size when the terminal reports one.
///
/// A resize is position-valued, not delta-valued: it names an absolute
/// size, not a change in size. That is why [coalesceable] is true — if
/// several resizes back up in the queue, only the latest describes the
/// terminal's actual current size, so the earlier ones are redundant and
/// safe to drop.
///
/// [width] and [height] are always meaningful. [widthPixels] and
/// [heightPixels] are 0 when the terminal does not report pixel
/// dimensions, which most terminals do not.
@immutable
class ResizeMsg extends Msg {
  /// The new terminal width, in cells.
  final int width;

  /// The new terminal height, in cells.
  final int height;

  /// The new terminal width, in pixels, or 0 if not reported.
  final int widthPixels;

  /// The new terminal height, in pixels, or 0 if not reported.
  final int heightPixels;

  /// Creates a ResizeMsg.
  const ResizeMsg({
    required this.width,
    required this.height,
    this.widthPixels = 0,
    this.heightPixels = 0,
  });

  @override
  bool get coalesceable => true;

  @override
  String get coalesceKey => 'resize';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResizeMsg &&
          width == other.width &&
          height == other.height &&
          widthPixels == other.widthPixels &&
          heightPixels == other.heightPixels;

  @override
  int get hashCode => Object.hash(width, height, widthPixels, heightPixels);
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
/// Returns null for the two events intake drops instead of delivering: the
/// auto-repeat of a bare modifier key (see [ModifierKeyMsg]) carries no new
/// information, and termparser's `NoneEvent` carries no event at all, so
/// there is nothing for `update` to see. Every other event becomes exactly
/// one message — nothing else is ever suppressed.
///
/// A mouse event is stamped with [hits], the geometry of the frame it was aimed
/// at. The runtime passes the map it last committed, so an event that waits in
/// the queue while a new frame is painted still resolves against the cells the
/// user was looking at. Before the first frame there is nothing to hit, and the
/// default empty map says so.
Msg? eventToMsg(evt.Event event, {HitMap hits = const HitMap.empty()}) {
  return switch (event) {
    final evt.KeyEvent e => _keyEventToMsg(e),
    final evt.MouseEvent e => RawPointerMsg(e, hits),
    final evt.FocusEvent e => FocusMsg(hasFocus: e.hasFocus),
    final evt.PasteEvent e => PasteMsg(e.text),
    evt.NoneEvent() => null,
    final evt.WindowResizeEvent e => ResizeMsg(
      width: e.widthChars,
      height: e.heightChars,
      widthPixels: e.widthPixels,
      heightPixels: e.heightPixels,
    ),
    final e => UnknownMsg(e),
  };
}

/// Named keys that report a bare modifier on its own, mapped to the
/// [ModifierKey] and [ModifierSide] they name.
const Map<evt.KeyCodeName, (ModifierKey, ModifierSide)> _bareModifierKeys = {
  evt.KeyCodeName.leftShift: (ModifierKey.shift, ModifierSide.left),
  evt.KeyCodeName.rightShift: (ModifierKey.shift, ModifierSide.right),
  evt.KeyCodeName.leftCtrl: (ModifierKey.ctrl, ModifierSide.left),
  evt.KeyCodeName.rightCtrl: (ModifierKey.ctrl, ModifierSide.right),
  evt.KeyCodeName.leftAlt: (ModifierKey.alt, ModifierSide.left),
  evt.KeyCodeName.rightAlt: (ModifierKey.alt, ModifierSide.right),
  evt.KeyCodeName.leftSuper: (ModifierKey.superKey, ModifierSide.left),
  evt.KeyCodeName.rightSuper: (ModifierKey.superKey, ModifierSide.right),
  evt.KeyCodeName.leftHyper: (ModifierKey.hyper, ModifierSide.left),
  evt.KeyCodeName.rightHyper: (ModifierKey.hyper, ModifierSide.right),
  evt.KeyCodeName.leftMeta: (ModifierKey.meta, ModifierSide.left),
  evt.KeyCodeName.rightMeta: (ModifierKey.meta, ModifierSide.right),
  evt.KeyCodeName.isoLevel3Shift: (ModifierKey.shift, ModifierSide.unsided),
  evt.KeyCodeName.isoLevel5Shift: (ModifierKey.shift, ModifierSide.unsided),
};

Msg? _keyEventToMsg(evt.KeyEvent e) {
  if (e.code.kind == evt.KeyCodeKind.named) {
    final bare = _bareModifierKeys[e.code.name];
    if (bare != null) {
      final (modifier, side) = bare;
      return switch (e.eventType) {
        evt.KeyEventType.keyPress => ModifierKeyMsg(modifier, side, down: true),
        evt.KeyEventType.keyRelease => ModifierKeyMsg(modifier, side, down: false),
        // A held modifier resending is not news; drop it rather than deliver
        // a message nobody can act on differently from the first press.
        evt.KeyEventType.keyRepeat => null,
      };
    }
  }

  final key = e.toSpec();
  return switch (e.eventType) {
    evt.KeyEventType.keyPress => KeyMsg(key, text: _textOf(e), baseKey: e.toBaseLayoutSpec()),
    evt.KeyEventType.keyRepeat => KeyMsg.repeat(key, text: _textOf(e), baseKey: e.toBaseLayoutSpec()),
    evt.KeyEventType.keyRelease => KeyReleaseMsg(key),
  };
}

/// The text a keystroke types, read off the event itself rather than
/// re-derived by parsing its spec string.
///
/// The terminal's own text-as-codepoints field ([evt.KeyEvent.text]) wins
/// when present. Otherwise, a plain character key typed with no modifiers,
/// or with shift only, types its character — folded the same way the key
/// spec folds it, so `key` and `text` never disagree: a shifted cased
/// letter types its uppercase form even when the terminal reported only
/// the base key, and a character the terminal already confirmed as the
/// shifted production types as is. Anything else — a named key, or a
/// character combined with ctrl/alt/super/hyper/meta — has no text form.
String? _textOf(evt.KeyEvent e) {
  if (e.text != null) return e.text;
  if (e.code.kind != evt.KeyCodeKind.char) return null;
  final mods = e.modifiers;
  if (mods == evt.KeyModifiers.none) return e.code.char;
  if (mods != evt.KeyModifiers.shift) return null;
  final upper = e.code.char.toUpperCase();
  return upper != e.code.char.toLowerCase() ? upper : e.code.char;
}
