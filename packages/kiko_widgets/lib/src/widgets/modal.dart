import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODAL MESSAGES
// ═══════════════════════════════════════════════════════════════════════════

/// Emitted by inner widget when user confirms.
///
/// Inner widget bundles data into [payload]. Parent receives this
/// after modal auto-dismisses.
class ModalConfirm<T> extends Msg {
  /// Data from the modal's inner widget.
  final T? payload;

  /// Creates a confirm message with optional payload.
  ModalConfirm([this.payload]);

  @override
  String toString() => 'ModalConfirm($payload)';
}

/// Emitted by inner widget when user cancels.
///
/// Parent receives this after modal auto-dismisses.
class ModalCancel extends Msg {
  /// Creates a cancel message.
  const ModalCancel();

  @override
  String toString() => 'ModalCancel()';
}

// ═══════════════════════════════════════════════════════════════════════════
// MODAL WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// Update function for modal's inner MVU.
typedef ModalUpdate<M> = (M, Cmd?) Function(M model, Msg msg);

/// View function for modal's inner MVU.
///
/// Receives the modal's constrained area, not the full viewport.
typedef ModalView<M> = void Function(M model, Rect area, Frame frame);

/// Modal container with inner MVU support.
///
/// Modal is a transparent container that:
/// - Captures all input events when open
/// - Routes events to inner widget's update
/// - Watches for [ModalConfirm]/[ModalCancel] from inner
/// - Auto-dismisses and forwards result to parent
///
/// ## Simple modal (static content)
///
/// ```dart
/// Modal.simple(
///   child: Text('Are you sure?'),
///   width: ConstraintPercent(50),
///   height: ConstraintLength(5),
/// )
/// ```
///
/// Default behavior: Enter → [ModalConfirm], ESC → [ModalCancel]
///
/// ## Custom modal (full MVU)
///
/// ```dart
/// Modal<FormModel>(
///   init: FormModel(),
///   update: formUpdate,
///   view: formView,
///   width: ConstraintPercent(60),
///   height: ConstraintLength(10),
/// )
/// ```
///
/// Inner update emits [ModalConfirm(data)] or [ModalCancel()] when done.
class Modal<M> implements Widget {
  /// Inner model state.
  final M _model;

  /// Inner update function.
  final ModalUpdate<M> _update;

  /// Inner view function.
  final ModalView<M> _view;

  /// Width constraint for the modal.
  final Constraint width;

  /// Height constraint for the modal.
  final Constraint height;

  /// Whether to dim the backdrop behind the modal.
  final bool dimBackdrop;

  /// Dim factor for backdrop (0.0 = black, 1.0 = unchanged).
  final double dimFactor;

  /// Creates a modal with custom inner MVU.
  const Modal({
    required M init,
    required ModalUpdate<M> update,
    required ModalView<M> view,
    required this.width,
    required this.height,
    this.dimBackdrop = true,
    this.dimFactor = 0.3,
  }) : _model = init,
       _update = update,
       _view = view;

  /// Creates a simple modal with static content.
  ///
  /// Default behavior:
  /// - Enter key → [ModalConfirm] with [confirmPayload]
  /// - ESC key → [ModalCancel]
  static Modal<void> simple({
    required Widget child,
    required Constraint width,
    required Constraint height,
    Object? confirmPayload,
    bool dimBackdrop = true,
    double dimFactor = 0.3,
  }) {
    return Modal<void>(
      init: null,
      update: (_, msg) => switch (msg) {
        KeyMsg(key: 'enter') => (null, Emit(ModalConfirm(confirmPayload))),
        KeyMsg(key: 'escape') => (null, const Emit(ModalCancel())),
        _ => (null, null),
      },
      view: (_, area, frame) => frame.renderWidget(child, area),
      width: width,
      height: height,
      dimBackdrop: dimBackdrop,
      dimFactor: dimFactor,
    );
  }

