import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart' as evt;

import '../layout/position.dart';
import '../layout/rect.dart';
import 'msg.dart';
import 'region.dart';

/// Whether [action] is one of the four wheel notches.
///
/// The one definition [PointerMsg.isWheel] and the router share: the router
/// must ask before a [PointerMsg] exists to wrap the answer in, so it cannot
/// go through the getter and needs this instead.
@internal
bool isWheelAction(evt.MouseButtonAction action) => switch (action) {
  evt.MouseButtonAction.wheelUp ||
  evt.MouseButtonAction.wheelDown ||
  evt.MouseButtonAction.wheelLeft ||
  evt.MouseButtonAction.wheelRight => true,
  _ => false,
};

/// Which physical button a pointer message names.
enum PointerButton {
  /// No button — a wheel notch names none, and a release under legacy mouse
  /// reporting does not say which button came up.
  none,

  /// The left button.
  left,

  /// The middle button.
  middle,

  /// The right button.
  right,
}

/// What a pointer did.
///
/// A wheel notch gets one member per direction rather than a bare `wheel`
/// plus a signed delta — see [PointerMsg.wheelDeltaY] and
/// [PointerMsg.wheelDeltaX] for the signed form most callers want.
///
/// There is no `none` member: a mouse action a terminal could not describe
/// never becomes a [PointerMsg] in the first place.
enum PointerAction {
  /// A button went down.
  down,

  /// A button came up.
  up,

  /// The pointer moved with no button held.
  move,

  /// The pointer moved with a button held.
  drag,

  /// The wheel turned up.
  wheelUp,

  /// The wheel turned down.
  wheelDown,

  /// The wheel turned left.
  wheelLeft,

  /// The wheel turned right.
  wheelRight,
}

/// Maps a termparser mouse event to the fields [PointerMsg] stores.
///
/// This is the one seam where termparser's button kind, action and modifier
/// bitset turn into kiko's own [PointerButton], [PointerAction] and three
/// plain booleans. The router calls it once, at the single site that builds a
/// [PointerMsg], so nothing that reads a [PointerMsg] ever needs to import
/// termparser.
///
/// [event]'s action must not be [evt.MouseButtonAction.none] — that is a
/// malformed sequence the router drops before it gets here.
@internal
({PointerAction action, PointerButton button, bool shift, bool ctrl, bool alt}) pointerFieldsFrom(
  evt.MouseEvent event,
) {
  return (
    action: switch (event.button.action) {
      evt.MouseButtonAction.down => PointerAction.down,
      evt.MouseButtonAction.up => PointerAction.up,
      evt.MouseButtonAction.moved => PointerAction.move,
      evt.MouseButtonAction.drag => PointerAction.drag,
      evt.MouseButtonAction.wheelUp => PointerAction.wheelUp,
      evt.MouseButtonAction.wheelDown => PointerAction.wheelDown,
      evt.MouseButtonAction.wheelLeft => PointerAction.wheelLeft,
      evt.MouseButtonAction.wheelRight => PointerAction.wheelRight,
      evt.MouseButtonAction.none => throw ArgumentError.value(
        event,
        'event',
        'a malformed mouse event never becomes a PointerMsg',
      ),
    },
    button: switch (event.button.button) {
      evt.MouseButtonKind.none => PointerButton.none,
      evt.MouseButtonKind.left => PointerButton.left,
      evt.MouseButtonKind.middle => PointerButton.middle,
      evt.MouseButtonKind.right => PointerButton.right,
    },
    shift: event.modifiers.has(evt.KeyModifiers.shift),
    ctrl: event.modifiers.has(evt.KeyModifiers.ctrl),
    alt: event.modifiers.has(evt.KeyModifiers.alt),
  );
}

