import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// Emitted when a combobox commits its highlighted option as the value.
///
/// Addressed by the combobox's own [id] — never the id of the list it embeds
/// internally. The command carries no value; the app reads the selection back
/// from `ComboboxModel.value`.
@immutable
class ComboboxSelectCmd extends Cmd {
  /// Id of the combobox model where the selection was committed.
  final String id;

  /// Creates a ComboboxSelectCmd.
  const ComboboxSelectCmd(this.id);

  @override
  bool operator ==(Object other) => identical(this, other) || other is ComboboxSelectCmd && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ComboboxSelectCmd($id)';
}
