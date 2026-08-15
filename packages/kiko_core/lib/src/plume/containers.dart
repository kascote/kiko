import 'package:plume/plume.dart' as plume;

import '../style.dart';
import '../text/line.dart';
import '../widgets/border_type.dart';
import '../widgets/hit_tag.dart';
import 'aliases.dart';
import 'paint_token.dart';
import 'view.dart';

/// The composable containers kiko lays out with — [View] wrappers over plume's
/// layout nodes.
///
/// Each container is an immutable [View]: it holds its children as views and,
/// on [View.build], inflates a fresh plume node with each child built in turn.
/// Children are typed [View], so a non-view child is a compile error rather than
/// a paint-time surprise.
///
/// Each container also takes an optional `id:`, which stamps [IdTag] on the
/// node it builds. This is the same tag `Tagged(id, child)` would stamp, so
/// either spelling produces the same tree; `id:` is the shorter one when the
/// caller is already constructing the container.

/// Stamps [node] with [IdTag] when [id] is not `null`, otherwise returns it
/// untouched.
///
/// Shared by every container's `id:` parameter, so each behaves like
/// `Tagged`: a node already carrying a tag must not be silently overwritten.
Node _withId(Node node, String? id) {
  if (id == null) return node;
  assert(
    node.tag == null,
    'id: "$id" would overwrite the tag "${node.tag}" this node already '
    'carries. Built-in widgets tag themselves with their model id — wrap a '
    'container around one instead, or address it by its own id.',
  );
  return node..tag = IdTag(id);
}

/// A vertical stack of children, laid out top to bottom.
final class Column implements View {
  /// Stacks [children] top to bottom, optionally tagged with [id].
  const Column({
    required this.children,
    this.mainAxis = plume.MainAxisAlignment.start,
    this.crossAxis = plume.CrossAxisAlignment.start,
    this.mainAxisSize = plume.MainAxisSize.max,
    this.id,
  });

  /// The children, laid out in order from top to bottom.
  final List<View> children;

  /// How leftover vertical space is distributed.
  final plume.MainAxisAlignment mainAxis;

  /// How each child is aligned or stretched horizontally.
  final plume.CrossAxisAlignment crossAxis;

  /// Whether the column fills the available height or shrink-wraps its children.
  final plume.MainAxisSize mainAxisSize;

  /// The stable id this node answers to, or `null` to leave it untagged.
  final String? id;

  @override
  Node build() => _withId(
    plume.Column<PaintToken>(
      children: [for (final c in children) c.build()],
      mainAxisAlignment: mainAxis,
      crossAxisAlignment: crossAxis,
      mainAxisSize: mainAxisSize,
    ),
    id,
  );
}

/// A horizontal row of children, laid out left to right.
final class Row implements View {
  /// Lays [children] out left to right, optionally tagged with [id].
  const Row({
    required this.children,
    this.mainAxis = plume.MainAxisAlignment.start,
    this.crossAxis = plume.CrossAxisAlignment.start,
    this.mainAxisSize = plume.MainAxisSize.max,
    this.id,
  });

  /// The children, laid out in order from left to right.
  final List<View> children;

  /// How leftover horizontal space is distributed.
  final plume.MainAxisAlignment mainAxis;

  /// How each child is aligned or stretched vertically.
  final plume.CrossAxisAlignment crossAxis;

  /// Whether the row fills the available width or shrink-wraps its children.
  final plume.MainAxisSize mainAxisSize;

  /// The stable id this node answers to, or `null` to leave it untagged.
  final String? id;

  @override
  Node build() => _withId(
    plume.Row<PaintToken>(
      children: [for (final c in children) c.build()],
      mainAxisAlignment: mainAxis,
      crossAxisAlignment: crossAxis,
      mainAxisSize: mainAxisSize,
    ),
    id,
  );
}

/// A flex child that takes a share of the free main-axis space proportional to
/// [flex], and may be smaller than its share.
final class Flexible implements View {
  /// Gives [child] a [flex] share, filled according to [fit].
  const Flexible({required this.child, this.flex = 1, this.fit = plume.FlexFit.loose});

