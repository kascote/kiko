import 'package:meta/meta.dart';

import 'ansi16_tones.dart';
import 'colors.dart';
import 'theme_derive.dart';
import 'tone.dart';

/// A theme is a small, fixed set of [Tone]s — color identities the whole app
/// shares.
///
/// A theme owns *which* colors exist, never how they land as paint: every tone
/// becomes cells only through a projection ([Tone.ink] / [SurfaceTone.fill] /
/// [Tone.wash]), usually via `StyleResolver`. Per-widget parts are anatomy
/// (widget style slots) and interaction facts are widget states, so this set
/// stays frozen while widgets grow freely.
///
/// Beside the tones a theme carries [name], the label a theme picker shows,
/// and two numbers the resolver reads: [step] and [deEmphasis].
///
/// ## Tone groups
///
/// Intent — the meaning of an action or status:
/// - [primary], [secondary], [accent]
/// - [error], [warning], [success]
///
/// Neutral — the surfaces and quiet text:
/// - [background]: the app base; `background.color` is the base bg,
///   `background.on` is the default text color
/// - [surface]: elevated panels and dialogs
/// - [border]: resting chrome
/// - [muted]: secondary text
/// - [disabled]: non-interactive elements
///
/// Interaction:
/// - [selection]: the chosen items
///
/// Focus, cursor, hover and pressed are not tones. Each is a state layer the
/// resolver lifts from the ground a part sits on, one [step] at a time.
///
/// The neutral tones are rungs on one ladder from [background] to its `on`.
/// How to space them, and the contrast each rung needs, is the "Authoring
/// a theme" section of `docs/theming.md`.
///
/// ## The ANSI-16 tier
///
/// A theme is authored once, in RGB. On a plain 16-color terminal the
/// resolver does not downsample that RGB — it re-expresses each tone through
/// [tones16], a named ANSI-16 pair, so a theme keeps its meaning (error is
/// still red, selection is still blue) instead of drifting toward whatever
/// RGB happens to be nearest. [tones16] is optional: a theme without a
/// hand-authored table gets one derived automatically ([Ansi16Tones.derive]).
///
/// A theme always has a background color. The app paints the whole frame
/// with it.
@immutable
class Theme implements ToneSet {
  /// The display name, for a theme picker or a status line.
  final String name;

  // === Intent ===

  /// Main brand color for primary actions.
  @override
  final SurfaceTone primary;

  /// Second-rank actions, less prominent than [primary].
  @override
  final SurfaceTone secondary;

  /// Attention-grabbing color for highlights and badges.
  @override
  final SurfaceTone accent;

  /// Destructive actions and invalid/error states.
  @override
  final SurfaceTone error;

  /// Cautions and warnings.
  @override
  final SurfaceTone warning;

  /// Confirmations and success states.
  @override
  final SurfaceTone success;

  // === Neutral ===

  /// The app base color.
  ///
  /// `background.color` is the base background; `background.on` is the default
  /// text color drawn on it.
  ///
  /// Nothing in the runtime paints it. The app grounds the frame with it at the
  /// top of `view` through `Frame.ground`; see `docs/theming.md`.
  @override
  final SurfaceTone background;

  /// Elevated surfaces — cards, dialogs, panels.
  @override
  final SurfaceTone surface;

  /// Resting chrome (borders, separators).
  @override
  final Tone border;

  /// Secondary/dimmed text.
  @override
  final Tone muted;

  /// Non-interactive elements.
  @override
  final Tone disabled;

  // === Interaction ===

  /// Chosen items (selected rows, picked options).
  @override
  final SurfaceTone selection;

  /// Hand-authored ANSI-16 re-expression of this theme's tones.
  ///
  /// Leave `null` to have the resolver derive one automatically
  /// ([Ansi16Tones.derive]) and cache it — most themes need nothing here.
  final Ansi16Tones? tones16;

  /// How far a de-emphasised part moves toward its ground, from 0 (not at
  /// all) to 1 (fully onto the ground).
  ///
  /// `StyleResolver.deEmphasised` blends every color it hands out by this
  /// amount. Under ANSI-16 and `NO_COLOR` it adds dim instead.
  final double deEmphasis;

