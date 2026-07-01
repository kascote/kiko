import 'package:plume/plume.dart';

/// Lays [root] out tightly at [size] (measuring with [measurer]), places it at
/// the origin, and returns a text dump of every node's type and absolute rect,
/// indented by depth.
///
/// This is a layout golden: readable, diff-friendly, and terminal-free.
String layoutGolden<S>(RenderNode<S> root, Size size, {TextMeasurer measurer = const MonospaceMeasurer()}) {
  root
    ..layout(BoxConstraints.tight(size), LayoutContext(measurer: measurer))
    ..place(Offset.zero);

  final buffer = StringBuffer();
  void walk(RenderNode<S> node, int depth) {
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
List<String> paintGolden<S>(RenderNode<S> root, Size size, {TextMeasurer measurer = const MonospaceMeasurer()}) {
  final surface = RecordingSurface<S>();
  root
    ..layout(BoxConstraints.tight(size), LayoutContext(measurer: measurer))
    ..place(Offset.zero)
    ..paint(surface);
  return surface.intents.map((intent) => intent.toString()).toList();
}
