import 'package:kiko/kiko.dart';

import 'button_model.dart';
import 'types.dart';

/// Model for a group of buttons with focus navigation.
///
/// Manages focus navigation across buttons and delegates key events
/// to the focused button. Does NOT handle layout - user renders buttons
/// using kiko layout widgets (Row, Column, etc.).
class ButtonGroupModel implements Focusable {
  /// The buttons in the group. Navigation order = list order.
  final List<ButtonModel> buttons;

  /// Whether navigation wraps at ends.
  final bool wrapNavigation;

  /// Custom key bindings. Null uses defaults.
  final KeyBinding<ButtonGroupAction>? keyBinding;

  bool _focused;
  int _focusedIndex;

  /// Creates a ButtonGroupModel.
  ButtonGroupModel({
    required this.buttons,
    this.wrapNavigation = false,
    bool focused = false,
    int initialFocusIndex = 0,
    this.keyBinding,
  }) : _focused = focused,
       _focusedIndex = buttons.isEmpty ? 0 : initialFocusIndex.clamp(0, buttons.length - 1) {
    _updateButtonFocus();
  }

  /// Whether the group is focused.
  bool get focused => _focused;

  @override
  set focused(bool value) {
    _focused = value;
    _updateButtonFocus();
  }

  /// The index of the currently focused button.
  int get focusedIndex => _focusedIndex;

  /// The currently focused button, or null if empty.
  ButtonModel? get focusedButton => buttons.isNotEmpty ? buttons[_focusedIndex] : null;

  /// The effective key binding (custom or default).
  KeyBinding<ButtonGroupAction> get effectiveKeyBinding => keyBinding ?? defaultButtonGroupBindings;

  /// Focus a button by its id.
  void focusButton(String id) => focusIndex(buttons.indexWhere((b) => b.id == id));

  /// Focus a button by index.
  void focusIndex(int index) {
    if (index < 0 || index >= buttons.length) return;
    buttons[_focusedIndex].focused = false;
    _focusedIndex = index;
    if (_focused) {
      buttons[_focusedIndex].focused = true;
    }
  }

  /// Updates the model based on the message.
  ///
  /// Handles navigation between buttons and delegates to focused button.
  Cmd? update(Msg msg) {
    if (!_focused) return null;
    if (buttons.isEmpty) return null;

    if (msg case KeyMsg()) {
      return _handleKey(msg);
    }
    return null;
  }

  Cmd? _handleKey(KeyMsg msg) {
    // Check for navigation action
    final action = effectiveKeyBinding.resolve(msg);
    if (action != null) {
      return _handleNavigation(action);
    }

    // Delegate to focused button
    return focusedButton?.update(msg);
  }

  Cmd? _handleNavigation(ButtonGroupAction action) {
    final delta = action == ButtonGroupAction.prev ? -1 : 1;
    final newIndex = _focusedIndex + delta;

    // Check boundary
    if (newIndex < 0 || newIndex >= buttons.length) {
      if (!wrapNavigation) {
        return const Unhandled();
      }
      // Wrap around
      final wrappedIndex = newIndex < 0 ? buttons.length - 1 : 0;
      focusIndex(wrappedIndex);
      return null;
    }

    focusIndex(newIndex);
    return null;
  }

  void _updateButtonFocus() {
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].focused = _focused && i == _focusedIndex;
    }
  }
}
