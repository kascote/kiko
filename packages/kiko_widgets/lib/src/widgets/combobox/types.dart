import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import '../list_view/types.dart';
import '../text_input/types.dart';

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
/// | `toggle`         | inherit, focused × ink            | focused × ink     |
/// | `popupGround`    | `resolver.ground(surface)`       | anatomy-specific  |
/// | `popupBorder`    | `resolver.border({})`            | resting chrome    |
/// | `placeholder`    | `resolver.ink(muted)`            | anatomy-specific  |
/// | `field`          | the field's own derived look     | —                 |
/// | `list`           | the popup list's own derived look | —                 |
///
/// The field styles through [field], and the popup's match rows style
/// through [list]. `placeholder` styles the popup's own status row instead —
/// the one line the view paints itself, after the standing matches, while a
/// remote query is in flight, has failed, or was refused. A failed row
/// patches `error` × `ink` over that base.
class ComboboxStyle {
  /// The toggle glyph's style.
  final Style? toggle;

  /// The popup's ground, painted behind every row and under the blank tail
  /// past the last match.
  final Style? popupGround;

  /// The popup border's ink.
  final Style? popupBorder;

  /// The popup's status row: in flight, failed, or refused.
  final Style? placeholder;

  /// The embedded field's anatomy.
  final TextInputStyle field;

  /// The popup list's anatomy.
  final ListViewStyle list;

  /// Creates a ComboboxStyle.
  const ComboboxStyle({
    this.toggle,
    this.popupGround,
    this.popupBorder,
    this.placeholder,
    this.field = const TextInputStyle(),
    this.list = const ListViewStyle(),
  });
}

// ═══════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════

/// Emitted when a combobox commits its highlighted option as the value.
///
/// Addressed by the combobox's own [id] — never the id of the list it embeds
/// internally. The event carries no value; the app reads the selection back
/// from `ComboboxModel.value`.
@immutable
class ComboboxSelectEvent extends WidgetEvent {
  /// Id of the combobox model where the selection was committed.
  @override
  final String id;

  /// Creates a ComboboxSelectEvent.
  const ComboboxSelectEvent(this.id);

  @override
  bool operator ==(Object other) => identical(this, other) || other is ComboboxSelectEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ComboboxSelectEvent($id)';
}
