import 'package:plume/plume.dart' as plume;

import '../layout/rect.dart';
import 'paint_token.dart';

export 'package:plume/plume.dart'
    show
        Alignment,
        Axis,
        BoxConstraints,
        CrossAxisAlignment,
        EdgeInsets,
        FlexFit,
        LayoutContext,
        MainAxisAlignment,
        MainAxisSize,
        Size,
        StackFit,
        TextAlign,
        TextMeasurer,
        ViewportMetrics,
        ViewportTagEntry;

/// Kiko's plume vocabulary, pinned to [PaintToken].
///
/// Plume's layout types are generic over an opaque paint token so the engine
/// stays reusable — kiko instantiates that token with exactly one concrete type,
/// [PaintToken], everywhere. This file re-exports the plume enums and geometry
/// kiko composes with, and pins the two carrier types ([Node], [Surface]) to
/// [PaintToken] once, here, so the rest of kiko never writes
/// `plume.RenderNode<PaintToken>` and never imports `package:plume` directly.
///
/// The composable containers themselves (`Column`, `Row`, and friends) are
/// view wrappers and live in `containers.dart`.

/// A laid-out plume node carrying a [PaintToken].
typedef Node = plume.RenderNode<PaintToken>;

/// The draw target a laid-out tree paints [PaintToken]s onto. See plume's `Surface`.
typedef Surface = plume.Surface<PaintToken>;

/// A `Viewport`'s measurement callback: this frame's [plume.ViewportMetrics]
/// and the [Surface] the viewport is painting on.
typedef ViewportMeasureCallback = plume.ViewportMeasureCallback<PaintToken>;

/// Bridges kiko's cell [Rect] to plume's own geometry `Rect`.
///
/// The two carry the same numbers but are different types — kiko has its own
/// [Rect] with buffer helpers, plume has a geometry-only one, and the bridge
/// deliberately does not re-export plume's to avoid the name clash. This is the
/// one seam that converts between them, so a widget marking a paint-time hit
/// region (`RenderNode.markRegion`, whose rect is plume's) passes
/// `rect.toPlume()` and never has to import `package:plume` to name the type.
extension RectToPlume on Rect {
  /// This rect as a plume geometry rect, cell-for-cell.
  plume.Rect toPlume() => plume.Rect(x, y, width, height);
}
