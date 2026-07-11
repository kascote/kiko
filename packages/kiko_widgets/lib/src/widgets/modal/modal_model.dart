import 'package:kiko/kiko.dart';

import 'types.dart';

/// Model for a static-content confirm/cancel dialog.
///
/// Covers the old `Modal.simple` case: no inner MVU of its own, just Enter →
/// [ModalConfirmCmd] / Escape → [ModalCancelCmd]. A dialog with its own state
/// (a form, a picker) needs no wrapper at all — render that widget's own model
/// as the `content` passed to `modalDialog` and route messages to it directly;
/// this model exists only for the plain "are you sure?" shape.
///
/// The app owns whether a modal is open at all (typically a nullable field
/// holding this model); [update] only reacts to Enter/Escape while it exists.
class ModalModel implements Focusable {
  /// Unique identifier for the modal.
  final String id;

  /// Data forwarded to [ModalConfirmCmd] when the modal is confirmed.
  final Object? confirmPayload;

  /// Custom key bindings. Null uses [defaultModalBindings].
  final KeyBinding<ModalAction>? keyBinding;

  bool _focused;

  /// Creates a ModalModel.
  ModalModel({String? id, this.confirmPayload, bool focused = true, this.keyBinding})
    : id = id ?? autoId('modal'),
      _focused = focused;

  /// Whether the modal is focused (captures input). Defaults to `true` since
  /// an open modal is normally the sole target of input while it exists.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// The effective key binding (custom or default).
  KeyBinding<ModalAction> get effectiveKeyBinding => keyBinding ?? defaultModalBindings;

  /// The dismiss request the app fires when a click lands outside the modal.
  ///
  /// Reuses the same [ModalCancelCmd] the Escape key emits — same event, same
  /// [id] — so a mouse dismiss and a keyboard dismiss are indistinguishable to
  /// the app. Whether a click is "outside" is an app-side `hitPath` decision (a
  /// widget's [update] never sees the hit map), so the app tests the click and
  /// fires this; the modal only supplies the request.
  Cmd dismiss() => ModalCancelCmd(id);

  /// Updates the model based on the message.
  ///
  /// Returns [Handled] with a [ModalConfirmCmd] on Enter and a [ModalCancelCmd]
  /// on Escape, and [Declined] for any other key. A pointer addressed to the
  /// modal (a click on its own chrome) is absorbed as [Handled] so it never
  /// falls through to the dimmed backdrop; a click *outside* never reaches this
  /// `update` (it addresses another id), so the app dismisses via [dismiss].
  UpdateResult update(Msg msg) {
    if (!_focused) return const Declined();
    if (msg is! KeyMsg) return const Handled();

    return switch (effectiveKeyBinding.resolve(msg)) {
      ModalAction.confirm => Handled(ModalConfirmCmd(id, confirmPayload)),
      ModalAction.cancel => Handled(ModalCancelCmd(id)),
      null => const Declined(),
    };
  }
}
