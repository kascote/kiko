import 'dart:math' as math;

import 'package:kiko/kiko.dart';

/// A widget that insets its child by the given padding.
class Padding implements Widget {
  /// The amount of space to inset the child.
  final EdgeInsets padding;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Creates a widget that insets its child.
  const Padding({
    required this.padding,
    required this.child,
  });

  @override
  void render(Rect area, Frame frame) {
    final width = math.max(0, area.width - padding.left - padding.right);
    final height = math.max(0, area.height - padding.top - padding.bottom);

    if (width > 0 && height > 0) {
      final innerArea = Rect.create(
        x: area.x + padding.left,
        y: area.y + padding.top,
        width: width,
        height: height,
      );
      child.render(innerArea, frame);
    }
  }
}
