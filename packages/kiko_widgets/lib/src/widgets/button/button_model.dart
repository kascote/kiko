import 'package:kiko/kiko.dart';

import 'button_styles.dart';
import 'types.dart';

/// Model for a single button.
///
/// Holds both state and config. Use [update] to handle messages.
/// Returns [ButtonPressCmd] when activated.
///
/// Has `copyWith` for creating modified copies. Mutable fields are
/// `focused` (required by [Focusable] interface) and `loading`.
class ButtonModel implements Focusable {
  /// Unique identifier for the button.
  final String id;

  /// Button text (must be single line).
  final Line label;

  /// Whether the button is disabled.
  final bool disabled;

  /// Content shown during loading.
  final Line loadingText;

  /// Horizontal padding (symmetric).
  final int padding;

  /// Custom styles for the button.
  final ButtonStyles styles;

  /// Custom key bindings. Null uses defaults.
  final KeyBinding<ButtonAction>? keyBinding;

  bool _focused;

  /// Whether the button is in loading state.
  bool loading;

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
    ButtonStyles? styles,
    this.keyBinding,
  }) : _focused = focused,
       loadingText = loadingText ?? _defaultLoadingText,
       styles = styles ?? ButtonStyles.defaultStyle;

  /// Whether the button is focused.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// The effective key binding (custom or default).
  KeyBinding<ButtonAction> get effectiveKeyBinding => keyBinding ?? defaultButtonBindings;

  /// Width of the button in terminal characters.
  int get width => label.width + (padding * 2);

  /// Gets the current style based on state.
  Style? get currentStyle {
    if (disabled) return styles.disabled;
    if (loading) return styles.loading;
    if (focused) return styles.focus;
    return styles.normal;
  }

  /// Updates the model based on the message.
  ///
  /// Returns [ButtonPressCmd] when activated, [Unhandled] for unhandled keys.
  Cmd? update(Msg msg) {
    if (!focused) return null;

    if (msg case KeyMsg()) {
      return _handleKey(msg);
    }
    return null;
  }

  Cmd? _handleKey(KeyMsg msg) {
    // Ignore activation when disabled or loading
    if (disabled || loading) {
      final action = effectiveKeyBinding.resolve(msg);
      if (action == ButtonAction.activate) {
        return null; // Silent ignore
      }
    }

    final action = effectiveKeyBinding.resolve(msg);
    if (action == ButtonAction.activate) {
      return ButtonPressCmd(id);
    }

    return const Unhandled();
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
    ButtonStyles? styles,
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
      styles: styles ?? this.styles,
      keyBinding: keyBinding ?? this.keyBinding,
    );
  }
}
