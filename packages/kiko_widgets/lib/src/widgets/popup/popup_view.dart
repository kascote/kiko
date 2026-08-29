import 'package:kiko/kiko.dart';

import 'popup_placement.dart';

/// Paints an anchored popup as a layer on top of an already-rendered
/// [frame].
///
/// The popup renders into its own clean slate and composites opaquely over
/// [frame]; a spot inside its rect that the popup never paints comes out
/// blank, never the base content underneath. Call it after rendering the
/// base tree that carries the anchor at
/// [anchorPath] — its full hit path, such as `'comboId/fieldId'`. Pass the
/// [requestedHeight] in rows, a [width], and [popupBuilder] to build the
/// popup's node, tags included; this helper adds no chrome of its own. Pass
/// the standing [decision] back on every paint of an open popup — `null`
/// while closed — and report the return value to the frame as a
/// `PopupPlaced` addressed to the model that owns the popup.
///
/// The anchor's rect comes from `frame.hits.rectOf(anchorPath)`, so it must
/// already be definite: a bare scope path has no rect and answers `null`
/// here too. When [anchorPath] has no rect this frame, no overlay paints
/// and [decision] is returned unchanged.
///
/// Placement is decided once per open session and held until [frame]'s area
/// changes, per [PopupPlacement]. [popupBuilder] receives the decided
/// height, which may be smaller than [requestedHeight] when neither side had
/// room for it in full. The popup's left edge aligns with the anchor's,
/// clamped so [width] never overhangs the viewport.
PopupPlacement? renderAnchoredPopup(
  Frame frame, {
  required String anchorPath,
  required int requestedHeight,
  required int width,
  required Node Function(int height) popupBuilder,
  PopupPlacement? decision,
}) {
  final anchor = frame.hits.rectOf(anchorPath);
  if (anchor == null) return decision;

  final area = frame.area;
  final placement = decision != null && decision.decidedAgainst == area
      ? decision
      : _decide(anchor: anchor, area: area, requestedHeight: requestedHeight);

  var left = anchor.left;
  if (left + width > area.right) left = area.right - width;
  if (left < area.left) left = area.left;
  final top = placement.side == PopupSide.below ? anchor.bottom : anchor.top - placement.height;

  frame.renderLayer(
    NodeView(popupBuilder(placement.height)),
    Rect.create(x: left, y: top, width: width, height: placement.height),
  );

  return placement;
}

/// Applies the placement rule: below the anchor when [requestedHeight] fits
/// there, above when below does not fit but above does, and otherwise the
/// side with more room, with the height shrunk to fit it.
PopupPlacement _decide({required Rect anchor, required Rect area, required int requestedHeight}) {
  final roomBelow = area.bottom - anchor.bottom;
  final roomAbove = anchor.top - area.top;
  if (requestedHeight <= roomBelow) {
    return PopupPlacement(side: PopupSide.below, height: requestedHeight, decidedAgainst: area);
  }
  if (requestedHeight <= roomAbove) {
    return PopupPlacement(side: PopupSide.above, height: requestedHeight, decidedAgainst: area);
  }
  final belowIsLarger = roomBelow >= roomAbove;
  final room = belowIsLarger ? roomBelow : roomAbove;
  return PopupPlacement(
    side: belowIsLarger ? PopupSide.below : PopupSide.above,
    height: room < 0 ? 0 : room,
    decidedAgainst: area,
  );
}
