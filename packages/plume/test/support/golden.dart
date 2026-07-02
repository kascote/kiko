import 'package:plume/plume.dart';

/// Lays [root] out tightly at [size] (measuring with [measurer]), places it at
/// the origin, and returns a text dump of every node's type and absolute rect,
/// indented by depth.
///
/// This is a layout golden: readable, diff-friendly, and terminal-free.
String layoutGolden<T>(RenderNode<T> root, Size size, {TextMeasurer measurer = const MonospaceMeasurer()}) {
  root
    ..layout(BoxConstraints.tight(size), LayoutContext(measurer: measurer))
    ..place(Offset.zero);

  final buffer = StringBuffer();
  void walk(RenderNode<T> node, int depth) {
    final name = node.runtimeType.toString().split('<').first;
    buffer.writeln('${'  ' * depth}$name ${node.rect}');
    node.visitChildren((child) => walk(child, depth + 1));
  }

  walk(root, 0);
  return buffer.toString().trimRight();
}

/// Lays [root] out tightly at [size] (measuring with [measurer]), paints it into
/// a [RecordingSurface], and returns the draw intents it emitted, one string per
/// line.
///
/// This is a paint golden.
List<String> paintGolden<T>(RenderNode<T> root, Size size, {TextMeasurer measurer = const MonospaceMeasurer()}) {
  final surface = RecordingSurface<T>();
  root
    ..layout(BoxConstraints.tight(size), LayoutContext(measurer: measurer))
    ..place(Offset.zero)
    ..paint(surface);
  return surface.intents.map((intent) => intent.toString()).toList();
}

/// Asserts every intent in [intents] paints only inside [frame].
///
/// Each intent's painted region is its rect trimmed to the clip it carries, or
/// its full rect when it carries none; a text run's width is measured with
/// [measurer]. Throws a [StateError] naming the first intent whose region
/// escapes [frame]. A correctly clipped paint never overflows the frame the
/// root pushed, so this is the overflow-suite invariant.
void noOverflow<T>(List<DrawIntent<T>> intents, Rect frame, {TextMeasurer measurer = const MonospaceMeasurer()}) {
  for (final intent in intents) {
    final (footprint, clip) = switch (intent) {
      FillIntent<T>(:final rect, :final clip) => (rect, clip),
      BorderIntent<T>(:final rect, :final clip) => (rect, clip),
      TextIntent<T>(:final x, :final y, :final run, :final clip) => (Rect(x, y, measurer.widthOf(run), 1), clip),
    };
    final region = clip == null ? footprint : footprint.intersect(clip);
    if (!region.isEmpty && !frame.containsRect(region)) {
      throw StateError('intent paints outside frame $frame: $intent (region $region)');
    }
  }
}