  /// The wrapped child.
  final View child;

  /// This child's share of the free space, relative to its siblings.
  final int flex;

  /// Whether the child must fill its share or may be smaller.
  final plume.FlexFit fit;

  @override
  Node build() => plume.Flexible<PaintToken>(flex: flex, fit: fit, child: child.build());
}

/// A flex child that expands to fill its whole share of the main axis.
final class Expanded implements View {
  /// Expands [child] with the given [flex] share.
  const Expanded({required this.child, this.flex = 1});

  /// The wrapped child.
  final View child;

  /// This child's share of the free space, relative to its siblings.
  final int flex;

  @override
  Node build() => plume.Expanded<PaintToken>(flex: flex, child: child.build());
}

/// Layers its children, painting each over the one before it.
final class Stack implements View {
  /// Layers [children], aligned by [alignment] and sized per [fit], optionally
  /// tagged with [id].
  const Stack({
    required this.children,
    this.alignment = plume.Alignment.topLeft,
    this.fit = plume.StackFit.loose,
    this.id,
  });

  /// The children, painted back to front in order.
  final List<View> children;

  /// Where each non-positioned child sits within the stack's extra space.
  final plume.Alignment alignment;

  /// How non-positioned children are sized.
  final plume.StackFit fit;

  /// The stable id this node answers to, or `null` to leave it untagged.
  final String? id;

  @override
  Node build() => _withId(
    plume.Stack<PaintToken>(
      children: [for (final c in children) c.build()],
      alignment: alignment,
      fit: fit,
    ),
    id,
  );
}

/// Pins its child to chosen edges of a [Stack].
final class Positioned implements View {
  /// Positions [child] using any mix of edges and an explicit size.
  const Positioned({
    required this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
  });

  /// The wrapped child.
  final View child;

  /// Distance from the stack's left edge, or `null` to leave the left free.
  final int? left;

  /// Distance from the stack's top edge, or `null` to leave the top free.
  final int? top;

  /// Distance from the stack's right edge, or `null` to leave the right free.
  final int? right;

  /// Distance from the stack's bottom edge, or `null` to leave the bottom free.
  final int? bottom;

  /// Explicit width, used when [left] and [right] do not already fix it.
  final int? width;

  /// Explicit height, used when [top] and [bottom] do not already fix it.
  final int? height;

  @override
  Node build() => plume.Positioned<PaintToken>(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    width: width,
    height: height,
    child: child.build(),
  );
}

/// Reserves space for [child] without showing it.
///
/// [child] is laid out and placed exactly as it would be if it were on screen —
/// its size still counts toward whatever sizes this node — but nothing under it
/// paints, and no pointer event can reach it. Since [Stack] already sizes itself
/// to its largest non-positioned child, wrapping an alternative in `Offstage`
/// inside a [Stack] reserves room for the larger of a set of interchangeable
/// children, so the stack never resizes when which child is active changes.
final class Offstage implements View {
  /// Reserves space for [child] without painting or hit-testing it.
  const Offstage({required this.child});

  /// The wrapped child.
  final View child;

  @override
  Node build() => plume.Offstage<PaintToken>(child: child.build());
}

/// A fixed-size box that draws nothing — a spacer or minimum-size placeholder.
final class SizedBox implements View {
  /// Creates a box [width] cells wide and [height] cells tall.
  const SizedBox({this.width = 0, this.height = 0});

  /// The requested width in cells, before constraints are applied.
  final int width;

  /// The requested height in cells, before constraints are applied.
  final int height;

  @override
  Node build() => plume.SizedBox<PaintToken>(width: width, height: height);
}

/// Applies [additionalConstraints] to its child on top of the incoming ones.
final class ConstrainedBox implements View {
  /// Constrains [child] further with [additionalConstraints].
  const ConstrainedBox({required this.additionalConstraints, required this.child});

