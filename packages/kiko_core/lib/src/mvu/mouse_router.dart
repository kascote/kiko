import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart' as evt;

import '../layout/position.dart';
import 'msg.dart';
import 'pointer_msg.dart';

/// Resolves a mouse event to the widget it belongs to, before `update` sees it.
///
/// The router sits between the queue and `update`. It answers the four
/// questions no other layer can: whose event is this, where did it land in that
/// widget's own coordinates, has the pointer left the widget it was over, and
/// which click of a chain is this. It hands `update` a [PointerMsg] with all
/// four already settled.
///
/// It carries the captor, the hover id and the last press across frames.
/// Everything else it needs comes from the event, which arrives stamped with
/// the geometry it was aimed at and the time it arrived.
///
/// ## Capture
///
/// A button press hands the pointer to whatever was under it, and every move,
/// drag and press that follows goes to the same place until the button comes up
/// — even once the cursor has wandered off, and even once the captor is gone
/// from the newest frame. So the release always reaches the widget that took
/// the press, and a drag that begins on the background does not jump to the
/// first widget the cursor crosses. What a press captures is the *answer* to
/// "what is under the pointer", and `null` — the background — is one of the
/// answers. The router never re-targets a gesture at the widget now under the
/// cursor.
///
/// A gesture ends three ways: a release, a bare move while a button is held,
/// or the terminal losing focus. A release ends it normally. The other two
/// deliver a [PointerCancelMsg] to whoever was holding the pointer instead, so
/// nothing is left waiting for a release that will never arrive.
///
/// The wheel never joins a gesture: it always addresses what is under the
/// pointer, and the router neither scales its notches nor reads its modifiers.
///
/// ## Hover
///
/// The router remembers the last widget the pointer resolved to. When an event
/// resolves somewhere else, the widget being left is told so, before the event
/// that left it is delivered. There is no matching enter message: a widget
/// learns it is hovered from the first [PointerMsg] addressed to it. Hover holds
/// still for the length of a gesture — the pointer is being used, not moved
/// about — and picks up wherever the cursor is once the button comes up.
///
/// ## Click count
///
/// A press chains onto the last one when its target, button and cell all
/// match and it lands within [doubleClickInterval] of it. The count
/// increments on each chained press; anything else starts a new chain at 1.
/// The `down` carries the count, and the `up` that ends the gesture carries
/// the same number. A release does not break the chain, so a slow release
/// still lets the next press join it. Only a cancelled gesture, lost
/// terminal focus, or [reset] clears the chain.
@internal
class MouseRouter {
  /// Creates a router that counts two presses as a chain when they land
  /// within [doubleClickInterval] of each other.
  MouseRouter({required this.doubleClickInterval});

  /// How long after a press a matching next press still chains onto it.
  final Duration doubleClickInterval;

  bool _capturing = false;
  String? _captureId;
  String? _hoverId;

  /// The last press recorded, for deciding whether the next one chains onto
  /// it. `null` before any press, and after [reset] or a cancelled gesture.
  ({Duration at, String? target, PointerButton button, Position cell})? _lastPress;

  /// The running length of the current chain of clicks.
  int _clickCount = 0;

  /// Whether a button gesture owns the pointer.
  ///
  /// True even when [captureId] is `null`: a press on the background captures
  /// the background.
  bool get capturing => _capturing;

  /// The widget holding the pointer, `null` for the background, and meaningless
  /// unless [capturing].
  String? get captureId => _captureId;

  /// The widget the pointer last resolved to, or `null` when it is over none.
  String? get hoverId => _hoverId;

  /// Forgets the pointer, for a runtime starting a fresh run.
  void reset() {
    _capturing = false;
    _captureId = null;
    _hoverId = null;
    _clearChain();
  }

  /// Expands one dequeued [msg] into the messages `update` should see.
  ///
  /// A mouse event becomes a [PointerMsg], preceded by a [PointerLeaveMsg] when
  /// it takes the pointer off a widget and by a [PointerCancelMsg] when it ends
  /// a gesture the wrong way. Losing terminal focus does both and then delivers
  /// the focus message itself. Everything else — keys, ticks, an already-routed
  /// message put back on the queue — passes through untouched.
  List<Msg> route(Msg msg) {
    if (msg is RawPointerMsg) return _routePointer(msg);
    if (msg is FocusMsg && !msg.hasFocus) return [..._abandon(), msg];
    return [msg];
  }