/// A message the mouse router addressed to a widget.
///
/// Match on it to forward every kind of pointer traffic in one line, whatever
/// the widget is:
///
/// ```dart
/// case Routed(:final targetId?) when targets.containsKey(targetId):
///   return (model, targets[targetId]!.update(msg));
/// ```
///
/// It means *this message was routed*, not *this message has a target*: a
/// pointer event over no widget carries a null [targetId], so the pattern above
/// declines it and a later case may treat it as a click on the background.
abstract interface class Routed {
  /// The widget the message was addressed to, or `null` for the background.
  String? get targetId;
}

/// A mouse event, resolved to the widget it belongs to.
///
/// It arrives at `update` knowing whose it is ([targetId]), where it landed in
/// that widget's own coordinates ([local]), and what it was ([action], [button],
/// [shift]/[ctrl]/[alt]) — nothing downstream re-derives a target or subtracts a
/// rect.
///
/// Every field is kiko's own vocabulary, not a terminal type copied through:
/// nothing that reads a [PointerMsg] needs to know a termparser event exists.
/// [global]'s coordinates are 0-based buffer cells, already translated by the
/// backend.
@immutable
class PointerMsg extends Msg implements Routed {
  /// The pointer, in absolute buffer cells.
  final Position global;

  /// What the pointer did: a press, a release, a move, a drag, a wheel notch.
  final PointerAction action;

  /// The button involved, or [PointerButton.none] for a wheel notch or an
  /// event with no button of its own.
  final PointerButton button;

  /// Whether shift was held.
  final bool shift;

  /// Whether ctrl was held.
  final bool ctrl;

  /// Whether alt was held.
  final bool alt;

  /// The widget under the pointer, the widget holding it, or `null` when the
  /// pointer is over no addressable widget at all.
  @override
  final String? targetId;

  /// The pointer, counted from the top-left cell of [targetRect].
  ///
  /// Equal to [global] when there is no target. It may fall outside the target
  /// while a gesture is [captured] — the cursor has left the widget, but the
  /// widget still owns the events.
  final Position local;

  /// Where the target was painted, or `null` when there is no target.
  ///
  /// A model does not know its own geometry, so this is what lets it answer
  /// whether a release landed [inside] it.
  final Rect? targetRect;

  /// Whether the target holds the pointer for the length of a button gesture,
  /// rather than merely sitting under it.
  final bool captured;

  /// The painted part of the target widget under the pointer, or `null` when
  /// the pointer is over no marked part.
  ///
  /// A view marks its discrete parts (rows, a header, an expand indicator) while
  /// painting, and the router resolves the innermost one under the pointer; a
  /// model switches over its own region types instead of re-deriving which part
  /// a coordinate falls on. `null` means the pointer is on nothing marked — an
  /// unmarked separator, the blank tail below the last row, or a widget that
  /// marks no regions at all — and is always `null` without a [targetId]. While
  /// a gesture is [captured] it is recomputed per event and is `null` whenever
  /// the pointer has left the widget holding it.
  ///
  /// [local] stays valid at every tier: region complements it, never replaces
  /// it. A continuous surface (a text editor's click-to-caret) marks no regions
  /// and reads [local]; that is a permanent tier, not a legacy one.
  final Region? region;

  /// Addresses a pointer event to a target.
  const PointerMsg({
    required this.global,
    required this.action,
    required this.local,
    this.button = PointerButton.none,
    this.shift = false,
    this.ctrl = false,
    this.alt = false,
    this.targetId,
    this.targetRect,
    this.captured = false,
    this.region,
  });

  /// Whether a button went down.
  bool get isDown => action == PointerAction.down;

  /// Whether a button came up.
  bool get isUp => action == PointerAction.up;

  /// Whether the pointer moved with no button held.
  bool get isMove => action == PointerAction.move;

  /// Whether the pointer moved with a button held.
  bool get isDrag => action == PointerAction.drag;

  /// Whether the wheel turned, in any of the four directions.
  ///
  /// A wheel event carries no button: read [action] for the direction. It
  /// always addresses whatever is under the pointer, never the widget holding a
  /// gesture, because the wheel is not part of one.
  bool get isWheel => switch (action) {
    PointerAction.wheelUp || PointerAction.wheelDown || PointerAction.wheelLeft || PointerAction.wheelRight => true,
    _ => false,
  };

