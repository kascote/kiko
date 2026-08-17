import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// Which side of its anchor an anchored popup renders on.
enum PopupSide {
  /// The popup renders below the anchor.
  below,

  /// The popup renders above the anchor.
  above,
}

/// A popup's placement decision, held for the life of one open session.
///
/// A widget with a floating popup stores one of these, nullable, on its
/// model: `null` while closed, set on the popup's first paint, and cleared
/// by the widget when the popup closes. The render helper that produces it
/// reuses a standing decision while [decidedAgainst] still matches the
/// current viewport, and decides again the moment it does not.
@immutable
class PopupPlacement {
  /// Which side of the anchor the popup renders on.
  final PopupSide side;

  /// The popup's height in rows.
  ///
  /// Equal to the height that was requested, except when neither side had
  /// room for it in full — then it is shrunk to the room the chosen side
  /// had.
  final int height;

  /// The viewport area this placement was decided against.
  final Rect decidedAgainst;

  /// Creates a placement decision.
  const PopupPlacement({required this.side, required this.height, required this.decidedAgainst});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PopupPlacement && other.side == side && other.height == height && other.decidedAgainst == decidedAgainst;

  @override
  int get hashCode => Object.hash(side, height, decidedAgainst);

  @override
  String toString() => 'PopupPlacement($side, height: $height, decidedAgainst: $decidedAgainst)';
}
