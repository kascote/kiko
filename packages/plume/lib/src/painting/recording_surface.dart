import '../geometry/rect.dart';
import 'draw_intent.dart';
import 'surface.dart';

/// A [Surface] that records every draw call instead of rendering it.
///
/// The recorded [intents] list, in call order, *is* the paint golden: build a
/// tree, paint it into a `RecordingSurface`, and assert on the intents — no
/// terminal required.
class RecordingSurface<S> implements Surface<S> {
  /// The draw calls received so far, in the order they arrived.
  final List<DrawIntent<S>> intents = <DrawIntent<S>>[];

  @override
  void drawText(int x, int y, String run, S style) => intents.add(TextIntent<S>(x, y, run, style));

  @override
  void fillRect(Rect rect, S style) => intents.add(FillIntent<S>(rect, style));

  @override
  void drawBorder(Rect rect, S style) => intents.add(BorderIntent<S>(rect, style));
}
