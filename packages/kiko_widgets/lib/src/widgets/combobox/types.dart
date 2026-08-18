import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

// ═══════════════════════════════════════════════════════════
// STYLES
// ═══════════════════════════════════════════════════════════

/// Combobox's anatomy: one nullable style slot per part.
///
/// A `null` slot is derived from the theme's tones by the rule below; a
/// non-null slot is the caller's exact style and wins verbatim.
///
/// | slot             | derived default                 | matrix source    |
/// | ---------------- | -------------------------------- | ---------------- |
/// | `toggle`         | `focused` × `ink`, else base ink | focused × ink     |
/// | `popupBackground`| `theme.surface.fill`             | anatomy-specific  |
///
/// The field's own look stays `TextInputModel`'s business — a combobox styles
/// only the parts it owns on top of the embedded field. The popup's rows are
/// styled by the embedded list's own anatomy, not by this class.
class ComboboxStyle {
  /// The toggle glyph's style.
  final Style? toggle;

  /// The popup's background fill, painted behind every row and under the
  /// blank tail past the last match.
  final Style? popupBackground;

  /// Creates a ComboboxStyle.
  const ComboboxStyle({this.toggle, this.popupBackground});
}

// ═══════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════

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
