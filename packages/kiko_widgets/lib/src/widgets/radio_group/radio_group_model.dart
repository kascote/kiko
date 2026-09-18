import 'dart:math';

import 'package:kiko/kiko.dart';

import '../checkbox/types.dart';
import '../row_region.dart';
import 'types.dart';

/// Model for a radio group: one exclusive choice among labeled options.
///
/// Holds every option and the chosen value. Use [update] to handle messages;
/// it returns [RadioChangeEvent] when the user's key or click chooses a
/// different option.
///
/// Every field but [options] and [value] is a plain mutable field: the app
/// disables the group with `model.disabled = true`, flags it with
/// `model.error = true`. There is no `copyWith` — the model is mutable, and
/// a copy would orphan the instance the router and the focus group hold.
class RadioGroupModel<T> implements Component {
  /// Stable identity for this radio group.
  ///
  /// A plume view stamps it on the group's subtree so a click resolves back
  /// through [HitMap.hitId]; pass an explicit id when addressing must
  /// survive a restart.
  @override
  final String id;

  List<RadioOption<T>> _options;

  T? _value;

  int _cursor;

  /// Whether the whole group is disabled.
  ///
  /// A disabled group keeps its chosen value and still paints every option,
  /// dimmed, and ignores the keyboard and the pointer.
  bool disabled;

  /// Whether validation failed for this group.
  bool error;

  /// The glyph parts each option's box is drawn from.
  CheckGlyphs glyphs;

  /// Whether the options stack in one column or sit on one row.
  Axis direction;

  /// Whether the label paints before the box, on every option.
  bool labelFirst;

  /// Where the label sits inside the width its row is given.
  ///
  /// Only [Axis.vertical] gives an option row spare width to place a label
  /// in, so this has no visible effect while [direction] is
  /// [Axis.horizontal].
  TextAlign labelAlign;

  /// Custom key bindings. Null uses [defaultRadioBindings].
  KeyBinding<RadioAction>? keyBinding;

  bool _focused;

  /// The index of the option a pointer is pressing, or `null` when none is.
  ///
  /// Set on a `down` over an enabled option, cleared on the `up`, on a
  /// [PointerCancelMsg], or on a release that landed on another row.
  int? pressedIndex;

  /// The index of the option under the pointer, or `null` when none is.
  ///
  /// Set from any pointer the group receives while nothing is pressed,
  /// cleared on [PointerLeaveMsg].
  int? hoveredIndex;

  /// Creates a RadioGroupModel.
  RadioGroupModel({
    required List<RadioOption<T>> options,
    String? id,
    T? value,
    this.disabled = false,
    this.error = false,
    this.glyphs = CheckGlyphs.paren,
    this.direction = Axis.vertical,
    this.labelFirst = false,
    this.labelAlign = TextAlign.start,
    this.keyBinding,
    bool focused = false,
  }) : id = id ?? autoId('radio'),
       _options = options,
       _value = value,
       _cursor = 0,
       _focused = focused {
    final matched = value == null ? -1 : _options.indexWhere((option) => option.value == value);
    _cursor = matched >= 0 ? matched : (_seek(-1, 1) ?? 0);
  }

  /// Whether the radio group is focused.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// The chosen value, or `null` while nothing is chosen.
  ///
  /// The setter is silent: it never emits [RadioChangeEvent]. It moves
  /// [cursor] to the option that matches [value], by `==`; a value that
  /// matches no option leaves [cursor] where it is.
  T? get value => _value;

  set value(T? newValue) {
    _value = newValue;
    final matched = newValue == null ? -1 : _options.indexWhere((option) => option.value == newValue);
    if (matched >= 0) _cursor = matched;
  }

  /// The options the group offers.
  ///
  /// Replace the list to change it: an in-place edit is not seen until the
  /// next replacement. The setter is silent. It keeps [value] when an
  /// option in the new list still matches it and moves [cursor] there;
  /// otherwise it clamps [cursor] into the new list and seeks the nearest
  /// enabled option from there, wrapping. An all-disabled list keeps the
  /// clamped index. The model never edits the list it is given.
  List<RadioOption<T>> get options => _options;

  set options(List<RadioOption<T>> newOptions) {
    _options = newOptions;
    final currentValue = _value;
    final matched = currentValue == null ? -1 : newOptions.indexWhere((option) => option.value == currentValue);
    if (matched >= 0) {
      _cursor = matched;
      return;
    }
    if (newOptions.isEmpty) {
      _cursor = 0;
      return;
    }
    final clamped = _cursor.clamp(0, newOptions.length - 1);
    _cursor = _seek(clamped - 1, 1) ?? clamped;
  }

  /// The keyboard-current option's index.
  ///
  /// The constructor puts it on the option matching [value], else the first
  /// enabled option, else `0`. The user's arrows and the app's [value]
  /// writes move it; the app never writes it directly. The getter clamps
  /// the stored index into the live [options] length, so a list shortened
  /// in place, bypassing the setter, never indexes past its end.
  int get cursor => _options.isEmpty ? 0 : _cursor.clamp(0, _options.length - 1);

