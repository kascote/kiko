import 'package:kiko/kiko.dart';

import 'modal_model.dart';
import 'types.dart';

/// Frames the view [content] builds as a dialog: a bordered box with a
/// painted ground, tagged with [id] so a click inside it resolves back through
/// [HitMap.hitId].
///
/// The dialog is a pane that re-grounds. It calls [content] with
/// `resolver.on(resolver.tones.surface)`, so every widget [content] returns
/// lifts its states from the dialog's ground. Build the widgets with that
/// resolver, not with [resolver]. Pass [ModalModel]'s id for the static
/// confirm/cancel case, or any other widget model's id to frame a fully
/// custom inner MVU the same way.
///
/// The frame and the ground paint through the same surface-bound resolver.
Node modalDialog({
  required String id,
  required StyleResolver resolver,
  required View Function(StyleResolver surface) content,
  BorderType border = BorderType.rounded,
  Style? borderStyle,
  Style? ground,
  List<Line> topTitles = const <Line>[],
}) {
  final surface = resolver.on(resolver.tones.surface);
  return Container(
    border: border,
    borderStyle: borderStyle ?? surface.border(const {}),
    ground: ground ?? surface.ground(surface.tones.surface),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: topTitles,
    child: content(surface),
  ).build()..tag = IdTag(id);
}

/// The centred [width]x[height] rect within [area], in frame-absolute
/// coordinates.
///
/// [area] is the full viewport — pass [Frame.area]. Sizing is fixed rather
/// than constraint-based because a dialog's whole point is a stable size
/// regardless of what's behind it. Pass the result to [Frame.renderLayer].
Rect centeredRect({required Rect area, required int width, required int height}) {
  final left = ((area.width - width) / 2).round().clamp(0, area.width);
  final top = ((area.height - height) / 2).round().clamp(0, area.height);
  return Rect.create(x: area.x + left, y: area.y + top, width: width, height: height);
}

/// Renders the node [base] builds, then, when [dialog] is non-null, renders a
/// full-frame barrier under [id] and layers [dialog] centred over it at
/// [width]x[height].
///
/// While a dialog is open, [base] receives `resolver.deEmphasised`, so the
/// host's chrome and widgets read one step quieter. With no dialog, [base]
/// receives [resolver] unchanged. Build the dialog from the un-quieted
/// [resolver] with [modalDialog].
///
/// [dialog] renders through [Frame.renderLayer]: a clean slate composited
/// opaquely at the centred rect, so nothing painted underneath shows through
/// it.
///
/// The barrier is a [Tagged.scope] under [id] wrapping an empty
/// [RegionMark], rendered through [Frame.render] between the base and the
/// dialog layer. A root lays out tight to the frame. A container with no
/// ground paints no cell, so the barrier covers the frame without altering
/// the base.
///
/// `HitMap` answers [id] for both nodes: the dialog layer inside its own
/// rect, the barrier everywhere else. A press anywhere on screen therefore
/// addresses the modal, and [HitMap.regionAt] tells the two apart by
/// [ModalBarrierRegion].
///
/// [id] must be the modal's id — the same id [dialog]'s root already carries
/// as its [IdTag] — and non-null exactly when [dialog] is non-null.
void renderModalOverlay(
  Frame frame, {
  required Node Function(StyleResolver host) base,
  required StyleResolver resolver,
  required int width,
  required int height,
  Node? dialog,
  String? id,
}) {
  assert(
    (id == null) == (dialog == null),
    'renderModalOverlay: id must be given exactly when dialog is, so the '
    "barrier and the dialog layer can share the modal's id.",
  );
  assert(
    dialog == null || dialog.tag == IdTag(id!),
    "renderModalOverlay: dialog's root must carry IdTag(id) — build it with "
    'modalDialog(id: id, ...) or tag it yourself.',
  );
  frame.render(NodeView(base(dialog == null ? resolver : resolver.deEmphasised)));
  if (dialog == null) return;
  frame.render(Tagged.scope(id!, const RegionMark(ModalBarrierRegion(), Container(child: SizedBox()))));
  frame.renderLayer(NodeView(dialog), centeredRect(area: frame.area, width: width, height: height));
}
