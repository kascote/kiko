import 'package:meta/meta.dart';

import '../geometry/box_constraints.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../painting/surface.dart';
import 'layout_context.dart';
import 'render_node.dart';
import 'single_child_node.dart';

/// A tagged descendant's row extent inside a [Viewport]'s content.
///
/// Both fields are content-relative — measured from the top of the content,
/// not the viewport — so a range stays the same as the viewport scrolls.
@immutable
class ViewportTagRange {
  /// Creates a range starting at content row [top], spanning [height] rows.
  const ViewportTagRange(this.top, this.height);

  /// The first content row this descendant occupies.
  final int top;

  /// How many rows this descendant spans.
  final int height;

  @override
  bool operator ==(Object other) => other is ViewportTagRange && other.top == top && other.height == height;

  @override
  int get hashCode => Object.hash(top, height);

  @override
  String toString() => 'ViewportTagRange($top, $height)';
}

/// The geometry a [Viewport] measured while painting a single frame.
@immutable
class ViewportMetrics {
  /// Creates a snapshot of [viewportRows], [contentRows], and [tagRanges].
  const ViewportMetrics({required this.viewportRows, required this.contentRows, required this.tagRanges});

  /// The viewport's own height, in rows.
  final int viewportRows;

  /// The content's full height, in rows — may be taller than [viewportRows].
  final int contentRows;

  /// Every tagged descendant's content-relative row range, keyed by its tag.
  final Map<Object, ViewportTagRange> tagRanges;
}

/// Called after each paint with the [Viewport]'s latest [ViewportMetrics].
typedef ViewportMeasureCallback = void Function(ViewportMetrics metrics);

/// Shows a scrolled window onto a taller [child].
///
/// The child is laid out with its main (vertical) axis unbounded and its
/// cross (horizontal) axis tight to the incoming width, so it reports its
/// full intrinsic height; the viewport then places it at
/// `Offset(0, -offset)` and sizes itself to the box its parent gave it.
/// Paint clipping falls out of the base [paint] pass for free — it already
/// pushes this node's [rect] as the active clip before descending — so
/// content above or below the window is cut off without any code here.
///
/// Plume holds no scroll state: [offset] is a per-frame input the owner
/// (typically a model) computes and clamps; a fresh tree is built every
/// frame, so there is nothing to reset between scrolls.
class Viewport<T> extends SingleChildNode<T> {
  /// Creates a viewport scrolled [scrollOffset] rows into [child], optionally
  /// reporting geometry to [onMeasure] after each paint.
  Viewport({required this.scrollOffset, required RenderNode<T> child, this.onMeasure}) : super(child);

  /// How many content rows are scrolled past the top of the viewport.
  ///
  /// Owned and clamped by the caller; this node places the child at exactly
  /// `-scrollOffset` without questioning it. Distinct from the inherited
  /// [RenderNode.offset], which is this node's own placement relative to its
  /// parent.
  final int scrollOffset;

  /// Fired from [paintSelf] with this frame's [ViewportMetrics], or `null` to
  /// skip measurement.
  final ViewportMeasureCallback? onMeasure;

  int _contentRows = 0;

  @override
  bool get clipsHits => true;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final size = constraints.biggest;
    final childSize = child.layout(BoxConstraints(minW: size.w, maxW: size.w), context);
    _contentRows = childSize.h;
    child.offset = Offset(0, -scrollOffset);
    return size;
  }

  @override
  void paintSelf(Surface<T> surface) {
    final callback = onMeasure;
    if (callback == null) {
      return;
    }
    final contentTop = child.rect.top;
    final tagRanges = <Object, ViewportTagRange>{};
    void walk(RenderNode<T> node) {
      final tag = node.tag;
      if (tag != null) {
        tagRanges[tag] = ViewportTagRange(node.rect.top - contentTop, node.rect.height);
      }
      node.visitChildren(walk);
    }

    walk(child);
    callback(ViewportMetrics(viewportRows: rect.height, contentRows: _contentRows, tagRanges: tagRanges));
  }
}
