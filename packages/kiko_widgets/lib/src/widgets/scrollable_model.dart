import 'package:kiko/kiko.dart';

/// Shared scroll arithmetic for the container widgets — ListView, TableView and
/// TreeView.
///
/// It gives each model a uniform scroll surface: where the viewport starts, how
/// many rows it shows, how to move it by a wheel notch, and how to turn a local
/// pointer position into the row under it. The mouse code drives every scrollable
/// widget through this one surface, whatever the widget is.
///
/// Opt-in and kiko_widgets-only: a model mixes it in with `with ScrollableModel`.
/// It is deliberately not a framework interface — a flat list, a windowed table
/// and an indented tree keep their scroll state in different fields and measure
/// their rows differently, so each member is implemented per model over its own
/// state. Only [wheelScrollLines] carries a shared default.
mixin ScrollableModel {
  /// The first visible row, in the model's own row space.
  int get scrollOffset;

  /// How many rows the viewport shows.
  ///
  /// The view pushes this in while it paints, so it reflects the last committed
  /// frame and lags a frame behind a resize — close enough to clamp a scroll.
  int get visibleCount;

  /// How many rows one wheel notch moves the viewport. The conventional three; a
  /// tree of tall nodes may raise it.
  int get wheelScrollLines => 3;

  /// Moves the viewport by [rows] — positive scrolls down — and stops it at the
  /// content edges.
  ///
  /// The offset is clamped to `[0, length - visibleCount]` over the model's own
  /// notion of length: a list's item count, a table's loaded window, a tree's
  /// flattened range. The keyboard cursor is left where it is; a wheel scroll and
  /// the cursor move independently, and the next keypress snaps the viewport back
  /// to the cursor.
  void scrollBy(int rows);

  /// The row the pointer at [local] falls on, or null when it lands on no row.
  ///
  /// The position is in the widget's own cells. Each widget maps it with its own
  /// geometry — a table skips its sticky header, a tree its flattened range — and
  /// returns null for a click above the first row or below the last.
  int? localToRow(Position local);
}
