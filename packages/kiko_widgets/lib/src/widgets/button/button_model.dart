import 'dart:math';

import 'package:kiko/kiko.dart';

import 'types.dart';

/// Model for a single button.
///
/// Holds both state and config. Use [update] to handle messages.
/// Returns [ButtonPressEvent] when activated.
///
/// Has `copyWith` for creating modified copies. Mutable fields are
/// `focused` (required by [Focusable] interface), `loading`, and `disabled`.
class ButtonModel implements Component {
  /// Unique identifier for the button.
  @override
  final String id;

  /// Button text (must be single line).
  final Line label;

  /// Whether the button is disabled.
  bool disabled;

  /// Content shown during loading.
  final Line loadingText;

  /// Horizontal padding (symmetric).
  final int padding;

  /// Custom key bindings. Null uses defaults.
  final KeyBinding<ButtonAction>? keyBinding;

  bool _focused;

  /// Whether the button is in loading state.
  bool loading;

  /// Whether a pointer is currently pressing the button.
  ///
  /// Set on a `down`, cleared on the `up`, on a [PointerCancelMsg], or on a
  /// release that slid off. `button_view` folds it into [WidgetState.pressed].
  /// An `up` fires [ButtonPressEvent] only while this is set.
  bool pressed = false;

  /// Whether the pointer is over the button.
  ///
  /// Set from any pointer the button receives while not pressed, cleared on
  /// [PointerLeaveMsg]; `button_view` folds it into [WidgetState.hover].
  bool hovered = false;

  /// Default loading text.
  static final _defaultLoadingText = Line('⏳');

  /// Creates a ButtonModel.
  ButtonModel({
    required this.id,
    required this.label,
    this.disabled = false,
    this.loading = false,
    Line? loadingText,
    bool focused = false,
    this.padding = 1,
    this.keyBinding,
  }) : _focused = focused,
       loadingText = loadingText ?? _defaultLoadingText;

  /// Whether the button is focused.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// The effective key binding (custom or default).
  KeyBinding<ButtonAction> get effectiveKeyBinding => keyBinding ?? defaultButtonBindings;

  /// Width of the button in cells, as measured by [measurer].
  ///
  /// The button reserves room for the larger of [label] and [loadingText] —
  /// both are laid out every frame, and only the active one paints — so its
  /// width never changes when [loading] toggles.
  int width(TextMeasurer measurer) => max(label.width(measurer), loadingText.width(measurer)) + (padding * 2);

  /// Updates the model based on the message.
  ///
  /// The pointer branch sits above the focus gate, so a click presses and
  /// activates whether or not the button is focused (the app focuses it on the
  /// down). A `down` begins the press, setting [pressed]. An `up` fires
  /// [ButtonPressEvent] only when [pressed] is true and the release lands
  /// [PointerMsg.inside] — a press slid off, a release without its own press,
  /// and a cancelled gesture all do nothing — and either way the `up` clears
  /// [pressed]. A [PointerCancelMsg] ends the gesture without firing. Hover
  /// tracks any pointer over the button and clears on [PointerLeaveMsg].
  /// Capture returns the `up`/`cancel` to this button even after the cursor
  /// leaves; [pressed] is the button's own record that it saw the matching
  /// down. The keyboard path stays behind the gate.
  ///
  /// Returns [Handled] with a [ButtonPressEvent] on a release inside while
  /// pressed; [Handled] with no event for a press, a slid-off release, a
  /// release without its own press, a cancel and hover traffic; [Declined] for the wheel
  /// (nothing to scroll), for keys it does not handle, for messages it does
  /// not know, and when not focused.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      // Nothing to scroll — decline the wheel so a scrollable ancestor gets it.
      if (pointer.isWheel) return const Declined();
      // A disabled or loading button consumes the gesture but never presses,
      // activates, or hovers — the keyboard's silent ignore, for the mouse.
      if (disabled || loading) return const Handled();
      if (pointer.isDown) {
        pressed = true;
        return const Handled();
      }
      if (pointer.isUp) {
        // Fire only when this button saw the matching down and the release
        // lands inside. A release with no press behind it reaches the button
        // when the app intercepted the down, as a modal does when a press
        // outside it dismisses it.
        final fires = pressed && pointer.inside;
        pressed = false;
        return fires ? Handled.event(ButtonPressEvent(id)) : const Handled();
      }
      // A move or drag over the button only refreshes the hover.
      hovered = true;
      return const Handled();
    }
    if (msg is PointerLeaveMsg) {
      hovered = false;
      return const Handled();
    }
    if (msg is PointerCancelMsg) {
      // The gesture was torn off (off-window, unmounted, focus lost): end it
      // without committing — a captured press never becomes an activation.
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
    // Ignore activation when disabled or loading
    if (disabled || loading) {
      final action = effectiveKeyBinding.resolve(msg);
      if (action == ButtonAction.activate) {
        return const Handled(); // Silent ignore
      }
    }

    final action = effectiveKeyBinding.resolve(msg);
    if (action == ButtonAction.activate) {
      return Handled.event(ButtonPressEvent(id));
    }

    return const Declined();
  }

  /// Creates a copy with the given fields replaced.
  ButtonModel copyWith({
    String? id,
    Line? label,
    bool? disabled,
    bool? loading,
    Line? loadingText,
    bool? focused,
    int? padding,
    KeyBinding<ButtonAction>? keyBinding,
  }) {
    return ButtonModel(
      id: id ?? this.id,
      label: label ?? this.label,
      disabled: disabled ?? this.disabled,
      loading: loading ?? this.loading,
      loadingText: loadingText ?? this.loadingText,
      focused: focused ?? this.focused,
      padding: padding ?? this.padding,
      keyBinding: keyBinding ?? this.keyBinding,
    );
  }
}