  /// Returns the current inner model.
  M get model => _model;

  /// Processes a message through the inner update.
  ///
  /// Returns (newModal, cmd). Used by [withModalCapture].
  (Modal<M>, Cmd?) processMsg(Msg msg) {
    final (newModel, cmd) = _update(_model, msg);
    final newModal = Modal<M>(
      init: newModel,
      update: _update,
      view: _view,
      width: width,
      height: height,
      dimBackdrop: dimBackdrop,
      dimFactor: dimFactor,
    );
    return (newModal, cmd);
  }

  @override
  void render(Rect area, Frame frame) {
    if (dimBackdrop) frame.dimBackdrop(factor: dimFactor);
    frame.renderModal(
      child: _ModalContent(_model, _view),
      width: width,
      height: height,
    );
  }
}

/// Internal widget that renders modal content with inner model.
class _ModalContent<M> implements Widget {
  final M _model;
  final ModalView<M> _view;

  const _ModalContent(this._model, this._view);

  @override
  void render(Rect area, Frame frame) {
    _view(_model, area, frame);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODAL CAPTURE HELPER
// ═══════════════════════════════════════════════════════════════════════════

/// Wraps update to capture events when modal is open.
///
/// When modal is active:
/// 1. Routes messages to modal's inner update
/// 2. Watches for [ModalConfirm]/[ModalCancel] in returned commands
/// 3. Auto-clears modal and forwards result to parent's update
///
/// ## Example
///
/// ```dart
/// final update = withModalCapture<AppModel>(
///   update: appUpdate,
///   getModal: (m) => m.modal,
///   setModal: (m, modal) => m.copyWith(modal: () => modal),
/// );
///
/// (AppModel, Cmd?) appUpdate(AppModel model, Msg msg) => switch (msg) {
///   ModalConfirm(:final payload) => (model.handleConfirm(payload), null),
///   ModalCancel() => (model, null),
///   KeyMsg(key: 'm') => (model.copyWith(modal: () => myModal), null),
///   _ => (model, null),
/// };
/// ```
Update<M> withModalCapture<M>({
  required Update<M> update,
  required Modal<dynamic>? Function(M model) getModal,
  required M Function(M model, Modal<dynamic>? modal) setModal,
}) {
  return (model, msg) {
    final modal = getModal(model);

    // No modal - pass to parent update
    if (modal == null) {
      return update(model, msg);
    }

    // Route to modal's inner update
    final (newModal, cmd) = modal.processMsg(msg);

    // Check if command is ModalConfirm or ModalCancel
    final (shouldDismiss, resultMsg) = _extractModalResult(cmd);

    if (shouldDismiss) {
      // Clear modal
      final clearedModel = setModal(model, null);
      // Forward result message to parent update
      if (resultMsg != null) {
        return update(clearedModel, resultMsg);
      }
      return (clearedModel, null);
    }

    // Stay in modal - update modal state
    final updatedModel = setModal(model, newModal);
    // Process other commands (not ModalConfirm/Cancel)
    return (updatedModel, cmd);
  };
}

/// Extracts ModalConfirm/ModalCancel from command.
///
/// Returns (shouldDismiss, resultMsg).
(bool, Msg?) _extractModalResult(Cmd? cmd) {
  return switch (cmd) {
    Emit(:final msg) when msg is ModalConfirm => (true, msg),
    Emit(:final msg) when msg is ModalCancel => (true, msg),
    Batch(:final cmds) => _extractFromBatch(cmds),
    _ => (false, null),
  };
}

/// Searches batch for ModalConfirm/ModalCancel.
(bool, Msg?) _extractFromBatch(List<Cmd> cmds) {
  for (final cmd in cmds) {
    if (cmd is Emit) {
      if (cmd.msg is ModalConfirm || cmd.msg is ModalCancel) {
        return (true, cmd.msg);
      }
    }
  }
  return (false, null);
}