  /// The vertical wheel notch: `-1` up, `1` down, `0` off-axis or non-wheel.
  ///
  /// A delta, not a position: one event is one notch, and the router never
  /// coalesces wheel events, so summing every [wheelDeltaY] seen is exact —
  /// unlike [global], which only the latest of a coalesced run reflects.
  int get wheelDeltaY => switch (action) {
    PointerAction.wheelUp => -1,
    PointerAction.wheelDown => 1,
    _ => 0,
  };

  /// The horizontal wheel notch: `-1` left, `1` right, `0` off-axis or
  /// non-wheel. See [wheelDeltaY].
  int get wheelDeltaX => switch (action) {
    PointerAction.wheelLeft => -1,
    PointerAction.wheelRight => 1,
    _ => 0,
  };

  /// Whether the pointer landed within the target.
  ///
  /// False without a target, and false when a captured gesture has dragged the
  /// cursor off the widget that owns it — which is how a button decides whether
  /// a release should fire it.
  bool get inside {
    final rect = targetRect;
    if (rect == null) return false;
    return local.x >= 0 && local.y >= 0 && local.x < rect.width && local.y < rect.height;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointerMsg &&
          global == other.global &&
          action == other.action &&
          button == other.button &&
          shift == other.shift &&
          ctrl == other.ctrl &&
          alt == other.alt &&
          targetId == other.targetId &&
          local == other.local &&
          targetRect == other.targetRect &&
          captured == other.captured &&
          region == other.region;

  @override
  int get hashCode =>
      Object.hash(global, action, button, shift, ctrl, alt, targetId, local, targetRect, captured, region);

  @override
  String toString() =>
      'PointerMsg(${action.name} at $global, target: $targetId, local: $local'
      '${region == null ? '' : ', region: $region'}${captured ? ', captured' : ''})';
}

/// The pointer has left a widget: no further event will address it.
///
/// Delivered just before the event that moved the pointer elsewhere, so a model
/// that lit up on hover can put itself out. There is no matching enter message —
/// a widget learns it is hovered from the first [PointerMsg] it receives.
///
/// The router invents this one, so it carries no terminal event and no position.
@immutable
class PointerLeaveMsg extends Msg implements Routed {
  /// The widget the pointer left.
  @override
  final String targetId;

  /// Announces that the pointer left [targetId].
  const PointerLeaveMsg(this.targetId);

  @override
  bool operator ==(Object other) => identical(this, other) || other is PointerLeaveMsg && targetId == other.targetId;

  @override
  int get hashCode => Object.hash(PointerLeaveMsg, targetId);

  @override
  String toString() => 'PointerLeaveMsg($targetId)';
}

/// A button gesture ended without a release: end the interaction, and do not
/// commit it.
///
/// Where an `up` says *the user finished*, this says *the user never will*. It
/// reaches the widget holding the pointer when the cursor leaves the terminal
/// window mid-drag, when the widget itself is no longer on screen, or when the
/// terminal loses focus. Without it a widget would sit at `dragging = true`
/// forever, waiting for a release nobody can send.
///
/// The router invents this one, so it carries no terminal event and no position.
/// A `null` [targetId] means the gesture began on the background.
@immutable
class PointerCancelMsg extends Msg implements Routed {
  /// The widget that was holding the pointer, or `null` for the background.
  @override
  final String? targetId;

  /// Announces that [targetId]'s gesture was abandoned.
  const PointerCancelMsg(this.targetId);

  @override
  bool operator ==(Object other) => identical(this, other) || other is PointerCancelMsg && targetId == other.targetId;

  @override
  int get hashCode => Object.hash(PointerCancelMsg, targetId);

  @override
  String toString() => 'PointerCancelMsg($targetId)';
}
