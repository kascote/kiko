import 'package:meta/meta.dart';

import '../geometry/box_constraints.dart';
import '../geometry/edge_insets.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../painting/surface.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';

/// Which horizontal edge of a [Container] a label rides on.
///
/// Labels live only on the top and bottom rows; the left and right edges are a
/// single column with no room for text.
enum EdgeSide {
  /// The top row.
  top,

  /// The bottom row.
  bottom,
}

/// Where a label sits within its edge, between the two corners.
enum LabelAlign {
  /// Packed against the left corner.
  start,

  /// Centered between the corners.
  center,

  /// Packed against the right corner.
  end,
}

/// A label riding on one edge of a [Container].
///
/// The [child] is any node — usually a one-line run of text — dropped into the
/// single-row band along its [side] and positioned within that band by [align].
/// Several labels sharing a side and alignment pack together with a one-cell gap.
@immutable
class EdgeLabel<T> {
  /// Creates a label drawing [child] on [side], placed by [align].
  const EdgeLabel({required this.child, this.side = EdgeSide.top, this.align = LabelAlign.start});

  /// The node drawn in the edge band.
  final RenderNode<T> child;

  /// The edge the label sits on.
  final EdgeSide side;

  /// How the label is placed between the box corners.
  final LabelAlign align;
}

/// A single-child box that can size itself, pad its child, paint a background
/// and border, and carry labels on its top and bottom edges.
///
/// The box is a decorated frame around one [child]. [width]/[height] become
/// tight constraints enforced against the incoming ones, forcing a size
/// regardless of the child; layout then insets the child by the border — one
/// cell on each side when [border] is present — plus any [padding]. A label on
/// an edge reserves that edge's row even with no border, so a titled but
/// borderless box insets its child the same way a bordered one does. Paint
/// fills the [background], strokes the [border], draws the child, and lays
/// each of [labels] over the border on its edge. Every appearance — the border
/// glyphs and colour, the fill — rides in an opaque paint token the box never
/// inspects; only the surface reads it.
///
/// The border is uniform: one token strokes all four sides at once.
class Container<T> extends RenderNode<T> {
  /// Wraps [child] with optional sizing, decoration, and edge [labels].
  Container({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.background,
    this.border,
    this.labels = const [],
  });

  /// The node laid out in the inner rect.
  final RenderNode<T> child;

  /// Inner padding between the border and the child.
  final EdgeInsets padding;

  /// A fixed width in cells, or `null` to size to the child.
  final int? width;

  /// A fixed height in cells, or `null` to size to the child.
  final int? height;

  /// The fill paint token, or `null` for no fill.
  final T? background;

  /// The border paint token, or `null` for no border.
  final T? border;

  /// The labels drawn on the top and bottom edges.
  final List<EdgeLabel<T>> labels;

  @override
  List<RenderNode<T>> get children => <RenderNode<T>>[child, for (final label in labels) label.child];

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final edge = border != null ? 1 : 0;
    final hasTop = labels.any((label) => label.side == EdgeSide.top);
    final hasBottom = labels.any((label) => label.side == EdgeSide.bottom);

    // A border reserves a cell on every side; a title reserves the top or bottom
    // row on its own even without a border, so the child clears it either way.
    final left = padding.left + edge;
    final right = padding.right + edge;
    final top = padding.top + (border != null || hasTop ? 1 : 0);
    final bottom = padding.bottom + (border != null || hasBottom ? 1 : 0);
    final horizontal = left + right;
    final vertical = top + bottom;

    var box = constraints;
    final w = width;
    final h = height;
    if (w != null || h != null) {
      box = BoxConstraints(
        minW: w ?? box.minW,
        maxW: w ?? box.maxW,
        minH: h ?? box.minH,
        maxH: h ?? box.maxH,
      ).enforce(constraints);
    }

    final childSize = child.layout(box.deflate(horizontal, vertical), context);
    child.offset = Offset(left, top);
    final size = box.constrain(Size(childSize.w + horizontal, childSize.h + vertical));

    _layoutLabels(context, size, edge);
    return size;
  }

  /// Lays out and positions every label within its edge's row.
  ///
  /// The band spans from just inside the left corner to just inside the right
  /// corner; labels are grouped by alignment and each group packed within it.
  void _layoutLabels(LayoutContext context, Size box, int edge) {
    final bandLeft = edge;
    final rawWidth = box.w - edge - edge;
    final bandWidth = rawWidth < 0 ? 0 : rawWidth;

    for (final side in EdgeSide.values) {
      final row = side == EdgeSide.top ? 0 : box.h - 1;
      for (final align in LabelAlign.values) {
        final group = <EdgeLabel<T>>[
          for (final label in labels)
            if (label.side == side && label.align == align) label,
        ];
        if (group.isEmpty) continue;
        _placeGroup(context, group, bandLeft, bandWidth, row, align);
      }
    }
  }

  /// Packs one alignment group into its band on [row], laying each label out
  /// against the band width and separating same-group labels by one cell.
  void _placeGroup(
    LayoutContext context,
    List<EdgeLabel<T>> group,
    int bandLeft,
    int bandWidth,
    int row,
    LabelAlign align,
  ) {
    final widths = <int>[];
    var total = 0;
    for (final label in group) {
      final size = label.child.layout(BoxConstraints.loose(Size(bandWidth, 1)), context);
      widths.add(size.w);
      total += size.w;
    }
    total += group.length - 1; // one-cell gap between neighbours in the group

    final bandRight = bandLeft + bandWidth;
    var x = switch (align) {
      LabelAlign.start => bandLeft,
      LabelAlign.center => bandLeft + (bandWidth - total) ~/ 2,
      LabelAlign.end => bandRight - total,
    };
    if (x < bandLeft) x = bandLeft; // an over-wide group never spills past a corner

    for (var i = 0; i < group.length; i++) {
      group[i].child.offset = Offset(x, row);
      x += widths[i] + 1;
    }
  }

  @override
  void paintSelf(Surface<T> surface) {
    final fill = background;
    if (fill != null) {
      surface.fillRect(rect, fill);
    }
    final stroke = border;
    if (stroke != null) {
      surface.drawBorder(rect, stroke);
    }
  }
}
