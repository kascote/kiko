import 'package:kiko/kiko.dart';

import 'types.dart';

/// Model for a single checkbox: a labeled on/off toggle.
///
/// Holds both state and config. Use [update] to handle messages; it returns
/// [CheckboxChangeEvent] when the user's key or click flips the value.
///
/// Every field is a plain mutable field: the app checks a box with
/// `model.checked = true`, disables it with `model.disabled = true`. There is
/// no `copyWith` — the model is mutable, and a copy would orphan the instance
/// the router and the focus group hold.
class CheckboxModel implements Component {
  /// Stable identity for this checkbox.
  ///
  /// A plume view stamps it on the row so a click resolves back through
  /// [HitMap.hitId]; pass an explicit id when addressing must survive a restart.
  @override
  final String id;

  /// The text beside the box.
  Line label;

  /// The value: unchecked, checked, or mixed.
  CheckState state;

  /// Whether the checkbox is disabled.
  ///
  /// A disabled box keeps its value: it still paints its mark, dimmed with
  /// the rest of the row, and ignores the keyboard and the pointer.
  bool disabled;

  /// Whether validation failed for this checkbox.
  bool error;

  /// The glyph parts the box is drawn from.
  CheckGlyphs glyphs;

  /// Whether the label paints before the box.
  bool labelFirst;

  /// Where the label sits inside the width its region is given.
  TextAlign labelAlign;

  /// Custom key bindings. Null uses [defaultCheckboxBindings].
  KeyBinding<CheckboxAction>? keyBinding;

  bool _focused;

  /// Whether a pointer is currently pressing the checkbox.
  ///
  /// Set on a `down`, cleared on the `up`, on a [PointerCancelMsg], or on a
  /// release that slid off.
  bool pressed = false;

  /// Whether the pointer is over the checkbox.
  ///
  /// Set from any pointer the checkbox receives while not pressed, cleared on
  /// [PointerLeaveMsg].
  bool hovered = false;

  /// Creates a CheckboxModel.
  CheckboxModel({
    required this.label,
    String? id,
    this.state = CheckState.unchecked,
    this.disabled = false,
    this.error = false,
    this.glyphs = CheckGlyphs.ascii,
    this.labelFirst = false,
    this.labelAlign = TextAlign.start,
    this.keyBinding,
    bool focused = false,
  }) : id = id ?? autoId('checkbox'),
       _focused = focused;

  /// Whether the checkbox is focused.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// The value as a bool, a getter and setter over [state].
  ///
  /// The setter writes [CheckState.checked] or [CheckState.unchecked],
  /// clearing a prior [CheckState.mixed].
  bool get checked => state == CheckState.checked;

  set checked(bool value) => state = value ? CheckState.checked : CheckState.unchecked;

  /// Whether the value is [CheckState.mixed].
  bool get mixed => state == CheckState.mixed;

  /// The effective key binding (custom or default).
  KeyBinding<CheckboxAction> get effectiveKeyBinding => keyBinding ?? defaultCheckboxBindings;

  /// Flips [state]: unchecked or mixed becomes checked, checked becomes
  /// unchecked.
  ///
  /// Public and silent — it never emits [CheckboxChangeEvent] itself; only
  /// [update] wraps the result in one, for the user's own toggle.
  void toggle() {
    state = state == CheckState.checked ? CheckState.unchecked : CheckState.checked;
  }

  /// Width of the checkbox in cells, as measured by [measurer]: the box, one
  /// gap cell, and the label.
  int width(TextMeasurer measurer) => glyphs.boxWidth(measurer) + 1 + label.width(measurer);

  /// Updates the model based on the message.
  ///
  /// The pointer branch sits above the focus gate, so a click toggles whether
  /// or not the checkbox is focused (the app focuses it on the down). A wheel
  /// declines, so a scrollable ancestor gets it. A disabled checkbox consumes
  /// the gesture but never toggles or hovers. A `down` begins the press; an
  /// `up` toggles and fires [CheckboxChangeEvent] only when it lands
  /// [PointerMsg.inside] — a press slid off and released does nothing — and a
  /// [PointerCancelMsg] ends the gesture without toggling. Hover tracks any
  /// other pointer and clears on [PointerLeaveMsg]. The keyboard path stays
  /// behind the gate: [CheckboxAction.toggle] toggles and fires the same
  /// event, silently ignored while disabled.
  ///
  /// Returns [Declined] for the wheel, for keys it does not bind, for
  /// messages it does not know, and when not focused.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      if (pointer.isWheel) return const Declined();
      if (disabled) return const Handled();
      if (pointer.isDown) {
        pressed = true;
        return const Handled();
      }
      if (pointer.isUp) {
        pressed = false;
        if (!pointer.inside) return const Handled();
        toggle();
        return Handled.event(CheckboxChangeEvent(id, checked: checked));
      }
      hovered = true;
      return const Handled();
    }
    if (msg is PointerLeaveMsg) {
      hovered = false;
      return const Handled();
    }
    if (msg is PointerCancelMsg) {
      pressed = false;
      return const Handled();
    }

    if (!focused) return const Declined();

    if (msg case KeyMsg()) {
      return _handleKey(msg);
    }
    return const Declined();
  }

  UpdateResult _handleKey(KeyMsg msg) {
    final action = effectiveKeyBinding.resolve(msg);
    if (action != CheckboxAction.toggle) return const Declined();
    if (disabled) return const Handled(); // Silent ignore.
    toggle();
    return Handled.event(CheckboxChangeEvent(id, checked: checked));
  }
}
