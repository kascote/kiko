import 'package:plume/plume.dart' as plume;

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
        TextMeasurer;

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
