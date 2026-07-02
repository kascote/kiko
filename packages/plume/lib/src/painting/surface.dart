import '../geometry/rect.dart';

/// A sink the paint pass draws into.
///
/// The engine walks the laid-out tree and calls these methods in paint order;
/// each call is a *draw intent*. Backends implement it to render for real (for
/// example into a terminal buffer), and tests implement it to record the calls.
///
/// [T] is the opaque paint token carried from the widgets. The surface is the
/// one place it is interpreted — the layout core never looks inside it.
///
/// The surface also owns the paint-side clip. The paint walk pushes a node's
/// rect before painting it and pops it after, so [clipRect] is always the
/// intersection of the node's rect with every ancestor's. Draw calls landing
/// outside that region are trimmed or dropped, so a node paints only within the
/// box layout assigned it. Concrete surfaces extend `ClippingSurface`, which
/// owns the clip stack and the trim/drop rules, so a leaf drawing through the
/// three draw methods cannot escape the clip.
abstract class Surface<T> {
  /// Draws the run of graphemes [run] starting at cell ([x], [y]), styled by
  /// [token].
  void drawText(int x, int y, String run, T token);

  /// Fills every cell of [rect], styled by [token].
  void fillRect(Rect rect, T token);

  /// Draws a border around the edge of [rect], styled by [token].
  void drawBorder(Rect rect, T token);

  /// Pushes [rect] as the active clip, intersected with the current clip.
  ///
  /// Every draw call between this and the matching [popClip] is confined to the
  /// pushed region.
  void pushClip(Rect rect);

  /// Removes the clip added by the matching [pushClip].
  void popClip();

  /// The active clip — the intersection of every pushed rect — or `null` when
  /// nothing is pushed (an unclipped surface).
  Rect? get clipRect;
}
