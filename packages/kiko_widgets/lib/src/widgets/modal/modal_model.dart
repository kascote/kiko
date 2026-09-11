import 'package:kiko/kiko.dart';

import 'types.dart';

/// Model for a static-content confirm/cancel dialog.
///
/// Covers the old `Modal.simple` case: no inner MVU of its own, just Enter →
/// [ModalConfirmEvent] / Escape → [ModalCancelEvent]. A dialog with its own state
/// (a form, a picker) needs no wrapper at all — render that widget's own model
/// as the `content` passed to `modalDialog` and route messages to it directly;
/// this model exists only for the plain "are you sure?" shape.
///
/// The app owns whether a modal is open at all (typically a nullable field
/// holding this model). While it is open, the modal owns every message
/// addressed to it. A press on its barrier decides for itself whether to
/// dismiss. An unknown key is absorbed rather than left for the app.
class ModalModel implements Component {
  /// Unique identifier for the modal.
  @override
  final String id;

  /// Data forwarded to [ModalConfirmEvent] when the modal is confirmed.
  final Object? confirmPayload;

  /// Custom key bindings. Null uses [defaultModalBindings].
  final KeyBinding<ModalAction>? keyBinding;

  /// Whether a press on the barrier dismisses the modal. Defaults to `true`.
  final bool dismissOnBarrierPress;

  bool _focused;

  /// Creates a ModalModel.
  ModalModel({
    String? id,
    this.confirmPayload,
    bool focused = true,
    this.keyBinding,
    this.dismissOnBarrierPress = true,
  }) : id = id ?? autoId('modal'),
       _focused = focused;

  /// Whether the modal is focused (captures input). Defaults to `true` since
  /// an open modal is normally the sole target of input while it exists.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// The effective key binding (custom or default).
  KeyBinding<ModalAction> get effectiveKeyBinding => keyBinding ?? defaultModalBindings;

  /// Updates the model based on the message.
  ///
  /// A `down` on the barrier — [PointerMsg.region] is a [ModalBarrierRegion] —
  /// emits [ModalCancelEvent] when [dismissOnBarrierPress] is set. Otherwise
  /// it is absorbed with no event. Every other pointer message addressed to
  /// the modal is absorbed too, including a press on the dialog's own cells.
  /// Nothing therefore falls through to the dimmed backdrop. These pointer
  /// cases apply whether or not the modal is focused.
  ///
  /// Past the pointer cases, an unfocused modal declines. A focused modal
  /// resolves a [KeyMsg] through [effectiveKeyBinding]. Enter returns
  /// [ModalConfirmEvent] and Escape returns [ModalCancelEvent]. Any other key
  /// is absorbed as [Handled], so nothing behind the modal reacts to it. A
  /// message that is neither routed nor a key is declined.
  @override
  UpdateResult update(Msg msg) {
    if (msg is PointerMsg) {
      if (msg.isDown && msg.region is ModalBarrierRegion) {
        return dismissOnBarrierPress ? Handled.event(ModalCancelEvent(id)) : const Handled();
      }
      return const Handled();
    }
    if (msg is PointerLeaveMsg || msg is PointerCancelMsg) return const Handled();

    if (!_focused) return const Declined();
    if (msg is! KeyMsg) return const Declined();

    return switch (effectiveKeyBinding.resolve(msg)) {
      ModalAction.confirm => Handled.event(ModalConfirmEvent(id, confirmPayload)),
      ModalAction.cancel => Handled.event(ModalCancelEvent(id)),
      null => const Handled(),
    };
  }
}
