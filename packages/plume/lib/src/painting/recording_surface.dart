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
class RecordingSurface<T> extends ClippingSurface<T> {
  /// The draw calls received so far, in the order they arrived.
  final List<DrawIntent<T>> intents = <DrawIntent<T>>[];

  @override
  void rawDrawText(int x, int y, String run, T token, Rect? clip) =>
      intents.add(TextIntent<T>(x, y, run, token, clip: clip));

  @override
  void rawFillRect(Rect rect, T token, Rect? clip) => intents.add(FillIntent<T>(rect, token, clip: clip));

  @override
  void rawDrawBorder(Rect rect, T token, Rect? clip) => intents.add(BorderIntent<T>(rect, token, clip: clip));
}
