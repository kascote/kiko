import 'package:kiko/kiko.dart';

import 'popup_placement.dart';

/// Where an anchored popup landed: the [PopupPlacement] its paint decided.
///
/// The view that paints the popup reports one through `Frame.report`,
/// addressed to the widget that owns the popup, with the decision
/// `renderAnchoredPopup` returned. The owner's `update` stores it, and the
/// next paint passes it back as the standing decision so the popup keeps one
/// side and height for the whole open session.
class PopupPlaced extends FrameReport {
  /// Creates a report that the popup owned by [id] was placed by [placement].
  const PopupPlaced(super.id, this.placement);

  /// The placement the popup was painted with.
  final PopupPlacement placement;
}
