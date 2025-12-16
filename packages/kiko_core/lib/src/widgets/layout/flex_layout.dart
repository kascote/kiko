import 'package:meta/meta.dart';

import '../../layout/flex.dart';
import '../../layout/layout.dart';
import '../../layout/margin.dart';
import '../../layout/rect.dart';
import '../../layout/spacing.dart';
import '../frame.dart';
import 'layout_child.dart';

/// A widget that arranges its children in a flex layout.
///
/// [FlexLayout] uses [Layout] internally to split the available area
/// among its children based on their constraints.
@immutable
class FlexLayout implements Widget {
  /// The direction of the layout (horizontal or vertical).
  final Direction direction;

  /// The margin around the layout.
  final Margin margin;

  /// How remaining space is distributed.
  final Flex flex;

  /// Spacing between children.
  final Spacing spacing;

  /// The children with their constraints.
  final List<LayoutChild> children;

  /// Creates a flex layout.
  FlexLayout({
    required this.direction,
    required this.children,
    this.margin = Margin.zero,
    this.flex = Flex.start,
    Spacing? spacing,
  }) : spacing = spacing ?? Space(0);

  @override
  void render(Rect area, Frame frame) {
    if (children.isEmpty) return;

    final layout = Layout(
      direction: direction,
      constraints: children.map((c) => c.constraint).toList(),
      margin: margin,
      flex: flex,
      spacing: spacing,
    );

    final rects = layout.areas(area);
    for (var i = 0; i < children.length; i++) {
      children[i].child.render(rects[i], frame);
    }
  }
}
