import 'package:meta/meta.dart';

import '../layout/rect.dart';
import '../widgets/hit_map.dart';

/// What the runtime knows and an update function cannot work out for itself.
///
/// It arrives as the third argument of every update call. Read [hits] to
/// resolve a mouse event to the widget under the pointer, and [area] to make a
/// decision that depends on how much room the application has. Nothing here is
/// writable: a new model and a command remain the only way out of an update.
///
/// It is to `update` what `Frame` is to `view`, minus the paint surface —
/// update never receives the frame, so there is no buffer to draw into and
/// nothing to stash for later.
///
/// A field belongs here only if the runtime supplies it, the model and the
/// message cannot yield it, and update logic really needs it. A logger fails
/// the first test, a widget's own state fails the second, and everything else
/// belongs in the model.
@immutable
class UpdateContext {
  /// The tagged geometry this turn's message was resolved against.
  ///
  /// For a pointer message that is the frame the pointer was over; for every
  /// other message it is the last frame committed to the screen. Before the
  /// first frame is drawn it is an empty map, never `null`.
  final HitMap hits;

  /// The viewport: the part of the terminal this application draws into.
  ///
  /// The whole terminal for a full screen application, a slice of it for an
  /// inline or fixed one. It is the same rect `view` reads as `Frame.area`.
  final Rect area;

  /// Bundles the runtime state one update turn may read.
  const UpdateContext({required this.hits, required this.area});
}
