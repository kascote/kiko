import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// Actions for the default modal key bindings.
enum ModalAction {
  /// Confirm and dismiss (default: Enter).
  confirm,

  /// Cancel and dismiss (default: Escape).
  cancel,
}

/// Command emitted when a modal is confirmed.
///
/// The app resolves this to the dismissed modal by [id] and drops it from
/// whatever state is holding it open, then acts on [payload].
@immutable
class ModalConfirmCmd extends Cmd {
  /// The id of the confirmed modal.
  final String id;

  /// App-supplied data carried from the modal to its result handler.
  final Object? payload;

  /// Creates a ModalConfirmCmd.
  const ModalConfirmCmd(this.id, [this.payload]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ModalConfirmCmd && other.id == id && other.payload == payload;

  @override
  int get hashCode => Object.hash(id, payload);

  @override
  String toString() => 'ModalConfirmCmd($id, $payload)';
}

/// Command emitted when a modal is cancelled.
@immutable
class ModalCancelCmd extends Cmd {
  /// The id of the cancelled modal.
  final String id;

  /// Creates a ModalCancelCmd.
  const ModalCancelCmd(this.id);

  @override
  bool operator ==(Object other) => identical(this, other) || other is ModalCancelCmd && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ModalCancelCmd($id)';
}

/// Default key bindings for a static-content modal: Enter confirms, Escape
/// cancels.
final defaultModalBindings = KeyBinding<ModalAction>()
  ..map(['enter'], ModalAction.confirm)
  ..map(['escape'], ModalAction.cancel);
