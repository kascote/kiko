// This example prints to stdout so it can be run and read directly.
// ignore_for_file: avoid_print

import 'package:plume/plume.dart';

/// Builds a tiny tree, drives one frame into a recording surface, and prints the
/// draw intents it emits. A real backend would draw into a terminal buffer
/// instead of recording.
void main() {
  // Styles are opaque tokens the engine carries but never inspects. Here they
  // are plain strings; a terminal backend would use its own style type.
  final tree = Container<String>(
    border: 'grey',
    child: Column<String>(
      children: [
        Text<String>([const TextRun('Hello, Plume', 'title')]),
        Text<String>([const TextRun('layout without a solver', 'body')]),
      ],
    ),
  );

  final surface = RecordingSurface<String>();
  renderFrame(tree, const Rect(0, 0, 27, 4), surface);

  surface.intents.forEach(print);
}