  List<Msg> _routePointer(RawPointerMsg raw) {
    final event = raw.mouse;
    final action = event.button.action;

    // A malformed SGR sequence reports no action at all. There is no gesture
    // to update and no widget to tell, so it is dropped before hover or
    // capture ever sees it — not delivered as input.
    if (action == evt.MouseButtonAction.none) return const [];

    final out = <Msg>[];

    // A bare `moved` while a button is held is the terminal's way of saying
    // the release happened where it could not see it: a held drag reports
    // `drag`, never `moved`. Cancel ends the gesture before the event that
    // exposed it is resolved.
    if (_capturing && action == evt.MouseButtonAction.moved) {
      out.add(PointerCancelMsg(_captureId));
      _release();
      _clearChain();
    }

    final hit = raw.hits.hitId(event.x, event.y);

    // Hover holds still while a gesture owns the pointer.
    if (!_capturing) out.addAll(_hoverOn(hit));

    // The wheel is not part of a button gesture, so it addresses what is under
    // the pointer even while another widget holds it.
    final captured = _capturing && !isWheelAction(action);
    final target = captured ? _captureId : hit;

    // A press with no gesture in flight captures the resolution, background and
    // all. A second press while one is held goes to the widget already holding
    // the pointer.
    if (action == evt.MouseButtonAction.down && !_capturing) {
      _capturing = true;
      _captureId = hit;
    }

    final fields = pointerFieldsFrom(event);
    final clickCount = _countClick(action, target, fields.button, Position(event.x, event.y), raw.at);

    // Local coordinates come from the event's own map, never from a rect frozen
    // when the button went down: the user aims at the cells now on screen. A
    // captor that has since been painted out has no rect, and its events fall
    // back to absolute coordinates.
    final rect = target == null ? null : raw.hits.rectOf(target);
    // The marked part under the pointer within the target, resolved from the
    // same map the event was aimed at. Recomputed per event, so a captured
    // gesture that has dragged off its widget carries a null region. A wheel
    // addresses what is under the pointer, so its region is that widget's part —
    // harmless, since wheel handling sits above region logic.
    final region = target == null ? null : raw.hits.regionAt(target, event.x, event.y);
    out.add(
      PointerMsg(
        global: Position(event.x, event.y),
        action: fields.action,
        button: fields.button,
        shift: fields.shift,
        ctrl: fields.ctrl,
        alt: fields.alt,
        targetId: target,
        local: rect == null ? Position(event.x, event.y) : Position(event.x - rect.x, event.y - rect.y),
        targetRect: rect,
        captured: captured,
        region: region,
        clickCount: clickCount,
      ),
    );

    // The release goes to the widget that held the pointer; hover only then
    // catches up with where the cursor actually is.
    if (action == evt.MouseButtonAction.up && _capturing) {
      _release();
      out.addAll(_hoverOn(hit));
    }

    return out;
  }

  /// Ends whatever the pointer was doing, for a terminal that just lost focus.
  List<Msg> _abandon() {
    final out = <Msg>[];
    if (_capturing) {
      out.add(PointerCancelMsg(_captureId));
      _release();
    }
    _clearChain();
    final left = _hoverId;
    if (left != null) {
      out.add(PointerLeaveMsg(left));
      _hoverId = null;
    }
    return out;
  }

  /// Moves hover onto [hit], telling the widget it left, if any.
  List<Msg> _hoverOn(String? hit) {
    if (hit == _hoverId) return const [];
    final left = _hoverId;
    _hoverId = hit;
    return left == null ? const [] : [PointerLeaveMsg(left)];
  }

  void _release() {
    _capturing = false;
    _captureId = null;
  }

  /// Counts [action] against the [target] already settled for this event,
  /// and records a press so the next one has something to compare against.
  ///
  /// A `down` that matches the last press's target, button and cell, and
  /// lands within [doubleClickInterval] of it, continues the chain; anything
  /// else starts a new one at 1. An `up` reuses the count its `down` set. A
  /// move, a drag or a wheel notch counts 0 and leaves the chain untouched.
  int _countClick(evt.MouseButtonAction action, String? target, PointerButton button, Position cell, Duration at) {
    if (action == evt.MouseButtonAction.up) return _clickCount;
    if (action != evt.MouseButtonAction.down) return 0;

    final last = _lastPress;
    final chains =
        last != null &&
        last.target == target &&
        last.button == button &&
        last.cell == cell &&
        at >= last.at &&
        at - last.at <= doubleClickInterval;
    _clickCount = chains ? _clickCount + 1 : 1;
    _lastPress = (at: at, target: target, button: button, cell: cell);
    return _clickCount;
  }

  /// Forgets the last press, so the next one starts a fresh chain.
  void _clearChain() {
    _lastPress = null;
    _clickCount = 0;
  }
}
