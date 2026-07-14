import 'package:kiko/kiko.dart';

/// A focusable placeholder that declines every message.
///
/// Use it to give a pane a slot in a [FocusGroup] when the pane has no
/// interactive widget of its own — an empty panel, a status area, a
/// deliberate focus sink at the end of a cycle. It holds a position in the
/// focus order and nothing else: it renders nothing and never consumes
/// input.
class FocusSlot implements Component {
  /// Creates a focus slot.
  ///
  /// [id] defaults to an auto-generated id; pass an explicit one to match
  /// against a literal or to disambiguate multiple instances.
  FocusSlot({String? id}) : id = id ?? autoId('focusslot');

  @override
  final String id;

  /// Whether this slot currently has focus.
  @override
  bool focused = false;

  @override
  UpdateResult update(Msg msg) => const Declined();
}
