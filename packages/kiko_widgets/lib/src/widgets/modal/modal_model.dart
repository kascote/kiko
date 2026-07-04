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

  /// Updates the model based on the message.
  ///
  /// Returns [ModalConfirmCmd] on Enter, [ModalCancelCmd] on Escape, and
  /// [Unhandled] for anything else.
  Cmd? update(Msg msg) {
    if (!_focused) return null;
    if (msg is! KeyMsg) return null;

    return switch (effectiveKeyBinding.resolve(msg)) {
      ModalAction.confirm => ModalConfirmCmd(id, confirmPayload),
      ModalAction.cancel => ModalCancelCmd(id),
      null => const Unhandled(),
    };
  }
}