  /// The extra bounds to impose on the child.
  final plume.BoxConstraints additionalConstraints;

  /// The wrapped child.
  final View child;

  @override
  Node build() => plume.ConstrainedBox<PaintToken>(
    additionalConstraints: additionalConstraints,
    child: child.build(),
  );
}

/// A single-child box that can size itself, pad its child, paint a background
/// and border, and carry titles on its top and bottom edges.
///
/// Decoration is described in kiko's own vocabulary: a [border] type and
/// [borderStyle] for the frame, a [background] style for the fill. [build] turns
/// each into the paint token plume carries — no caller assembles one.
/// [topTitles] and [bottomTitles] are the one TUI-specific extension over the
/// Flutter shape — each title line becomes a label riding its edge, packed from
/// the start, and keeps its multi-colour styling because every title inflates
/// through [Line.build] into a real text node.
final class Container implements View {
  /// Wraps [child] with optional sizing, decoration, edge titles, and an
  /// [id] tag.
  const Container({
    required this.child,
    this.padding = plume.EdgeInsets.zero,
    this.width,
    this.height,
    this.background = const Style(),
    this.border = BorderType.none,
    this.borderStyle = const Style(),
    this.topTitles = const <Line>[],
    this.bottomTitles = const <Line>[],
    this.id,
  });

  /// The wrapped child.
  final View child;

  /// Inner padding around the child.
  final plume.EdgeInsets padding;

  /// A fixed width in cells, or `null` to size to the child.
  final int? width;

  /// A fixed height in cells, or `null` to size to the child.
  final int? height;

  /// The fill painted behind the child, or an empty style for no fill.
  final Style background;

  /// The border glyph set drawn around the box, or [BorderType.none] for no
  /// border.
  final BorderType border;

  /// The colour and modifiers of the border glyphs.
  final Style borderStyle;

  /// The titles riding on the top edge, packed from the start.
  final List<Line> topTitles;

  /// The titles riding on the bottom edge, packed from the start.
  final List<Line> bottomTitles;

  /// The stable id this node answers to, or `null` to leave it untagged.
  final String? id;

  @override
  Node build() => _withId(
    plume.Container<PaintToken>(
      padding: padding,
      width: width,
      height: height,
      background: background == const Style() ? null : PaintToken(background),
      border: border == BorderType.none ? null : PaintToken(borderStyle, border: border.symbols),
      child: child.build(),
      labels: <plume.EdgeLabel<PaintToken>>[
        for (final line in topTitles) _titleLabel(line, plume.EdgeSide.top),
        for (final line in bottomTitles) _titleLabel(line, plume.EdgeSide.bottom),
      ],
    ),
    id,
  );

  /// Wraps a title [line] as an edge label at the start of [side].
  static plume.EdgeLabel<PaintToken> _titleLabel(Line line, plume.EdgeSide side) =>
      plume.EdgeLabel<PaintToken>(child: line.build(), side: side);
}

/// Insets its child by [insets], reporting a size that includes the padding.
final class Padding implements View {
  /// Pads [child] by [insets].
  const Padding({required this.insets, required this.child});

  /// The cell insets around the child.
  final plume.EdgeInsets insets;

  /// The wrapped child.
  final View child;

  @override
  Node build() => plume.Padding<PaintToken>(insets: insets, child: child.build());
}

/// Sizes to the available space and positions its child within it by
/// [alignment].
final class Align implements View {
  /// Aligns [child] within this box using [alignment].
  const Align({required this.alignment, required this.child});

  /// Where the child sits within the extra space.
  final plume.Alignment alignment;

  /// The wrapped child.
  final View child;

  @override
  Node build() => plume.Align<PaintToken>(alignment: alignment, child: child.build());
}

/// Centers its child within the available space.
final class Center implements View {
  /// Centers [child].
  const Center({required this.child});

  /// The wrapped child.
  final View child;

  @override
  Node build() => plume.Center<PaintToken>(child: child.build());
}
