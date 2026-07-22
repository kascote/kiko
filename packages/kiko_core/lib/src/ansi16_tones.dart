import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;
import 'package:termlib/color_util.dart' as tl;
import 'package:termlib/termlib.dart' as tl;

import 'colors.dart';
import 'theme.dart';
import 'tone.dart';

/// A theme's tones re-expressed as the fixed ANSI-16 palette.
///
/// At full color, a theme is free RGB and every hue is available. A plain
/// 16-color terminal has no free hues at all — only sixteen fixed slots the
/// user has already picked colors for. Rather than downsample (which just
/// finds a *nearby* slot and quietly loses the theme's intent), each tone is
/// given a *named* slot: [error] is always red-family, [selection] is always
/// blue-family, and so on, so the terminal's own palette customization still
/// reads correctly.
///
/// Every entry is a [Tone] whose [Tone.color] (when set) is an ANSI-kind
/// [Color] in the 0-15 range; [Tone.on] is always black or white, chosen for
/// contrast, never a named hue.
///
/// A theme may hand-author this table ([Theme.tones16]); one without a
/// hand-authored table gets one via [Ansi16Tones.derive], computed once and
/// cached.
@immutable
class Ansi16Tones implements ToneSet {
  /// Main brand color for primary actions, as a named ANSI-16 pair.
  @override
  final Tone primary;

  /// Second-rank actions, less prominent than [primary].
  @override
  final Tone secondary;

  /// Attention-grabbing color for highlights and badges.
  @override
  final Tone accent;

  /// Destructive actions and invalid/error states.
  @override
  final Tone error;

  /// Cautions and warnings.
  @override
  final Tone warning;

  /// Confirmations and success states.
  @override
  final Tone success;

  /// The app base color.
  @override
  final Tone background;

  /// Elevated surfaces — cards, dialogs, panels.
  @override
  final Tone surface;

  /// Resting chrome (borders, separators).
  @override
  final Tone border;

  /// Secondary/dimmed text.
  @override
  final Tone muted;

  /// Non-interactive elements.
  @override
  final Tone disabled;

  /// Keyboard focus indicator ("you are here").
  @override
  final Tone focus;

  /// Chosen items (selected rows, picked options).
  @override
  final Tone selection;

  /// The current row/column tint.
  ///
  /// [cursor] paints as a fill in the resolver's state matrix, so it needs a
  /// named slot here; `hover` never does (see [ToneSet]) and has none.
  @override
  final Tone cursor;

  /// Creates a table from its named tones.
  const Ansi16Tones({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.error,
    required this.warning,
    required this.success,
    required this.background,
    required this.surface,
    required this.border,
    required this.muted,
    required this.disabled,
    required this.focus,
    required this.selection,
    required this.cursor,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ansi16Tones &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.accent == accent &&
        other.error == error &&
        other.warning == warning &&
        other.success == success &&
        other.background == background &&
        other.surface == surface &&
        other.border == border &&
        other.muted == muted &&
        other.disabled == disabled &&
        other.focus == focus &&
        other.selection == selection &&
        other.cursor == cursor;
  }

  @override
  int get hashCode => Object.hash(
    Ansi16Tones,
    primary,
    secondary,
    accent,
    error,
    warning,
    success,
    background,
    surface,
    border,
    muted,
    disabled,
    focus,
    selection,
    cursor,
  );

  // Auto-derived tables, keyed by the exact Theme instance they came from.
  // An identity-keyed map: two structurally-equal themes still get their own
  // entries, and a theme's derived table is stable for as long as the Theme
  // instance is (built-in themes are static consts, so this is forever).
  static final Map<Theme, Ansi16Tones> _memo = Map<Theme, Ansi16Tones>.identity();

  /// Derives an [Ansi16Tones] table from [theme]'s RGB tones.
  ///
  /// Computed once per [theme] instance and cached, so every resolver built
  /// from the same theme shares one table instead of re-deriving it.
  ///
  /// Each tone's color converts through the terminal's own RGB→ANSI-16
  /// nearest-color search (an ANSI color passes through unchanged). The
  /// paired `on` is picked fresh from the *mapped* color's luminance — black
  /// on a light slot, white on a dark one — deliberately ignoring the
  /// theme's original `on`: a white-or-black choice made from the color that
  /// is actually going to be painted can never collide with it, which
  /// picking from the original RGB `on` could not guarantee. Identical
  /// theme tones that map to the same ANSI slot are left identical here;
  /// this derivation makes no attempt to spread them apart.
  factory Ansi16Tones.derive(Theme theme) {
    final cached = _memo[theme];
    if (cached != null) return cached;

    final derived = Ansi16Tones(
      primary: _deriveTone(theme.primary),
      secondary: _deriveTone(theme.secondary),
      accent: _deriveTone(theme.accent),
      error: _deriveTone(theme.error),
      warning: _deriveTone(theme.warning),
      success: _deriveTone(theme.success),
      background: _deriveTone(theme.background),
      surface: _deriveTone(theme.surface),
      border: _deriveTone(theme.border),
      muted: _deriveTone(theme.muted),
      disabled: _deriveTone(theme.disabled),
      focus: _deriveTone(theme.focus),
      selection: _deriveTone(theme.selection),
      cursor: _deriveTone(theme.cursor),
    );
    _memo[theme] = derived;
    return derived;
  }

  static Tone _deriveTone(Tone tone) {
    final color16 = _toAnsi16(tone.color);
    return Tone(color: color16, on: color16 == null ? null : _onFor(color16));
  }

  // Maps a color of any kind onto one of the 16 ANSI colors. Null stays
  // null (a tone with no identity color has nothing to map); an ANSI color
  // is already a valid slot and passes through untouched.
  static Color? _toAnsi16(Color? color) {
    if (color == null) return null;
    if (color.kind == ColorKind.ansi) return color;

    final source = color.kind == ColorKind.indexed ? tl.Color.indexed(color.value) : tl.Color.fromRGB(color.value);
    final mapped = source.convert(tl.ColorKind.ansi);
    return Color.ansi(mapped.value);
  }

  // Black or white, whichever reads better on the mapped ANSI slot — judged
  // by that slot's own RGB hex, not the theme's original color.
  static Color _onFor(Color color16) {
    final hex = ansi.ansiHex[color16.value];
    final luminance = tl.colorLuminance(tl.Color.fromRGB(hex));
    return luminance < 0.5 ? Color.white : Color.black;
  }
}
