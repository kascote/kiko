import 'package:meta/meta.dart';

import 'ansi16_tones.dart';
import 'colors.dart';
import 'tone.dart';

/// A theme is a small, fixed set of [Tone]s — color identities the whole app
/// shares.
///
/// A theme owns *which* colors exist, never how they land as paint: every tone
/// becomes cells only through a projection ([Tone.ink] / [SurfaceTone.fill] /
/// [Tone.wash]), usually via `StyleResolver`. Nothing else belongs on a theme —
/// per-widget parts are anatomy (widget style slots) and interaction facts are
/// widget states, so this set stays frozen while widgets grow freely. The one
/// non-tone member is [name], the label a theme picker shows.
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
/// Interaction — how the current interaction looks:
/// - [focus]: keyboard "you are here"
/// - [selection]: the chosen items
/// - [cursor]: the current row/column tint (derived from [background] by default)
/// - [hover]: the mouse-over tint (derived from [background] by default)
///
/// ## The ANSI-16 tier
///
/// A theme is authored once, in RGB. On a plain 16-color terminal the
/// resolver does not downsample that RGB — it re-expresses each tone through
/// [tones16], a named ANSI-16 pair, so a theme keeps its meaning (error is
/// still red, selection is still blue) instead of drifting toward whatever
/// RGB happens to be nearest. [tones16] is optional: a theme without a
/// hand-authored table gets one derived automatically ([Ansi16Tones.derive]).
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

  /// Keyboard focus indicator ("you are here").
  @override
  final SurfaceTone focus;

  /// Chosen items (selected rows, picked options).
  @override
  final SurfaceTone selection;

  /// Hand-authored ANSI-16 re-expression of this theme's tones.
  ///
  /// Leave `null` to have the resolver derive one automatically
  /// ([Ansi16Tones.derive]) and cache it — most themes need nothing here.
  final Ansi16Tones? tones16;

  final SurfaceTone? _cursor;
  final Tone? _hover;

  /// Creates a theme from its tones.
  ///
  /// [cursor] and [hover] are optional: when omitted they are derived from
  /// [background] as subtle washes (see [cursor] and [hover]). Themes built on
  /// the terminal's default background (`background.color == null`) cannot
  /// derive a wash and should pass [cursor]/[hover] explicitly.
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
    required this.focus,
    required this.selection,
    this.tones16,
    SurfaceTone? cursor,
    Tone? hover,
  }) : _cursor = cursor,
       _hover = hover;

  /// The current row/column tint.
  ///
  /// When not set explicitly it is derived from [background] by
  /// [deriveCursor]. Keeps [background]'s text color as its `on` and
  /// carries no color when [background] has none (terminal-default themes).
  @override
  SurfaceTone get cursor => _cursor ?? deriveCursor(background);

  /// Derives a cursor tone from a surface tone, when one is not set
  /// explicitly.
  ///
  /// Lifts [background]'s color by 10% and keeps its `on`; carries no color
  /// when [background] has none. [Theme.cursor] and [Ansi16Tones.cursor]
  /// both call this, so a theme and its ANSI-16 table derive a missing
  /// cursor by the same rule.
  static SurfaceTone deriveCursor(SurfaceTone background) {
    final base = background.color;
    if (base == null) return SurfaceTone(on: background.on);
    return SurfaceTone(color: base.lift(0.10), on: background.on);
  }

  /// The fraction a hovered background lifts by, shared by the derived
  /// [hover] tone and the resolver's hover transform.
  static const double hoverLift = 0.08;

  /// The fraction a background lifts by when a state lands on a base that
  /// already has one.
  ///
  /// `StyleResolver` lifts a colored base by this much for
  /// `WidgetState.cursor` and `WidgetState.focused`; [hoverLift] is hover's
  /// own, smaller step on top.
  static const double stateLift = 0.16;

  /// The fraction a disabled fill's `fg` and `bg` move toward the ground
  /// color.
  ///
  /// `StyleResolver` blends with this under `RenderPolicy.color` only, when
  /// the base already carries a background and [background] has a color.
  static const double disabledMix = 0.5;

  /// The mouse-over tint.
  ///
  /// When not set explicitly it is derived as a fainter lift of [background]
  /// (8%). Derives to an empty tone when [background] has no color.
  Tone get hover {
    final explicit = _hover;
    if (explicit != null) return explicit;
    final base = background.color;
    if (base == null) return const Tone();
    return Tone(color: base.lift(hoverLift));
  }

  /// Whether [cursor] is derived from [background] rather than set explicitly.
  bool get derivesCursor => _cursor == null;

  /// Whether [hover] is derived from [background] rather than set explicitly.
  bool get derivesHover => _hover == null;

  /// Kiko Dark theme - deep slate base with muted warm accents.
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
    border: Tone(color: Color.rgb(0x30363d)),
    muted: Tone(color: Color.rgb(0x6e7681)),
    disabled: Tone(color: Color.rgb(0x484f58)),
    focus: SurfaceTone(color: Color.rgb(0x6bc5d2), on: Color.rgb(0x0d1117)),
    selection: SurfaceTone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9)),
    // cursor, hover: derived washes over background.
    //
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
    // - bright variants are the spare headroom: spend them on selection,
    //   cursor, focus and error once a hue family is already used
    //   elsewhere, so those four stay visually distinct from one another.
    //   Cursor and focus also pick up bold from the resolver's state
    //   matrix, which helps them stand out further.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
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
    focus: SurfaceTone(color: Color.rgb(0x89dceb), on: Color.rgb(0x11111b)),
    selection: SurfaceTone(color: Color.rgb(0x585b70), on: Color.rgb(0xcdd6f4)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table. Blue primary and the
    // gray selection both land on plain blue — an accepted collapse, since
    // only the four interaction tones need to stay apart. Sky focus takes
    // brightCyan; peach accent takes brightRed, the orange stand-in.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Rosé Pine - the main (darkest) variant: muted rose, gold, and teal on a
  /// deep violet-black base.
  ///
  /// Every color is a Rosé Pine palette entry, placed by the palette's own
  /// role guide: `love` for errors, `gold` for warnings, `pine` as the
  /// green, `subtle` and `muted` for the two text ranks, `highlightMed` for
  /// selection, `highlightHigh` for borders. The palette has six hues for
  /// seven slots, so [focus] shares `foam` with [primary]; the resolver's
  /// bold and state lift keep a focused element apart from a resting one.
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
    focus: SurfaceTone(color: Color.rgb(0x9ccfd8), on: Color.rgb(0x191724)),
    selection: SurfaceTone(color: Color.rgb(0x403d52), on: Color.rgb(0xe0def4)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table, with the palette's
    // own terminal mapping: foam is cyan, iris is magenta, rose is
    // brightMagenta, love is red, gold is yellow, pine is green. Focus takes
    // brightCyan so it stays apart from the plain-cyan primary here even
    // though the two share one RGB color.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Gruvbox dark - retro-groove pastels on a warm dark-gray base.
  ///
  /// Every color is a Gruvbox dark-mode palette entry. The bright variants
  /// carry the intents (orange primary, blue secondary, purple accent, red,
  /// yellow, green, aqua focus) with the hard-contrast `bg0_h` as their
  /// text; the neutrals climb `bg0_h` → `bg0` → `bg2` → `bg3`, with `bg0_h`
  /// as the ground and `bg0` as the raised surface, and the two text ranks
  /// are `gray` and `bg4`.
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
    muted: Tone(color: Color.rgb(0x928374)),
    disabled: Tone(color: Color.rgb(0x7c6f64)),
    focus: SurfaceTone(color: Color.rgb(0x8ec07c), on: Color.rgb(0x1d2021)),
    selection: SurfaceTone(color: Color.rgb(0x665c54), on: Color.rgb(0xfbf1c7)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table. Orange primary takes
    // brightRed, the orange stand-in, leaving plain red for error; blue
    // secondary and the gray selection share plain blue — an accepted
    // collapse, since only the four interaction tones need to stay apart.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Monokai Pro - the default (dark) filter: vivid accents on a muted
  /// plum-gray base.
  ///
  /// Every color is a Monokai Pro palette entry. The six accents carry the
  /// intents (blue primary, purple secondary, orange accent, red, yellow,
  /// green) with the base background as their text; `dark1` is the raised
  /// surface, and the `dimmed` ramp supplies border, selection, and the two
  /// text ranks. The palette has six hues for seven slots, so [focus]
  /// shares blue with [primary]; the resolver's bold and state lift keep a
  /// focused element apart from a resting one.
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
    border: Tone(color: Color.rgb(0x403e41)),
    muted: Tone(color: Color.rgb(0x939293)),
    disabled: Tone(color: Color.rgb(0x727072)),
    focus: SurfaceTone(color: Color.rgb(0x78dce8), on: Color.rgb(0x2d2a2e)),
    selection: SurfaceTone(color: Color.rgb(0x5b595c), on: Color.rgb(0xfcfcfa)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table. Focus takes
    // brightCyan so it stays apart from the plain-cyan primary here even
    // though the two share one RGB color; orange accent takes brightRed,
    // the orange stand-in.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Nord - arctic, bluish pastels on a dark blue-gray base.
  ///
  /// Every color is a Nord palette entry, placed by the palette's own role
  /// guide: Polar Night `nord0` → `nord1` → `nord2` → `nord3` for ground,
  /// surface, border, and selection; Snow Storm `nord4` as text; Frost
  /// `nord8` and `nord9` as primary and focus; Aurora for the intents. Nord
  /// has no mid gray, so muted text takes `nord3` brightened
  /// (`#616e88`, the comment color of the palette's own Vim port) and
  /// disabled text takes `nord3` itself, which also fills selection. Error
  /// takes `nord6` as its text; `nord0` reads too faintly on `nord11`.
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
    border: Tone(color: Color.rgb(0x434c5e)),
    muted: Tone(color: Color.rgb(0x616e88)),
    disabled: Tone(color: Color.rgb(0x4c566a)),
    focus: SurfaceTone(color: Color.rgb(0x81a1c1), on: Color.rgb(0x2e3440)),
    selection: SurfaceTone(color: Color.rgb(0x4c566a), on: Color.rgb(0xeceff4)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table. Frost primary is
    // cyan; blue focus takes brightCyan rather than blue so it stays apart
    // from the blue selection; orange accent takes brightRed, the orange
    // stand-in.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Tokyo Night - the night variant: neon-tinted pastels on a deep
  /// blue-black base.
  ///
  /// Every color is a Tokyo Night palette entry. The seven hues carry the
  /// intents (blue primary, magenta secondary, orange accent, red, yellow,
  /// green, cyan focus) with the darkest background as their text; the
  /// ground is `bg_dark1`, the raised surface is `bg`, `fg_gutter` is the
  /// border, `blue7` fills selection, and `dark5` and `comment` are the
  /// two text ranks.
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
    muted: Tone(color: Color.rgb(0x737aa2)),
    disabled: Tone(color: Color.rgb(0x565f89)),
    focus: SurfaceTone(color: Color.rgb(0x7dcfff), on: Color.rgb(0x0c0e14)),
    selection: SurfaceTone(color: Color.rgb(0x394b70), on: Color.rgb(0xc0caf5)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table. Blue primary and
    // the blue-tinted selection share plain blue — an accepted collapse,
    // since only the four interaction tones need to stay apart. Orange
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// One Dark - Atom's default: soft syntax hues on a cool charcoal base.
  ///
  /// Every color is an Atom One Dark entry. The syntax hues carry the
  /// intents (blue primary, purple secondary, orange accent, red, yellow,
  /// green) and the UI accent color is focus, all with the darkest UI
  /// level as their text; the ground is that darkest level, the raised
  /// surface is the editor background, the selection color is both border
  /// and selection, and the three `mono` grays are the text ranks.
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
    border: Tone(color: Color.rgb(0x3e4451)),
    muted: Tone(color: Color.rgb(0x828997)),
    disabled: Tone(color: Color.rgb(0x5c6370)),
    focus: SurfaceTone(color: Color.rgb(0x528bff), on: Color.rgb(0x21252b)),
    selection: SurfaceTone(color: Color.rgb(0x3e4451), on: Color.rgb(0xabb2bf)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table. Blue primary and
    // the gray selection share plain blue — an accepted collapse, since
    // only the four interaction tones need to stay apart. Focus takes
    // brightCyan rather than a second blue so it stays apart from both.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Dracula - vivid candy hues on a dark purple-gray base.
  ///
  /// Every color is a Dracula palette entry. The seven hues carry the
  /// intents (purple primary, pink secondary, orange accent, red, yellow,
  /// green, cyan focus) with the darkest background as their text; the
  /// ground is that darkest background, the raised surface is the editor
  /// background, `comment` is muted text, and the selection color is both
  /// disabled text and the selection fill, since the palette has no gray
  /// between the two.
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
    border: Tone(color: Color.rgb(0x343746)),
    muted: Tone(color: Color.rgb(0x6272a4)),
    disabled: Tone(color: Color.rgb(0x44475a)),
    focus: SurfaceTone(color: Color.rgb(0x8be9fd), on: Color.rgb(0x191a21)),
    selection: SurfaceTone(color: Color.rgb(0x44475a), on: Color.rgb(0xf8f8f2)),
    // cursor, hover: derived washes over background.
    //
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Solarized Dark - Ethan Schoonover's low-contrast palette on a deep
  /// teal-black base.
  ///
  /// Every color is a Solarized entry. The accents carry the intents (blue
  /// primary, violet secondary, magenta accent, red, yellow, green, cyan
  /// focus); each takes `base03` or `base3` as its text, whichever reads
  /// better on it. The neutral ladder is `base03` ground, `base02` surface,
  /// `base01` border and selection, then `base00`, `base0`, and `base1` as
  /// disabled, muted, and default text, so the three text ranks stay
  /// apart.
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
    muted: Tone(color: Color.rgb(0x839496)),
    disabled: Tone(color: Color.rgb(0x657b83)),
    focus: SurfaceTone(color: Color.rgb(0x2aa198), on: Color.rgb(0x002b36)),
    selection: SurfaceTone(color: Color.rgb(0x586e75), on: Color.rgb(0xfdf6e3)),
    // cursor, hover: derived washes over background.
    //
    // Follows the pattern documented on [dark]'s table. Violet secondary is
    // magenta and the magenta accent is brightMagenta; blue primary and the
    // gray selection share plain blue — an accepted collapse, since only
    // the four interaction tones need to stay apart.
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
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Creates a copy of this theme with the given tones replaced.
  ///
  /// The copy keeps this theme's [name] unless [name] is passed. Passing `null` for [cursor] or [hover] keeps this theme's current
  /// value (explicit or derived); to override them, pass a tone.
  ///
  /// The ANSI-16 table follows the tones. When a tone other than [hover]
  /// changes and no [tones16] is passed, the copy carries no table, so the
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
    SurfaceTone? focus,
    SurfaceTone? selection,
    Ansi16Tones? tones16,
    SurfaceTone? cursor,
    Tone? hover,
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
      focus,
      selection,
      cursor,
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
      focus: focus ?? this.focus,
      selection: selection ?? this.selection,
      tones16: tones16 ?? (tonesChanged ? null : this.tones16),
      cursor: cursor ?? _cursor,
      hover: hover ?? _hover,
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
        other.focus == focus &&
        other.selection == selection &&
        other.tones16 == tones16 &&
        other._cursor == _cursor &&
        other._hover == _hover;
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
    focus,
    selection,
    tones16,
    _cursor,
    _hover,
  );
}
