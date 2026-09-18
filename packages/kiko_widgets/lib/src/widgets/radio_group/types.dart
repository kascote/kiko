import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// One choice inside a radio group: a value, a label, and whether it can be
/// chosen.
///
/// A radio group matches values with `==`, so a fresh instance built from a
/// reload still matches an already-chosen value.
@immutable
class RadioOption<T> {
  /// The value this option represents.
  final T value;

  /// The text beside the option's mark.
  final Line label;

  /// Whether this option can be chosen.
  ///
  /// The cursor and the pointer skip a disabled option, but it still paints
  /// in its place among the others.
  final bool disabled;

  /// Creates a RadioOption.
  const RadioOption({required this.value, required this.label, this.disabled = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioOption<T> && other.value == value && other.label == label && other.disabled == disabled;

  @override
  int get hashCode => Object.hash(value, label, disabled);
}

// ═══════════════════════════════════════════════════════════
// STYLES
// ═══════════════════════════════════════════════════════════

/// Radio group's anatomy: one nullable style slot per part, shared by every
/// option row.
///
/// A `null` slot is derived from the theme's tones by the rule below; a
/// non-null slot is the caller's exact style and wins verbatim.
///
/// | slot          | derived default             | matrix source   |
/// | ------------- | ---------------------------- | --------------- |
/// | `open`        | `resolver.ink(border)`       | resting chrome  |
/// | `close`       | `resolver.ink(border)`       | resting chrome  |
/// | `mark`        | none (inherits the ground)   | —               |
/// | `checkedMark` | `resolver.ink(selection)`    | selected × ink  |
/// | `label`       | none (inherits the ground)   | —               |
@immutable
class RadioStyle {
  /// The opening bracket glyph.
  final Style? open;

  /// The closing bracket glyph.
  final Style? close;

  /// The mark on an unchosen option.
  final Style? mark;

  /// The mark on the chosen option.
  final Style? checkedMark;

  /// The label text.
  final Style? label;

  /// Creates a RadioStyle.
  const RadioStyle({this.open, this.close, this.mark, this.checkedMark, this.label});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RadioStyle &&
        other.open == open &&
        other.close == close &&
        other.mark == mark &&
        other.checkedMark == checkedMark &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(open, close, mark, checkedMark, label);
}

// ═══════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════

/// Actions for radio group key bindings.
enum RadioAction {
  /// Move the cursor to the nearest enabled option before it, wrapping, and
  /// choose it.
  previous,

  /// Move the cursor to the nearest enabled option after it, wrapping, and
  /// choose it.
  next,

  /// Choose the option at the cursor.
  select,
}

/// Default key bindings for a radio group: the arrows and `j`/`k` move the
/// cursor and choose in one step, space chooses the cursor option.
///
/// Enter stays unbound, so a radio group never eats the key a form wants for
/// submit.
final defaultRadioBindings = KeyBinding<RadioAction>()
  ..map(['up', 'left', 'k'], RadioAction.previous)
  ..map(['down', 'right', 'j'], RadioAction.next)
  ..map(['space'], RadioAction.select);

// ═══════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════

/// Emitted when the user chooses a different option in a radio group.
@immutable
class RadioChangeEvent<T> extends WidgetEvent {
  /// The id of the radio group that changed.
  @override
  final String id;

  /// The value of the option the user chose.
  final T value;

  /// Creates a RadioChangeEvent.
  const RadioChangeEvent(this.id, this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RadioChangeEvent<T> && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => 'RadioChangeEvent($id, $value)';
}
