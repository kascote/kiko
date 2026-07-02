import '../geometry/rect.dart';
import 'clipping_surface.dart';
import 'draw_intent.dart';

/// A [ClippingSurface] that records every (already clipped) draw call instead
/// of rendering it.
///
/// The recorded [intents] list, in call order, *is* the paint golden: build a
/// tree, paint it into a `RecordingSurface`, and assert on the intents — no
/// terminal required. The clip stack is enforced by the base class, so an
/// intent that overflowed its box carries the clip it should have been trimmed
/// to.
class RecordingSurface<S> extends ClippingSurface<S> {
  /// The draw calls received so far, in the order they arrived.
  final List<DrawIntent<S>> intents = <DrawIntent<S>>[];

  @override
  void rawDrawText(int x, int y, String run, S style, Rect? clip) =>
      intents.add(TextIntent<S>(x, y, run, style, clip: clip));

  @override
  void rawFillRect(Rect rect, S style, Rect? clip) => intents.add(FillIntent<S>(rect, style, clip: clip));

  @override
  void rawDrawBorder(Rect rect, S style, Rect? clip) => intents.add(BorderIntent<S>(rect, style, clip: clip));
}
