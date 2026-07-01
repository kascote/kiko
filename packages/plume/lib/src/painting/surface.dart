import '../geometry/rect.dart';

/// A sink the paint pass draws into.
///
/// The engine walks the laid-out tree and calls these methods in paint order;
/// each call is a *draw intent*. Backends implement it to render for real (for
/// example into a terminal buffer), and tests implement it to record the calls.
///
/// [S] is the opaque style token carried from the widgets. The surface is the
/// one place it is interpreted — the layout core never looks inside it.
abstract class Surface<S> {
  /// Draws the run of graphemes [run] starting at cell ([x], [y]), styled by
  /// [style].
  void drawText(int x, int y, String run, S style);

  /// Fills every cell of [rect], styled by [style].
  void fillRect(Rect rect, S style);

  /// Draws a border around the edge of [rect], styled by [style].
  void drawBorder(Rect rect, S style);
}
