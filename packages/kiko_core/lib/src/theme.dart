import 'package:meta/meta.dart';

import 'colors.dart';
import 'style.dart';

/// Theme defines the visual appearance of widgets.
///
/// A theme is a collection of [Style]s, not raw colors. Each style has:
/// - `fg`: the primary color (used for text, borders)
/// - `bg`: the contrast color (used when inverted for surfaces)
///
/// Use [Style.inverted] to swap fg/bg for surface uses (buttons, selected rows).
///
/// ## Palette Styles
/// - [primary]: main brand color (buttons, links, selections)
/// - [secondary]: secondary actions, less prominent
/// - [accent]: highlights, badges, attention-grabbing elements
/// - [error]: errors, destructive actions
/// - [success]: success states, confirmations
/// - [warning]: warnings, cautions
/// - [surface]: elevated surfaces, cards, dialogs
/// - [background]: base background; `background.fg` is default text color,
///   `background.bg` is actual background color
///
/// ## Semantic Styles
/// - [focus]: focused element indicator
/// - [muted]: secondary/dimmed text
/// - [disabled]: disabled elements
/// - [border]: default border color
/// - [highlight]: search matches, selections
@immutable
class Theme {
  // === Palette Styles ===

  /// Main brand color for primary actions.
  final Style primary;

  /// Secondary color for less prominent actions.
  final Style secondary;

  /// Accent color for highlights and badges.
  final Style accent;

  /// Error color for destructive actions and error states.
  final Style error;

  /// Success color for confirmations and success states.
  final Style success;

  /// Warning color for cautions and warnings.
  final Style warning;

  /// Surface color for elevated elements (cards, dialogs).
  final Style surface;

  /// Background style.
  ///
  /// - `background.bg` = actual background color
  /// - `background.fg` = default text color on background
  final Style background;

  // === Semantic Styles ===

  /// Focus indicator style.
  final Style focus;

  /// Muted/secondary text style.
  final Style muted;

  /// Disabled element style.
  final Style disabled;

  /// Default border style.
  final Style border;

  /// Highlight style for search matches and selections.
  final Style highlight;

