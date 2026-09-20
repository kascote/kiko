import 'package:kiko/kiko.dart';

/// Shared scroll arithmetic for the container widgets — ListView, TableView and
/// TreeView.
///
/// It gives each model a uniform scroll surface: where the viewport starts, how
/// many rows it shows, and how to move it by a wheel notch. It also carries
/// [handleRowPointer], the row handler those widgets' data rows share — the
/// row a pointer lands on is resolved by the framework as a hit region and
/// carried on the message, so no model turns a coordinate into a row itself.
///
/// Opt-in and kiko_widgets-only: a model mixes it in with `with ScrollableModel`.
/// It is deliberately not a framework interface — a flat list, a windowed table
/// and an indented tree keep their scroll state in different fields, so each
/// member is implemented per model over its own state. Only [wheelScrollLines]
/// and [handleRowPointer] carry shared behavior.
///
/// [handleRowPointer] activates a row according to [pointerActivation]: on
/// every press by default, or only on the second press of a chain when an
/// app sets the field to [PointerActivation.doubleClick].
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

  /// How a press on a row activates it, read by [handleRowPointer].
  ///
  /// Defaults to [PointerActivation.press]: a row opens on the same press
  /// that selects it. Set it to [PointerActivation.doubleClick] so a click
  /// only selects and the second press of a chain opens it. Either way the
  /// keyboard is unaffected — Enter activates on its own — so a
  /// `doubleClick` list reads as "click selects, Enter or double-click
  /// opens".
  PointerActivation pointerActivation = PointerActivation.press;

  /// Moves the viewport by [rows] — positive scrolls down — and stops it at the
  /// content edges. Returns how many rows the offset actually moved, which is
  /// `0` when the viewport was already at the edge [rows] pushed toward.
  ///
  /// The offset is clamped to `[0, length - visibleCount]` over the model's own
  /// notion of length: a list's item count, a table's loaded window, a tree's
  /// flattened range. The keyboard cursor is left where it is; a wheel scroll and
  /// the cursor move independently, and the next keypress snaps the viewport back
  /// to the cursor.
  ///
  /// The return value is what lets a wheel handler decline a notch that moved
  /// nothing in that direction (per-direction: wheel-up declines at the top,
  /// wheel-down at the bottom), so a nesting scroll ancestor gets the chance —
  /// consuming at the limit would make nesting permanently dead.
  int scrollBy(int rows);

  /// The row handler every scrollable's data rows share: hover follows the
  /// pointer, and a press moves the cursor to the row, scrolls it into view, and
  /// activates it — the mouse counterpart of the keyboard's move-then-confirm.
  ///
  /// A widget calls this from its own update switch for a row-scoped region,
  /// passing the seams the mixin cannot reach into: [setHover] writes the
  /// model's hover field, [moveCursorTo] sets the cursor and adjusts the scroll,
  /// and [activate] builds the widget's own action event (`ListActivateEvent`,
  /// `TableActivateEvent`, a tree's confirm event, each carrying the model id).
  /// [activate] is a callback, not a value, so it is built only on a press and
  /// never on a hot hover move, and it may return `null` when the widget's
  /// activation produces no event.
  ///
  /// A press ([PointerMsg.isDown]) moves the cursor and, under
  /// [PointerActivation.press], returns [Handled] carrying the activate
  /// event, exactly as Enter does. Under [PointerActivation.doubleClick],
  /// only the second press of a chain carries the event; any other press
  /// still moves the cursor and returns a bare [Handled]. Any other pointer
  /// — a move, a drag, the release half of a click — only refreshes the
  /// hover and returns a bare [Handled]. The verdict and any deviation stay
  /// with the widget: the mixin never invokes this itself, and a part that
  /// should not highlight its row (a per-row button, a tree's indicator that
  /// toggles instead) is simply not routed here.
  UpdateResult handleRowPointer(
    PointerMsg pointer,
    int row, {
    required void Function(int row) setHover,
    required void Function(int row) moveCursorTo,
    required WidgetEvent? Function() activate,
  }) {
    setHover(row);
    if (pointer.isDown) {
      moveCursorTo(row);
      final activates = switch (pointerActivation) {
        PointerActivation.press => true,
        PointerActivation.doubleClick => pointer.clickCount == 2,
      };
      if (!activates) return const Handled();
      final event = activate();
      return event == null ? const Handled() : Handled.event(event);
    }
    return const Handled();
  }
}

/// How a press activates a row scrollable's row.
///
/// Read from [ScrollableModel.pointerActivation] by
/// [ScrollableModel.handleRowPointer].
enum PointerActivation {
  /// Every press activates its row, the same press that moves the cursor.
  press,

  /// Only the second press of a chain activates its row; a lone press only
  /// moves the cursor.
  doubleClick,
}