  /// Creates a theme from its tones.
  const Theme({
    required this.name,
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
    required this.selection,
    this.tones16,
    this.deEmphasis = 0.45,
  });

  /// One state step, as a distance in OKLab lightness.
  ///
  /// `StyleResolver` moves a background this far from the ground it lands on
  /// for `WidgetState.focused` and `WidgetState.cursor`. Hover moves half a
  /// step and `WidgetState.pressed` one step past hover.
  static const double step = 0.12;

  /// The fraction a disabled fill's `fg` and `bg` move toward the ground
  /// color.
  ///
  /// `StyleResolver` blends with this under `RenderPolicy.color` only, when
  /// the base already carries a background.
  static const double disabledMix = 0.5;

  /// Kiko Dark theme - deep slate base with muted warm accents.
  ///
  /// The three neutral rungs `border`, `muted` and `disabled` read on both the
  /// background and the surface (`deriveTheme`).
  static const Theme dark = Theme(
    name: 'Kiko Dark',
    primary: SurfaceTone(color: Color.rgb(0x58a6b0), on: Color.rgb(0x0d1117)),
    secondary: SurfaceTone(color: Color.rgb(0x8b7ec8), on: Color.rgb(0x0d1117)),
    accent: SurfaceTone(color: Color.rgb(0xd4976c), on: Color.rgb(0x0d1117)),
    error: SurfaceTone(color: Color.rgb(0xc75d5d), on: Color.rgb(0x0d1117)),
    warning: SurfaceTone(color: Color.rgb(0xc9a857), on: Color.rgb(0x0d1117)),
    success: SurfaceTone(color: Color.rgb(0x6aab73), on: Color.rgb(0x0d1117)),
    background: SurfaceTone(color: Color.rgb(0x0d1117), on: Color.rgb(0xc9d1d9)),
    surface: SurfaceTone(color: Color.rgb(0x161b22), on: Color.rgb(0xc9d1d9)),
    border: Tone(color: Color.rgb(0x343a41)),
    muted: Tone(color: Color.rgb(0x7b838e)),
    disabled: Tone(color: Color.rgb(0x5f6770)),
    selection: SurfaceTone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9)),
    // This table is the reference for how every built-in theme picks its
    // ANSI-16 pairs; new themes should copy this pattern rather than the
    // exact colors below.
    //
    // - color: pick the ANSI-16 hue family that reads as this tone's
    //   identity, not whichever of the sixteen happens to be numerically
    //   closest to the RGB value.
    // - on: black or white, chosen by whether the slot itself reads as a
    //   dark tone or a light one — black, red, blue and their bright
    //   variants read dark and take white; green, yellow, cyan, magenta,
    //   gray and their bright variants read light and take black. Two
    //   mid-tones never pair together.
    // - bright variants are the spare headroom: spend them on accent once a
    //   hue family is already used elsewhere, so the intents stay visually
    //   distinct from one another.
    // - background, surface, border, muted and disabled collapse into the
    //   four grays (black, darkGray, gray, white); keep each theme's own
    //   relative light-to-dark ordering when choosing among them, since
    //   that ordering differs between a dark theme and a light one.
    // - a tone with no readable `on` on the RGB side (border, muted,
    //   disabled) gets no `on` here either; a tone with no RGB color at
    //   all stays null.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.cyan, on: Color.black),
      secondary: SurfaceTone(color: Color.blue, on: Color.white),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Catppuccin Mocha - the darkest Catppuccin flavor: soft pastel accents on
  /// a cool near-black base.
  ///
  /// Every color is a Mocha palette entry. Intent tones take the palette's
  /// own hues (blue, mauve, peach, red, yellow, green) with `crust` as their
  /// text; neutrals climb the palette's crust → base → surface → overlay →
  /// subtext ladder, with `crust` as the ground and `base` as the raised
  /// surface.
  static const Theme catppuccin = Theme(
    name: 'Catppuccin Mocha',
    primary: SurfaceTone(color: Color.rgb(0x89b4fa), on: Color.rgb(0x11111b)),
    secondary: SurfaceTone(color: Color.rgb(0xcba6f7), on: Color.rgb(0x11111b)),
    accent: SurfaceTone(color: Color.rgb(0xfab387), on: Color.rgb(0x11111b)),
    error: SurfaceTone(color: Color.rgb(0xf38ba8), on: Color.rgb(0x11111b)),
    warning: SurfaceTone(color: Color.rgb(0xf9e2af), on: Color.rgb(0x11111b)),
    success: SurfaceTone(color: Color.rgb(0xa6e3a1), on: Color.rgb(0x11111b)),
    background: SurfaceTone(color: Color.rgb(0x11111b), on: Color.rgb(0xcdd6f4)),
    surface: SurfaceTone(color: Color.rgb(0x1e1e2e), on: Color.rgb(0xcdd6f4)),
    border: Tone(color: Color.rgb(0x45475a)),
    muted: Tone(color: Color.rgb(0xa6adc8)),
    disabled: Tone(color: Color.rgb(0x6c7086)),
    selection: SurfaceTone(color: Color.rgb(0x585b70), on: Color.rgb(0xcdd6f4)),
    // Follows the pattern documented on [dark]'s table. Blue primary and the
    // gray selection both land on plain blue — an accepted collapse. Peach
    // accent takes brightRed, the orange stand-in.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.blue, on: Color.white),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Rosé Pine - the main (darkest) variant: muted rose, gold, and teal on a
  /// deep violet-black base.
  ///
  /// Every color is a Rosé Pine palette entry, placed by the palette's own
  /// role guide: `love` for errors, `gold` for warnings, `pine` as the
  /// green, `subtle` and `muted` for the two text ranks, `highlightMed` for
  /// selection, `highlightHigh` for borders.
  static const Theme rosePine = Theme(
    name: 'Rosé Pine',
    primary: SurfaceTone(color: Color.rgb(0x9ccfd8), on: Color.rgb(0x191724)),
    secondary: SurfaceTone(color: Color.rgb(0xc4a7e7), on: Color.rgb(0x191724)),
    accent: SurfaceTone(color: Color.rgb(0xebbcba), on: Color.rgb(0x191724)),
    error: SurfaceTone(color: Color.rgb(0xeb6f92), on: Color.rgb(0x191724)),
    warning: SurfaceTone(color: Color.rgb(0xf6c177), on: Color.rgb(0x191724)),
    success: SurfaceTone(color: Color.rgb(0x31748f), on: Color.rgb(0xe0def4)),
    background: SurfaceTone(color: Color.rgb(0x191724), on: Color.rgb(0xe0def4)),
    surface: SurfaceTone(color: Color.rgb(0x1f1d2e), on: Color.rgb(0xe0def4)),
    border: Tone(color: Color.rgb(0x524f67)),
    muted: Tone(color: Color.rgb(0x908caa)),
    disabled: Tone(color: Color.rgb(0x6e6a86)),
    selection: SurfaceTone(color: Color.rgb(0x403d52), on: Color.rgb(0xe0def4)),
    // Follows the pattern documented on [dark]'s table, with the palette's
    // own terminal mapping: foam is cyan, iris is magenta, rose is
    // brightMagenta, love is red, gold is yellow, pine is green.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.cyan, on: Color.black),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightMagenta, on: Color.black),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Gruvbox dark - retro-groove pastels on a warm dark-gray base.
  ///
  /// Every color but `muted` is a Gruvbox dark-mode palette entry. The bright variants
  /// carry the intents (orange primary, blue secondary, purple accent, red,
  /// yellow, green) with the hard-contrast `bg0_h` as their
  /// text; the neutrals climb `bg0_h` → `bg0` → `bg2` → `bg3`, with `bg0_h`
  /// as the ground and `bg0` as the raised surface, and the two text ranks
  /// are `gray` and `bg4`. `muted` is `gray` lightened until it reads on both
  /// grounds (`deriveTheme`).
  static const Theme gruvbox = Theme(
    name: 'Gruvbox',
    primary: SurfaceTone(color: Color.rgb(0xfe8019), on: Color.rgb(0x1d2021)),
    secondary: SurfaceTone(color: Color.rgb(0x83a598), on: Color.rgb(0x1d2021)),
    accent: SurfaceTone(color: Color.rgb(0xd3869b), on: Color.rgb(0x1d2021)),
    error: SurfaceTone(color: Color.rgb(0xfb4934), on: Color.rgb(0x1d2021)),
    warning: SurfaceTone(color: Color.rgb(0xfabd2f), on: Color.rgb(0x1d2021)),
    success: SurfaceTone(color: Color.rgb(0xb8bb26), on: Color.rgb(0x1d2021)),
    background: SurfaceTone(color: Color.rgb(0x1d2021), on: Color.rgb(0xebdbb2)),
    surface: SurfaceTone(color: Color.rgb(0x282828), on: Color.rgb(0xebdbb2)),
    border: Tone(color: Color.rgb(0x504945)),
    muted: Tone(color: Color.rgb(0x9b8c7d)),
    disabled: Tone(color: Color.rgb(0x7c6f64)),
    selection: SurfaceTone(color: Color.rgb(0x665c54), on: Color.rgb(0xfbf1c7)),
    // Follows the pattern documented on [dark]'s table. Orange primary takes
    // brightRed, the orange stand-in, leaving plain red for error; blue
    // secondary and the gray selection share plain blue — an accepted
    // collapse.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.brightRed, on: Color.white),
      secondary: SurfaceTone(color: Color.blue, on: Color.white),
      accent: SurfaceTone(color: Color.magenta, on: Color.black),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Monokai Pro - the default (dark) filter: vivid accents on a muted
  /// plum-gray base.
  ///
  /// Every color but `border` and `disabled` is a Monokai Pro palette entry;
  /// those two are palette grays lightened until they read on both grounds
  /// (`deriveTheme`). The six accents carry the
  /// intents (blue primary, purple secondary, orange accent, red, yellow,
  /// green) with the base background as their text; `dark1` is the raised
  /// surface, and the `dimmed` ramp supplies border, selection, and the two
  /// text ranks.
  static const Theme monokai = Theme(
    name: 'Monokai Pro',
    primary: SurfaceTone(color: Color.rgb(0x78dce8), on: Color.rgb(0x2d2a2e)),
    secondary: SurfaceTone(color: Color.rgb(0xab9df2), on: Color.rgb(0x2d2a2e)),
    accent: SurfaceTone(color: Color.rgb(0xfc9867), on: Color.rgb(0x2d2a2e)),
    error: SurfaceTone(color: Color.rgb(0xff6188), on: Color.rgb(0x2d2a2e)),
    warning: SurfaceTone(color: Color.rgb(0xffd866), on: Color.rgb(0x2d2a2e)),
    success: SurfaceTone(color: Color.rgb(0xa9dc76), on: Color.rgb(0x2d2a2e)),
    background: SurfaceTone(color: Color.rgb(0x2d2a2e), on: Color.rgb(0xfcfcfa)),
    surface: SurfaceTone(color: Color.rgb(0x221f22), on: Color.rgb(0xfcfcfa)),
    border: Tone(color: Color.rgb(0x484649)),
    muted: Tone(color: Color.rgb(0x939293)),
    disabled: Tone(color: Color.rgb(0x757375)),
    selection: SurfaceTone(color: Color.rgb(0x5b595c), on: Color.rgb(0xfcfcfa)),
    // Follows the pattern documented on [dark]'s table. Orange accent takes
    // brightRed, the orange stand-in.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.cyan, on: Color.black),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Nord - arctic, bluish pastels on a dark blue-gray base.
  ///
  /// Every color but the three neutral rungs is a Nord palette entry, placed
  /// by the palette's own role guide: Polar Night `nord0` → `nord1` →
  /// `nord3` for ground, surface, and selection; Snow Storm `nord4` as text;
  /// Frost `nord8` as primary; Aurora for the intents. Nord has no mid
  /// gray, so `border`, `muted` and `disabled` start from Polar Night
  /// (`nord2`, the Vim port's comment color `#616e88`, and `nord3`) and are
  /// lightened until they read on both grounds (`deriveTheme`). Error takes
  /// `nord6` as its text; `nord0` reads too faintly on `nord11`.
  static const Theme nord = Theme(
    name: 'Nord',
    primary: SurfaceTone(color: Color.rgb(0x88c0d0), on: Color.rgb(0x2e3440)),
    secondary: SurfaceTone(color: Color.rgb(0xb48ead), on: Color.rgb(0x2e3440)),
    accent: SurfaceTone(color: Color.rgb(0xd08770), on: Color.rgb(0x2e3440)),
    error: SurfaceTone(color: Color.rgb(0xbf616a), on: Color.rgb(0xeceff4)),
    warning: SurfaceTone(color: Color.rgb(0xebcb8b), on: Color.rgb(0x2e3440)),
    success: SurfaceTone(color: Color.rgb(0xa3be8c), on: Color.rgb(0x2e3440)),
    background: SurfaceTone(color: Color.rgb(0x2e3440), on: Color.rgb(0xd8dee9)),
    surface: SurfaceTone(color: Color.rgb(0x3b4252), on: Color.rgb(0xd8dee9)),
    border: Tone(color: Color.rgb(0x535d6f)),
    muted: Tone(color: Color.rgb(0xa1afcb)),
    disabled: Tone(color: Color.rgb(0x828da3)),
    selection: SurfaceTone(color: Color.rgb(0x4c566a), on: Color.rgb(0xeceff4)),
    // Follows the pattern documented on [dark]'s table. Frost primary is
    // cyan; orange accent takes brightRed, the orange stand-in.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.cyan, on: Color.black),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Tokyo Night - the night variant: neon-tinted pastels on a deep
  /// blue-black base.
  ///
  /// Every color but the two text ranks is a Tokyo Night palette entry. The seven hues carry the
  /// intents (blue primary, magenta secondary, orange accent, red, yellow,
  /// green) with the darkest background as their text; the
  /// ground is `bg_dark1`, the raised surface is `bg`, `fg_gutter` is the
  /// border, `blue7` fills selection, and `dark5` and `comment` are the
  /// two text ranks, both lightened until they read on both grounds
  /// (`deriveTheme`).
  static const Theme tokyoNight = Theme(
    name: 'Tokyo Night',
    primary: SurfaceTone(color: Color.rgb(0x7aa2f7), on: Color.rgb(0x0c0e14)),
    secondary: SurfaceTone(color: Color.rgb(0xbb9af7), on: Color.rgb(0x0c0e14)),
    accent: SurfaceTone(color: Color.rgb(0xff9e64), on: Color.rgb(0x0c0e14)),
    error: SurfaceTone(color: Color.rgb(0xf7768e), on: Color.rgb(0x0c0e14)),
    warning: SurfaceTone(color: Color.rgb(0xe0af68), on: Color.rgb(0x0c0e14)),
    success: SurfaceTone(color: Color.rgb(0x9ece6a), on: Color.rgb(0x0c0e14)),
    background: SurfaceTone(color: Color.rgb(0x0c0e14), on: Color.rgb(0xc0caf5)),
    surface: SurfaceTone(color: Color.rgb(0x1a1b26), on: Color.rgb(0xc0caf5)),
    border: Tone(color: Color.rgb(0x3b4261)),
    muted: Tone(color: Color.rgb(0x7a81aa)),
    disabled: Tone(color: Color.rgb(0x5c658f)),
    selection: SurfaceTone(color: Color.rgb(0x394b70), on: Color.rgb(0xc0caf5)),
    // Follows the pattern documented on [dark]'s table. Blue primary and
    // the blue-tinted selection share plain blue — an accepted collapse. Orange
    // accent takes brightRed, the orange stand-in.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.blue, on: Color.white),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// One Dark - Atom's default: soft syntax hues on a cool charcoal base.
  ///
  /// Every color but the border and the two quieter text ranks is an Atom One Dark entry. The syntax hues carry the
  /// intents (blue primary, purple secondary, orange accent, red, yellow,
  /// green), all with the darkest UI
  /// level as their text; the ground is that darkest level, the raised
  /// surface is the editor background, the selection color is the selection,
  /// and the three `mono` grays are the text ranks. The border and the two
  /// quieter text ranks are lightened until they read on both grounds
  /// (`deriveTheme`).
  static const Theme oneDark = Theme(
    name: 'One Dark',
    primary: SurfaceTone(color: Color.rgb(0x61afef), on: Color.rgb(0x21252b)),
    secondary: SurfaceTone(color: Color.rgb(0xc678dd), on: Color.rgb(0x21252b)),
    accent: SurfaceTone(color: Color.rgb(0xd19a66), on: Color.rgb(0x21252b)),
    error: SurfaceTone(color: Color.rgb(0xe06c75), on: Color.rgb(0x21252b)),
    warning: SurfaceTone(color: Color.rgb(0xe5c07b), on: Color.rgb(0x21252b)),
    success: SurfaceTone(color: Color.rgb(0x98c379), on: Color.rgb(0x21252b)),
    background: SurfaceTone(color: Color.rgb(0x21252b), on: Color.rgb(0xabb2bf)),
    surface: SurfaceTone(color: Color.rgb(0x282c34), on: Color.rgb(0xabb2bf)),
    border: Tone(color: Color.rgb(0x414754)),
    muted: Tone(color: Color.rgb(0x8c94a2)),
    disabled: Tone(color: Color.rgb(0x6e7683)),
    selection: SurfaceTone(color: Color.rgb(0x3e4451), on: Color.rgb(0xabb2bf)),
    // Follows the pattern documented on [dark]'s table. Blue primary and
    // the gray selection share plain blue — an accepted collapse.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.blue, on: Color.white),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Dracula - vivid candy hues on a dark purple-gray base.
  ///
  /// Every color but the three neutral rungs is a Dracula palette entry. The seven hues carry the
  /// intents (purple primary, pink secondary, orange accent, red, yellow,
  /// green) with the darkest background as their text; the
  /// ground is that darkest background, the raised surface is the editor
  /// background, `comment` is muted text, and the selection color is the
  /// selection fill. The palette has no gray for chrome, so `border`, `muted`
  /// and `disabled` start from its grays and are lightened until they read on
  /// both grounds (`deriveTheme`).
  static const Theme dracula = Theme(
    name: 'Dracula',
    primary: SurfaceTone(color: Color.rgb(0xbd93f9), on: Color.rgb(0x191a21)),
    secondary: SurfaceTone(color: Color.rgb(0xff79c6), on: Color.rgb(0x191a21)),
    accent: SurfaceTone(color: Color.rgb(0xffb86c), on: Color.rgb(0x191a21)),
    error: SurfaceTone(color: Color.rgb(0xff5555), on: Color.rgb(0x191a21)),
    warning: SurfaceTone(color: Color.rgb(0xf1fa8c), on: Color.rgb(0x191a21)),
    success: SurfaceTone(color: Color.rgb(0x50fa7b), on: Color.rgb(0x191a21)),
    background: SurfaceTone(color: Color.rgb(0x191a21), on: Color.rgb(0xf8f8f2)),
    surface: SurfaceTone(color: Color.rgb(0x282a36), on: Color.rgb(0xf8f8f2)),
    border: Tone(color: Color.rgb(0x424555)),
    muted: Tone(color: Color.rgb(0x7f90c4)),
    disabled: Tone(color: Color.rgb(0x6f7287)),
    selection: SurfaceTone(color: Color.rgb(0x44475a), on: Color.rgb(0xf8f8f2)),
    // Follows the pattern documented on [dark]'s table. Purple primary is
    // magenta and pink secondary is brightMagenta; orange accent takes
    // brightRed, the orange stand-in.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.magenta, on: Color.black),
      secondary: SurfaceTone(color: Color.brightMagenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// Solarized Dark - Ethan Schoonover's low-contrast palette on a deep
  /// teal-black base.
  ///
  /// Every color but muted and disabled is a Solarized entry. The accents carry the intents (blue
  /// primary, violet secondary, magenta accent, red, yellow, green);
  /// each takes `base03` or `base3` as its text, whichever reads
  /// better on it. The neutral ladder is `base03` ground, `base02` surface,
  /// `base01` border and selection, then `base00`, `base0`, and `base1` as
  /// disabled, muted, and default text, so the three text ranks stay
  /// apart. Muted and disabled are lightened slightly until they read on both
  /// grounds (`deriveTheme`).
  static const Theme solarized = Theme(
    name: 'Solarized Dark',
    primary: SurfaceTone(color: Color.rgb(0x268bd2), on: Color.rgb(0x002b36)),
    secondary: SurfaceTone(color: Color.rgb(0x6c71c4), on: Color.rgb(0xfdf6e3)),
    accent: SurfaceTone(color: Color.rgb(0xd33682), on: Color.rgb(0xfdf6e3)),
    error: SurfaceTone(color: Color.rgb(0xdc322f), on: Color.rgb(0xfdf6e3)),
    warning: SurfaceTone(color: Color.rgb(0xb58900), on: Color.rgb(0x002b36)),
    success: SurfaceTone(color: Color.rgb(0x859900), on: Color.rgb(0x002b36)),
    background: SurfaceTone(color: Color.rgb(0x002b36), on: Color.rgb(0x93a1a1)),
    surface: SurfaceTone(color: Color.rgb(0x073642), on: Color.rgb(0x93a1a1)),
    border: Tone(color: Color.rgb(0x586e75)),
    muted: Tone(color: Color.rgb(0x8a9c9e)),
    disabled: Tone(color: Color.rgb(0x687e86)),
    selection: SurfaceTone(color: Color.rgb(0x586e75), on: Color.rgb(0xfdf6e3)),
    // Follows the pattern documented on [dark]'s table. Violet secondary is
    // magenta and the magenta accent is brightMagenta; blue primary and the
    // gray selection share plain blue — an accepted collapse.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.blue, on: Color.white),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.brightMagenta, on: Color.black),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
    ),
  );

  /// A theme that sits on the terminal's own background.
  ///
  /// Pass the color the startup probe found (`InitMsg.backgroundColor`). The
  /// result keeps [dark]'s hues and moves each text and intent color in
  /// lightness until it reads at 4.5:1 on both the background and the surface.
  /// The surface is the background shifted one [step], lighter on a dark
  /// background and darker on a light one. The selection keeps [dark]'s hue and
  /// sits two steps from the background. Then the result goes through
  /// [deriveTheme], so `border`, `muted` and `disabled` read too.
  ///
  /// A `null` [background], from a terminal that never answered, gives [dark].
  /// The report of the final derivation is dropped; call [deriveTheme] on the
  /// result to read it. The theme carries no [tones16], so the ANSI-16 tier
  /// derives one.
  static Theme system(Color? background) => deriveSystemTheme(background);

  /// Creates a copy of this theme with the given tones replaced.
  ///
  /// The copy keeps this theme's [name] unless [name] is passed.
  ///
  /// The ANSI-16 table follows the tones. When a tone changes and no
  /// [tones16] is passed, the copy carries no table, so the
  /// resolver derives one from the new tones ([Ansi16Tones.derive]). Pass
  /// [tones16] to keep a hand-authored table in control. A copy that changes
  /// no tone keeps this theme's table.
  Theme copyWith({
    String? name,
    SurfaceTone? primary,
    SurfaceTone? secondary,
    SurfaceTone? accent,
    SurfaceTone? error,
    SurfaceTone? warning,
    SurfaceTone? success,
    SurfaceTone? background,
    SurfaceTone? surface,
    Tone? border,
    Tone? muted,
    Tone? disabled,
    SurfaceTone? selection,
    Ansi16Tones? tones16,
    double? deEmphasis,
  }) {
    final tonesChanged = [
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
      selection,
    ].any((tone) => tone != null);
    return Theme(
      name: name ?? this.name,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      disabled: disabled ?? this.disabled,
      selection: selection ?? this.selection,
      tones16: tones16 ?? (tonesChanged ? null : this.tones16),
      deEmphasis: deEmphasis ?? this.deEmphasis,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Theme &&
        other.name == name &&
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
        other.selection == selection &&
        other.tones16 == tones16 &&
        other.deEmphasis == deEmphasis;
  }

  @override
  int get hashCode => Object.hash(
    name,
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
    selection,
    tones16,
    deEmphasis,
  );
}