  /// Creates a theme with the given styles.
  const Theme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.error,
    required this.success,
    required this.warning,
    required this.surface,
    required this.background,
    required this.focus,
    required this.muted,
    required this.disabled,
    required this.border,
    required this.highlight,
  });

  /// Kiko Dark theme - deep slate base with muted warm accents.
  static const Theme dark = Theme(
    primary: Style(fg: Color.rgb(0x58a6b0), bg: Color.rgb(0x0d1117)),
    secondary: Style(fg: Color.rgb(0x8b7ec8), bg: Color.rgb(0x0d1117)),
    accent: Style(fg: Color.rgb(0xd4976c), bg: Color.rgb(0x0d1117)),
    error: Style(fg: Color.rgb(0xc75d5d), bg: Color.rgb(0x0d1117)),
    success: Style(fg: Color.rgb(0x6aab73), bg: Color.rgb(0x0d1117)),
    warning: Style(fg: Color.rgb(0xc9a857), bg: Color.rgb(0x0d1117)),
    surface: Style(fg: Color.rgb(0xc9d1d9), bg: Color.rgb(0x161b22)),
    background: Style(fg: Color.rgb(0xc9d1d9), bg: Color.rgb(0x0d1117)),
    focus: Style(fg: Color.rgb(0x6bc5d2), addModifier: Modifier.bold),
    muted: Style(fg: Color.rgb(0x6e7681)),
    disabled: Style(fg: Color.rgb(0x484f58), addModifier: Modifier.dim),
    border: Style(fg: Color.rgb(0x30363d)),
    highlight: Style(fg: Color.rgb(0xc9d1d9), bg: Color.rgb(0x264a5c)),
  );

  /// Kiko Light theme - warm white base with deeper accents.
  static const Theme light = Theme(
    primary: Style(fg: Color.rgb(0x1a7f8e), bg: Color.rgb(0xf6f8fa)),
    secondary: Style(fg: Color.rgb(0x6b5ba8), bg: Color.rgb(0xf6f8fa)),
    accent: Style(fg: Color.rgb(0xb87a4a), bg: Color.rgb(0xf6f8fa)),
    error: Style(fg: Color.rgb(0xb54343), bg: Color.rgb(0xf6f8fa)),
    success: Style(fg: Color.rgb(0x3d8b48), bg: Color.rgb(0xf6f8fa)),
    warning: Style(fg: Color.rgb(0xa68830), bg: Color.rgb(0xf6f8fa)),
    surface: Style(fg: Color.rgb(0x1f2328), bg: Color.rgb(0xeef1f5)),
    background: Style(fg: Color.rgb(0x1f2328), bg: Color.rgb(0xf6f8fa)),
    focus: Style(fg: Color.rgb(0x2a8a9a), addModifier: Modifier.bold),
    muted: Style(fg: Color.rgb(0x8b949e)),
    disabled: Style(fg: Color.rgb(0xafb8c1), addModifier: Modifier.dim),
    border: Style(fg: Color.rgb(0xd0d7de)),
    highlight: Style(fg: Color.rgb(0x1f2328), bg: Color.rgb(0xddf4ff)),
  );

  /// Ember theme - warm orange palette with teal accents on near-black base.
  ///
  /// Uses complementary color theory: orange primary with teal accent.
  /// Warm-tinted semantic colors (coral error, olive success) maintain cohesion.
  static const Theme ember = Theme(
    primary: Style(fg: Color.rgb(0xe07830), bg: Color.rgb(0x0a0908)),
    secondary: Style(fg: Color.rgb(0xa85545), bg: Color.rgb(0x0a0908)),
    accent: Style(fg: Color.rgb(0x45a5a5), bg: Color.rgb(0x0a0908)),
    error: Style(fg: Color.rgb(0xcc5555), bg: Color.rgb(0x0a0908)),
    success: Style(fg: Color.rgb(0x88a540), bg: Color.rgb(0x0a0908)),
    warning: Style(fg: Color.rgb(0xd5a030), bg: Color.rgb(0x0a0908)),
    surface: Style(fg: Color.rgb(0xcdc0b4), bg: Color.rgb(0x16120f)),
    background: Style(fg: Color.rgb(0xcdc0b4), bg: Color.rgb(0x0a0908)),
    focus: Style(fg: Color.rgb(0x55c5c5), addModifier: Modifier.bold),
    muted: Style(fg: Color.rgb(0x6a6055)),
    disabled: Style(fg: Color.rgb(0x4a4540), addModifier: Modifier.dim),
    border: Style(fg: Color.rgb(0x2a2420)),
    highlight: Style(fg: Color.rgb(0xcdc0b4), bg: Color.rgb(0x1a3535)),
  );

  /// ANSI-16 dark theme for basic terminal compatibility.
  static const Theme ansiDark = Theme(
    primary: Style(fg: Color.cyan, bg: Color.black),
    secondary: Style(fg: Color.magenta, bg: Color.black),
    accent: Style(fg: Color.yellow, bg: Color.black),
    error: Style(fg: Color.red, bg: Color.white),
    success: Style(fg: Color.green, bg: Color.black),
    warning: Style(fg: Color.yellow, bg: Color.black),
    surface: Style(fg: Color.white, bg: Color.darkGray),
    background: Style(fg: Color.white, bg: Color.black),
    focus: Style(fg: Color.brightCyan, addModifier: Modifier.bold),
    muted: Style(fg: Color.darkGray),
    disabled: Style(fg: Color.darkGray, addModifier: Modifier.dim),
    border: Style(fg: Color.gray),
    highlight: Style(fg: Color.black, bg: Color.yellow),
  );

  /// Creates a copy of this theme with the given fields replaced.
  Theme copyWith({
    Style? primary,
    Style? secondary,
    Style? accent,
    Style? error,
    Style? success,
    Style? warning,
    Style? surface,
    Style? background,
    Style? focus,
    Style? muted,
    Style? disabled,
    Style? border,
    Style? highlight,
  }) => Theme(
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    accent: accent ?? this.accent,
    error: error ?? this.error,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    surface: surface ?? this.surface,
    background: background ?? this.background,
    focus: focus ?? this.focus,
    muted: muted ?? this.muted,
    disabled: disabled ?? this.disabled,
    border: border ?? this.border,
    highlight: highlight ?? this.highlight,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Theme &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.accent == accent &&
        other.error == error &&
        other.success == success &&
        other.warning == warning &&
        other.surface == surface &&
        other.background == background &&
        other.focus == focus &&
        other.muted == muted &&
        other.disabled == disabled &&
        other.border == border &&
        other.highlight == highlight;
  }

  @override
  int get hashCode => Object.hash(
    primary,
    secondary,
    accent,
    error,
    success,
    warning,
    surface,
    background,
    focus,
    muted,
    disabled,
    border,
    highlight,
  );
}
