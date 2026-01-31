import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// Styles for button widget states.
@immutable
class ButtonStyles {
  /// Style for default/normal state.
  final Style? normal;

  /// Style for focused/hover state.
  final Style? focus;

  /// Style for disabled state.
  final Style? disabled;

  /// Style for loading state.
  final Style? loading;

  /// Creates ButtonStyles.
  const ButtonStyles({this.normal, this.focus, this.disabled, this.loading});

  /// Default button styles.
  static const defaultStyle = ButtonStyles(
    normal: Style(fg: Color.white, bg: Color.blue),
    focus: Style(fg: Color.white, bg: Color.cyan),
    disabled: Style(fg: Color.darkGray, bg: Color.gray),
    loading: Style(fg: Color.yellow, bg: Color.blue),
  );

  /// Merges [other] on top of this, non-null values override.
  ButtonStyles merge(ButtonStyles? other) {
    if (other == null) return this;
    return ButtonStyles(
      normal: other.normal ?? normal,
      focus: other.focus ?? focus,
      disabled: other.disabled ?? disabled,
      loading: other.loading ?? loading,
    );
  }

  /// Creates a copy with the given fields replaced.
  ButtonStyles copyWith({
    Style? normal,
    Style? focus,
    Style? disabled,
    Style? loading,
  }) {
    return ButtonStyles(
      normal: normal ?? this.normal,
      focus: focus ?? this.focus,
      disabled: disabled ?? this.disabled,
      loading: loading ?? this.loading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ButtonStyles &&
        other.normal == normal &&
        other.focus == focus &&
        other.disabled == disabled &&
        other.loading == loading;
  }

  @override
  int get hashCode => Object.hash(normal, focus, disabled, loading);
}
