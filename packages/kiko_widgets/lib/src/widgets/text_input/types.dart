import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

// ═══════════════════════════════════════════════════════════
// STYLE
// ═══════════════════════════════════════════════════════════

/// Region-based styles for the text input's plume view: one nullable style
/// slot per region.
///
/// A `null` slot is derived from the theme's tones by the view, through a
/// [StyleResolver]; a non-null slot is the caller's exact style and wins
/// verbatim. State-based styling (focused, disabled) is handled by
/// [StyleResolver] separately, in the view.
///
/// | slot          | derived default            | matrix source      |
/// | ------------- | --------------------------- | ------------------ |
/// | `placeholder` | `resolver.ink(muted)`       | anatomy-specific   |
/// | `fill`        | `resolver.ink(muted)`       | anatomy-specific   |
/// | `obscured`    | none (inherits the base text style) | —          |
@immutable
class TextInputStyle {
  /// Style for placeholder text.
  final Style? placeholder;

  /// Style for fill characters.
  final Style? fill;

  /// Style for obscured text (password dots).
  final Style? obscured;

  /// Creates a TextInputStyle.
  const TextInputStyle({this.placeholder, this.fill, this.obscured});

  /// Merges [other] on top of this, non-null values override.
  TextInputStyle merge(TextInputStyle? other) {
    if (other == null) return this;
    return TextInputStyle(
      placeholder: other.placeholder ?? placeholder,
      fill: other.fill ?? fill,
      obscured: other.obscured ?? obscured,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextInputStyle &&
        other.placeholder == placeholder &&
        other.fill == fill &&
        other.obscured == obscured;
  }

  @override
  int get hashCode => Object.hash(placeholder, fill, obscured);
}
