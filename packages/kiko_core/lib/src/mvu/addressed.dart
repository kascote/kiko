import 'pointer_msg.dart';

/// A message that names the widget it is for.
///
/// A router delivers it to the component registered under [id], or under the
/// longest registered prefix of [id] when the id names a composite's part,
/// and declines it when nothing answers. An async result that comes back to
/// the widget that asked for it carries one.
///
/// This is not [Routed]. A [Routed.targetId] is nullable and is resolved by
/// the hit map, so a null there means the background. An [Addressed] id is
/// never null: whoever built the message chose the widget.
abstract interface class Addressed {
  /// The id of the widget this message is for.
  String get id;
}
