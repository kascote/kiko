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
/// widget states, so this set stays frozen while widgets grow freely.
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
  /// When not set explicitly it is derived as a subtle lift of [background]
  /// (10%), keeping [background]'s text color as its `on`. Keeps that `on`
  /// and carries no color when [background] has none (terminal-default
  /// themes).
  @override
  SurfaceTone get cursor {
    final explicit = _cursor;
    if (explicit != null) return explicit;
    final base = background.color;
    if (base == null) return SurfaceTone(on: background.on);
    return SurfaceTone(color: base.lift(0.10), on: background.on);
  }

  /// The fraction a hovered background lifts by, shared by the derived
  /// [hover] tone and the resolver's hover transform.
  static const double hoverLift = 0.08;

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

  /// Kiko Light theme - warm white base with deeper accents.
  static const Theme light = Theme(
    primary: SurfaceTone(color: Color.rgb(0x1a7f8e), on: Color.rgb(0xf6f8fa)),
    secondary: SurfaceTone(color: Color.rgb(0x6b5ba8), on: Color.rgb(0xf6f8fa)),
    accent: SurfaceTone(color: Color.rgb(0xb87a4a), on: Color.rgb(0xf6f8fa)),
    error: SurfaceTone(color: Color.rgb(0xb54343), on: Color.rgb(0xf6f8fa)),
    warning: SurfaceTone(color: Color.rgb(0xa68830), on: Color.rgb(0xf6f8fa)),
    success: SurfaceTone(color: Color.rgb(0x3d8b48), on: Color.rgb(0xf6f8fa)),
    background: SurfaceTone(color: Color.rgb(0xf6f8fa), on: Color.rgb(0x1f2328)),
    surface: SurfaceTone(color: Color.rgb(0xeef1f5), on: Color.rgb(0x1f2328)),
    border: Tone(color: Color.rgb(0xd0d7de)),
    muted: Tone(color: Color.rgb(0x8b949e)),
    disabled: Tone(color: Color.rgb(0xafb8c1)),
    focus: SurfaceTone(color: Color.rgb(0x2a8a9a), on: Color.rgb(0xf6f8fa)),
    selection: SurfaceTone(color: Color.rgb(0xddf4ff), on: Color.rgb(0x1f2328)),
    // Named ANSI colors paint on the user's own terminal background, so a
    // light theme cannot force a light terminal here — this table just
    // stays coherent with the theme's own intent (a white base, dark text).
    // Muted text needs to stay readable against that white base, so it
    // takes the darker of the two grays even though border and disabled
    // (mere chrome, not text) take the lighter one — the opposite ordering
    // from a dark theme, where dim text needs the lighter gray.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.cyan, on: Color.black),
      secondary: SurfaceTone(color: Color.blue, on: Color.white),
      accent: SurfaceTone(color: Color.brightRed, on: Color.white),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.white, on: Color.black),
      surface: SurfaceTone(color: Color.white, on: Color.black),
      border: Tone(color: Color.gray),
      muted: Tone(color: Color.darkGray),
      disabled: Tone(color: Color.gray),
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.blue, on: Color.white),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// Ember theme - warm orange palette with teal accents on near-black base.
  ///
  /// Uses complementary color theory: orange primary with teal accent.
  /// Warm-tinted intents (coral error, olive success) maintain cohesion.
  static const Theme ember = Theme(
    primary: SurfaceTone(color: Color.rgb(0xe07830), on: Color.rgb(0x0a0908)),
    secondary: SurfaceTone(color: Color.rgb(0xa85545), on: Color.rgb(0x0a0908)),
    accent: SurfaceTone(color: Color.rgb(0x45a5a5), on: Color.rgb(0x0a0908)),
    error: SurfaceTone(color: Color.rgb(0xcc5555), on: Color.rgb(0x0a0908)),
    warning: SurfaceTone(color: Color.rgb(0xd5a030), on: Color.rgb(0x0a0908)),
    success: SurfaceTone(color: Color.rgb(0x88a540), on: Color.rgb(0x0a0908)),
    background: SurfaceTone(color: Color.rgb(0x0a0908), on: Color.rgb(0xcdc0b4)),
    surface: SurfaceTone(color: Color.rgb(0x16120f), on: Color.rgb(0xcdc0b4)),
    border: Tone(color: Color.rgb(0x2a2420)),
    muted: Tone(color: Color.rgb(0x6a6055)),
    disabled: Tone(color: Color.rgb(0x4a4540)),
    focus: SurfaceTone(color: Color.rgb(0x55c5c5), on: Color.rgb(0x0a0908)),
    selection: SurfaceTone(color: Color.rgb(0x1a3535), on: Color.rgb(0xcdc0b4)),
    // Primary and secondary are both warm reds in RGB, so the vivid one
    // (primary) takes the bright slot and the quieter one (secondary)
    // shares plain red with error — an accepted collapse, since staying
    // distinct from error only matters for the interaction tones below.
    // Accent keeps its complementary teal identity as plain cyan, leaving
    // brightCyan free for focus.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.brightRed, on: Color.white),
      secondary: SurfaceTone(color: Color.red, on: Color.white),
      accent: SurfaceTone(color: Color.cyan, on: Color.black),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.cyan, on: Color.black),
      cursor: SurfaceTone(color: Color.brightBlue, on: Color.white),
    ),
  );

  /// ANSI-16 dark theme for basic terminal compatibility.
  static const Theme ansiDark = Theme(
    primary: SurfaceTone(color: Color.cyan, on: Color.black),
    secondary: SurfaceTone(color: Color.magenta, on: Color.black),
    accent: SurfaceTone(color: Color.yellow, on: Color.black),
    error: SurfaceTone(color: Color.red, on: Color.white),
    warning: SurfaceTone(color: Color.yellow, on: Color.black),
    success: SurfaceTone(color: Color.green, on: Color.black),
    background: SurfaceTone(color: Color.black, on: Color.white),
    surface: SurfaceTone(color: Color.darkGray, on: Color.white),
    border: Tone(color: Color.gray),
    muted: Tone(color: Color.darkGray),
    disabled: Tone(color: Color.darkGray),
    focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
    selection: SurfaceTone(color: Color.yellow, on: Color.black),
    // Already authored in named ANSI colors, so this table just restates
    // this theme's own tones — including the cursor tint, which this theme
    // leaves to derive as a lift of its black background (comes out as
    // darkGray with the background's own white `on`).
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.cyan, on: Color.black),
      secondary: SurfaceTone(color: Color.magenta, on: Color.black),
      accent: SurfaceTone(color: Color.yellow, on: Color.black),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.gray),
      muted: Tone(color: Color.darkGray),
      disabled: Tone(color: Color.darkGray),
      focus: SurfaceTone(color: Color.brightCyan, on: Color.black),
      selection: SurfaceTone(color: Color.yellow, on: Color.black),
      cursor: SurfaceTone(color: Color.darkGray, on: Color.white),
    ),
  );

  /// Lantern theme - monochrome amber on a dark warm-brown base, like text
  /// lit by lamplight.
  ///
  /// The signature is that *default* text is amber rather than gray-white:
  /// everything on screen sits on one warm hue, with brightness carrying the
  /// hierarchy — muted text is a darker amber, focus is a brighter one, and
  /// the only departures from the hue are the intent tones (error, success).
  static const Theme lantern = Theme(
    primary: SurfaceTone(color: Color.rgb(0x008080), on: Color.rgb(0x221a10)), // 0xc8933f
    secondary: SurfaceTone(color: Color.rgb(0xb3854d), on: Color.rgb(0x221a10)),
    accent: SurfaceTone(color: Color.rgb(0xf5d9a0), on: Color.rgb(0x221a10)),
    error: SurfaceTone(color: Color.rgb(0xd06048), on: Color.rgb(0x221a10)),
    warning: SurfaceTone(color: Color.rgb(0xe0b040), on: Color.rgb(0x221a10)),
    success: SurfaceTone(color: Color.rgb(0x9aa548), on: Color.rgb(0x221a10)),
    background: SurfaceTone(color: Color.rgb(0x14100B), on: Color.rgb(0xcaa356)),
    surface: SurfaceTone(color: Color.rgb(0x2a2113), on: Color.rgb(0xcaa356)),
    border: Tone(color: Color.rgb(0x3a2e1e)),
    muted: Tone(color: Color.rgb(0x4A3F30)),
    disabled: Tone(color: Color.rgb(0x57492a)),
    focus: SurfaceTone(color: Color.rgb(0xffb63d), on: Color.rgb(0x221a10)),
    selection: SurfaceTone(color: Color.rgb(0x4a3a1e), on: Color.rgb(0xf2d9a5)),
    // cursor, hover: derived washes over background.
    //
    // Nearly every tone lives in the yellow family, so this table leans on
    // the accepted collapses: primary, warning and selection share plain
    // yellow, accent and focus share brightYellow (focus also picks up bold
    // from the resolver's state matrix). Secondary drops to red alongside
    // error — the quieter warm hue — and the grays follow the dark-theme
    // ordering.
    tones16: Ansi16Tones(
      primary: SurfaceTone(color: Color.yellow, on: Color.black),
      secondary: SurfaceTone(color: Color.red, on: Color.white),
      accent: SurfaceTone(color: Color.brightYellow, on: Color.black),
      error: SurfaceTone(color: Color.red, on: Color.white),
      warning: SurfaceTone(color: Color.yellow, on: Color.black),
      success: SurfaceTone(color: Color.green, on: Color.black),
      background: SurfaceTone(color: Color.black, on: Color.white),
      surface: SurfaceTone(color: Color.darkGray, on: Color.white),
      border: Tone(color: Color.darkGray),
      muted: Tone(color: Color.gray),
      disabled: Tone(color: Color.darkGray),
      focus: SurfaceTone(color: Color.brightYellow, on: Color.black),
      selection: SurfaceTone(color: Color.yellow, on: Color.black),
      cursor: SurfaceTone(color: Color.darkGray, on: Color.white),
    ),
  );

  /// Creates a copy of this theme with the given tones replaced.
  ///
  /// Passing `null` for [cursor] or [hover] keeps this theme's current
  /// value (explicit or derived); to override them, pass a tone. Passing
  /// `null` for [tones16] likewise keeps this theme's current table.
  Theme copyWith({
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
  }) => Theme(
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
    tones16: tones16 ?? this.tones16,
    cursor: cursor ?? _cursor,
    hover: hover ?? _hover,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Theme &&
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
