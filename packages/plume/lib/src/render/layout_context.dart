import '../painting/text_measurer.dart';

/// Ambient inputs threaded down the tree during layout that a node may need but
/// that are not part of its box constraints.
///
/// Today it carries only the [TextMeasurer]: the seam through which a backend
/// injects real text measurement once, at the root, for every node below.
class LayoutContext {
  /// Creates a layout context backed by [measurer].
  const LayoutContext({required this.measurer});

  /// Measures and wraps text for this layout pass.
  final TextMeasurer measurer;
}
