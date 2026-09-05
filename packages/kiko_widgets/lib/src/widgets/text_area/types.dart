import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

// ═══════════════════════════════════════════════════════════
// STYLE
// ═══════════════════════════════════════════════════════════

/// Region-based styles for TextArea widget: one nullable style slot per
/// region.
///
/// A `null` slot is derived from the theme's tones by the widget, through a
/// [StyleResolver]; a non-null slot is the caller's exact style and wins
/// verbatim. State-based styling (focused, disabled) is handled by
/// [StyleResolver] separately, in the widget.
///
/// | slot          | derived default            | matrix source      |
/// | ------------- | --------------------------- | ------------------ |
/// | `placeholder` | `resolver.ink(muted)`       | anatomy-specific   |
/// | `selection`   | `resolver.fill(selection)`  | anatomy-specific   |
/// | `lineNumber`  | `resolver.ink(muted)`       | anatomy-specific   |
@immutable
class TextAreaStyle {
  /// Style for placeholder text.
  final Style? placeholder;

  /// Style for selected text.
  final Style? selection;

  /// Style for line numbers.
  final Style? lineNumber;

  /// Creates a TextAreaStyle.
  const TextAreaStyle({
    this.placeholder,
    this.selection,
    this.lineNumber,
  });

  /// Merges [other] on top of this, non-null values override.
  TextAreaStyle merge(TextAreaStyle? other) {
    if (other == null) return this;
    return TextAreaStyle(
      placeholder: other.placeholder ?? placeholder,
      selection: other.selection ?? selection,
      lineNumber: other.lineNumber ?? lineNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextAreaStyle &&
        other.placeholder == placeholder &&
        other.selection == selection &&
        other.lineNumber == lineNumber;
  }

  @override
  int get hashCode => Object.hash(placeholder, selection, lineNumber);
}
