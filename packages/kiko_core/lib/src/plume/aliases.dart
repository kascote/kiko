import 'package:plume/plume.dart' as plume;

import 'paint_token.dart';

export 'package:plume/plume.dart'
    show
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
        TextMeasurer;

/// Kiko's plume vocabulary, pinned to [PaintToken].
///
/// Plume's node types are generic over an opaque paint token so the layout
/// engine stays reusable — kiko instantiates that token with exactly one
/// concrete type, [PaintToken], everywhere. These typedefs pin `T` to it once,
/// here, so the rest of kiko (examples, `kiko_widgets`) never writes
/// `plume.Column<PaintToken>` and never imports `package:plume` directly.

/// A laid-out plume node carrying a [PaintToken].
typedef Node = plume.RenderNode<PaintToken>;

/// A vertical flex container. See plume's `Column`.
typedef Column = plume.Column<PaintToken>;

/// A horizontal flex container. See plume's `Row`.
typedef Row = plume.Row<PaintToken>;

/// A node that overlays its children. See plume's `Stack`.
typedef Stack = plume.Stack<PaintToken>;

/// A [Stack] child positioned by offsets from its edges. See plume's `Positioned`.
typedef Positioned = plume.Positioned<PaintToken>;

/// A node with a fixed size. See plume's `SizedBox`.
typedef SizedBox = plume.SizedBox<PaintToken>;

/// A flex child that expands to fill available space. See plume's `Expanded`.
typedef Expanded = plume.Expanded<PaintToken>;

/// A flex child with a flex factor. See plume's `Flexible`.
typedef Flexible = plume.Flexible<PaintToken>;

/// A node that constrains its child. See plume's `ConstrainedBox`.
typedef ConstrainedBox = plume.ConstrainedBox<PaintToken>;

/// A node that sizes, pads, and/or colors a box around its child. See plume's `Container`.
typedef Container = plume.Container<PaintToken>;

/// A node that pads its child. See plume's `Padding`.
typedef Padding = plume.Padding<PaintToken>;

/// The draw target a laid-out tree paints [PaintToken]s onto. See plume's `Surface`.
typedef Surface = plume.Surface<PaintToken>;
