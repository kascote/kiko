import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart' as evt;

import '../layout/position.dart';
import '../layout/rect.dart';
import 'msg.dart';

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
/// [modifiers]) — nothing downstream re-derives a target or subtracts a rect.
///
/// The raw event is kept whole in [mouse] rather than copied field by field, so
/// nothing is lost and an app that hit-tests its own canvas can ignore the
/// routing and read [global]. Its coordinates are 0-based buffer cells, already
/// translated by the backend.
@immutable
class PointerMsg extends Msg implements Routed {
  /// The terminal event this message routes.
  final evt.MouseEvent mouse;

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

  /// Addresses [mouse] to a target.
  const PointerMsg(
    this.mouse, {
    required this.local,
    this.targetId,
    this.targetRect,
    this.captured = false,
  });

  /// The pointer, in absolute buffer cells.
  Position get global => Position(mouse.x, mouse.y);

  /// The button, paired with what it did.
  evt.MouseButton get button => mouse.button;

  /// What the mouse did: a press, a release, a move, a drag, a wheel notch.
  evt.MouseButtonAction get action => mouse.button.action;

  /// The modifier keys held down, for a shift-click or a ctrl-click.
  evt.KeyModifiers get modifiers => mouse.modifiers;

  /// Whether a button went down.
  bool get isDown => action == evt.MouseButtonAction.down;

  /// Whether a button came up.
  bool get isUp => action == evt.MouseButtonAction.up;

  /// Whether the pointer moved with no button held.
  bool get isMove => action == evt.MouseButtonAction.moved;

  /// Whether the pointer moved with a button held.
  bool get isDrag => action == evt.MouseButtonAction.drag;

  /// Whether the wheel turned, in any of the four directions.
  ///
  /// A wheel event carries no button: read [action] for the direction. It
  /// always addresses whatever is under the pointer, never the widget holding a
  /// gesture, because the wheel is not part of one.
  bool get isWheel => switch (action) {
    evt.MouseButtonAction.wheelUp ||
    evt.MouseButtonAction.wheelDown ||
    evt.MouseButtonAction.wheelLeft ||
    evt.MouseButtonAction.wheelRight => true,
    _ => false,
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
          mouse == other.mouse &&
          targetId == other.targetId &&
          local == other.local &&
          targetRect == other.targetRect &&
          captured == other.captured;

  @override
  int get hashCode => Object.hash(mouse, targetId, local, targetRect, captured);

  @override
  String toString() =>
      'PointerMsg(${action.name} at $global, target: $targetId, local: $local'
      '${captured ? ', captured' : ''})';
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
