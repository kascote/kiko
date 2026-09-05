import 'dart:math';

import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// The value a checkbox holds.
enum CheckState {
  /// The box is empty.
  unchecked,

  /// The box shows the checked mark.
  checked,

  /// The box shows the mixed mark: some, but not all, of a group are checked.
  mixed,
}

/// The five glyph parts a checkbox's box is drawn from: a bracket pair, and
/// one mark per [CheckState].
///
/// Cells are measured under `TermUnicodeMeasurer`.
///
/// | preset   | unchecked | checked | mixed | cells | notes                        |
/// | -------- | --------- | ------- | ----- | ----- | ----------------------------- |
/// | `ascii`  | `[ ]`     | `[x]`   | `[-]` | 3     | the default                   |
/// | `check`  | `[ ]`     | `[✓]`   | `[−]` | 3     | near-universal font coverage  |
/// | `ballot` | `☐`       | `☑`     | `⊟`   | 1     | no brackets                   |
/// | `square` | `◻`       | `◼`     | `▬`   | 1     | no brackets                   |
/// | `block`  | `▐ ▌`     | `▐X▌`   | `▐-▌` | 3     | half blocks, filled mark cell |
/// | `emoji`  | `⬜`      | `✅`    | `➖`  | 2     | two cells on every tier       |
///
/// Each part is a plain string, so an app swaps it for a preset below, an
/// empty string (no brackets), or a wider glyph such as an emoji. The widget
/// measures every part rather than assuming it is one cell wide.
///
/// ```dart
/// CheckboxModel(label: Line('Accept the terms'), glyphs: CheckGlyphs.check)
/// ```
@immutable
class CheckGlyphs {
  /// The glyph painted before the mark.
  final String open;

  /// The glyph painted after the mark.
  final String close;

  /// The mark shown while [CheckState.checked].
  final String checked;

  /// The mark shown while [CheckState.unchecked].
  final String unchecked;

  /// The mark shown while [CheckState.mixed].
  final String mixed;

  /// Creates a CheckGlyphs.
  const CheckGlyphs({this.open = '[', this.close = ']', this.checked = 'x', this.unchecked = ' ', this.mixed = '-'});

  /// `[ ]` / `[x]` / `[-]`.
  static const ascii = CheckGlyphs();

  /// `[ ]` / `[✓]` / `[−]`.
  static const check = CheckGlyphs(checked: '✓', mixed: '−');

  /// `☐` / `☑` / `⊟`.
  static const ballot = CheckGlyphs(open: '', close: '', unchecked: '☐', checked: '☑', mixed: '⊟');

  /// `◻` / `◼` / `▬`.
  static const square = CheckGlyphs(open: '', close: '', unchecked: '◻', checked: '◼', mixed: '▬');

  /// `▐ ▌` / `▐X▌` / `▐-▌`.
  static const block = CheckGlyphs(open: '▐', close: '▌', checked: 'X');

  /// `⬜` / `✅` / `➖`.
  static const emoji = CheckGlyphs(open: '', close: '', unchecked: '⬜', checked: '✅', mixed: '➖');

  /// The width of the widest mark, as measured by [measurer].
  ///
  /// The box reserves this width for every mark, so toggling never shifts
  /// the label beside it.
  int markWidth(TextMeasurer measurer) =>
      [measurer.widthOf(unchecked), measurer.widthOf(checked), measurer.widthOf(mixed)].reduce(max);

  /// The width of the whole box — [open], the widest mark, and [close] — as
  /// measured by [measurer].
  int boxWidth(TextMeasurer measurer) => measurer.widthOf(open) + markWidth(measurer) + measurer.widthOf(close);
}

// ═══════════════════════════════════════════════════════════
// STYLES
// ═══════════════════════════════════════════════════════════

/// Checkbox's anatomy: one nullable style slot per part.
///
/// A `null` slot is derived from the theme's tones by the rule below; a
/// non-null slot is the caller's exact style and wins verbatim, bypassing both
/// the derivation and the per-state `styleOverrides` map on `Checkbox`.
///
/// | slot          | derived default             | matrix source   |
/// | ------------- | ---------------------------- | --------------- |
/// | `open`        | `resolver.ink(border)`       | resting chrome  |
/// | `close`       | `resolver.ink(border)`       | resting chrome  |
/// | `mark`        | none (inherits the ground)   | —               |
/// | `checkedMark` | `resolver.ink(selection)`    | selected × ink  |
/// | `label`       | none (inherits the ground)   | —               |
@immutable
class CheckboxStyle {
  /// The opening bracket glyph.
  final Style? open;

  /// The closing bracket glyph.
  final Style? close;

  /// The mark while [CheckState.unchecked].
  final Style? mark;

  /// The mark while [CheckState.checked] or [CheckState.mixed].
  final Style? checkedMark;

  /// The label text.
  final Style? label;

  /// Creates a CheckboxStyle.
  const CheckboxStyle({this.open, this.close, this.mark, this.checkedMark, this.label});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckboxStyle &&
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

/// Actions for checkbox key bindings.
enum CheckboxAction {
  /// Flip the checked value.
  toggle,
}

/// Default key bindings for checkbox toggling: Space only.
///
/// Enter stays unbound, so a checkbox never eats the key a form wants for
/// submit.
final defaultCheckboxBindings = KeyBinding<CheckboxAction>()..map(['space'], CheckboxAction.toggle);

// ═══════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════

/// Emitted when a checkbox's value changes.
@immutable
class CheckboxChangeEvent extends WidgetEvent {
  /// The id of the checkbox that changed.
  @override
  final String id;

  /// The value after the change.
  final bool checked;

  /// Creates a CheckboxChangeEvent.
  const CheckboxChangeEvent(this.id, {required this.checked});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CheckboxChangeEvent && other.id == id && other.checked == checked;

  @override
  int get hashCode => Object.hash(id, checked);

  @override
  String toString() => 'CheckboxChangeEvent($id, checked: $checked)';
}