  /// The effective key binding: [keyBinding] if set, else
  /// [defaultRadioBindings].
  KeyBinding<RadioAction> get effectiveKeyBinding => keyBinding ?? defaultRadioBindings;

  /// Width of the group in cells, as measured by [measurer].
  ///
  /// Each option row is its box plus one gap cell plus its label. Vertical,
  /// the group is as wide as its widest row; horizontal, it is every row's
  /// width plus two cells between each pair. Zero when [options] is empty.
  int width(TextMeasurer measurer) {
    if (_options.isEmpty) return 0;
    final rowWidths = _options.map((option) => glyphs.boxWidth(measurer) + 1 + option.label.width(measurer));
    if (direction == Axis.vertical) return rowWidths.reduce(max);
    return rowWidths.reduce((a, b) => a + b) + (_options.length - 1) * 2;
  }

  /// Walks [_options], starting [step] cells from [from] and wrapping, and
  /// returns the first enabled option's index found within one full lap, or
  /// `null` when every option is disabled or there are none.
  int? _seek(int from, int step) {
    final length = _options.length;
    if (length == 0) return null;
    for (var i = 1; i <= length; i++) {
      final index = (from + step * i) % length;
      if (!_options[index].disabled) return index;
    }
    return null;
  }

  /// Sets [value] to the option at [index] and moves [cursor] there,
  /// emitting [RadioChangeEvent] only when the value actually changed.
  UpdateResult _choose(int index) {
    final chosen = _options[index].value;
    final changed = chosen != _value;
    _value = chosen;
    _cursor = index;
    if (!changed) return const Handled();
    return Handled.event(RadioChangeEvent(id, chosen));
  }

  /// Updates the model based on the message.
  ///
  /// The pointer branch sits above the focus gate, so a click chooses an
  /// option whether or not the group is focused (the app focuses it on the
  /// down). A wheel declines, so a scrollable ancestor gets it. A disabled
  /// group consumes the gesture but never chooses or hovers. A `down` over
  /// an enabled option begins the press, setting [pressedIndex]; a `down`
  /// anywhere else is consumed and starts nothing. An `up` chooses the
  /// pressed option and fires [RadioChangeEvent] only when [pressedIndex] is
  /// set, the release lands [PointerMsg.inside], and it lands on the same
  /// row — a press slid onto another row, a release without its own press,
  /// and a cancelled gesture all choose nothing — and either way the `up`
  /// clears [pressedIndex]. A [PointerCancelMsg] ends the gesture without
  /// choosing. Hover tracks any other pointer over an enabled option and
  /// clears on [PointerLeaveMsg] or over no option or a disabled one.
  ///
  /// The keyboard path stays behind the gate: [RadioAction.previous] and
  /// [RadioAction.next] seek the nearest enabled option from [cursor],
  /// wrapping, move it and choose it, doing nothing when every option is
  /// disabled; [RadioAction.select] chooses [cursor], silently ignored when
  /// that option is disabled. A disabled group consumes every action
  /// silently.
  ///
  /// Returns [Declined] for the wheel, for keys it does not bind, for
  /// messages it does not know, and when not focused.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      return _handlePointer(pointer);
    }
    if (msg is PointerLeaveMsg) {
      hoveredIndex = null;
      return const Handled();
    }
    if (msg is PointerCancelMsg) {
      pressedIndex = null;
      return const Handled();
    }

    if (!focused) return const Declined();

    if (msg case final KeyMsg key) {
      return _handleKey(key);
    }
    return const Declined();
  }

  UpdateResult _handlePointer(PointerMsg pointer) {
    if (pointer.isWheel) return const Declined();
    if (disabled) return const Handled();
    if (pointer.isDown) {
      if (pointer.region case RowRegion(:final index) when !_options[index].disabled) {
        pressedIndex = index;
      }
      return const Handled();
    }
    if (pointer.isUp) {
      final pressed = pressedIndex;
      pressedIndex = null;
      final landedOnPressedRow = switch (pointer.region) {
        RowRegion(:final index) => index == pressed,
        _ => false,
      };
      if (pressed == null || !pointer.inside || !landedOnPressedRow) return const Handled();
      return _choose(pressed);
    }
    hoveredIndex = switch (pointer.region) {
      RowRegion(:final index) when !_options[index].disabled => index,
      _ => null,
    };
    return const Handled();
  }

  UpdateResult _handleKey(KeyMsg msg) {
    final action = effectiveKeyBinding.resolve(msg);
    if (action == null) return const Declined();
    if (disabled) return const Handled(); // Silent ignore.
    switch (action) {
      case RadioAction.previous:
        final index = _seek(cursor, -1);
        return index == null ? const Handled() : _choose(index);
      case RadioAction.next:
        final index = _seek(cursor, 1);
        return index == null ? const Handled() : _choose(index);
      case RadioAction.select:
        final index = cursor;
        if (_options.isEmpty || _options[index].disabled) return const Handled();
        return _choose(index);
    }
  }
}
