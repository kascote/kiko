import 'package:plume/plume.dart' as plume;

import '../layout/rect.dart';
import '../widgets/frame.dart';
import 'buffer_surface.dart';
import 'paint_token.dart';

/// Wraps an un-ported kiko [Widget] as a fixed-size leaf in a plume tree.
///
/// Use it while migrating a screen to plume: build the outer layout from plume
/// nodes and drop each not-yet-ported widget in as a `LegacyLeaf`, so the old
/// `render(Rect, Frame)` widgets keep working while the layout around them
/// moves over. When painted, the leaf hands its widget the rect it was placed
/// at and lets it draw straight into the buffer.
///
/// The leaf asks for [width] × [height] cells, but that size is clamped to the
/// constraints it is laid out under — so an enclosing `Expanded` or
/// `ConstrainedBox` overrides it, exactly like a plume `SizedBox`.
///
/// It draws only when painted through a [BufferSurface], the production surface
/// backed by a real buffer. Painting it into any other surface is a no-op,
/// since there is no buffer for the legacy widget to render into.
class LegacyLeaf extends plume.RenderNode<PaintToken> {
  /// Wraps [widget] as a leaf requesting [width] × [height] cells.
  LegacyLeaf(this.widget, {required this.width, required this.height});

  /// The un-ported kiko widget this leaf renders.
  final Widget widget;

  /// Requested width in cells, before constraints are applied.
  final int width;

  /// Requested height in cells, before constraints are applied.
  final int height;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) =>
      constraints.constrain(plume.Size(width, height));

  @override
  void paintSelf(plume.Surface<PaintToken> surface) {
    if (surface is! BufferSurface) return;

    // The active clip is this leaf's rect intersected with its ancestors: the
    // visible box, always inside the buffer. Handing the widget that region
    // draws it where it belongs and keeps its writes off the buffer's edge —
    // in ordinary layout the clip is exactly this leaf's rect.
    final clip = surface.clipRect ?? rect;
    if (clip.width <= 0 || clip.height <= 0) return;

    final area = Rect.create(x: clip.x, y: clip.y, width: clip.width, height: clip.height);
    widget.render(area, Frame(area, surface.buffer, 0));
  }
}
