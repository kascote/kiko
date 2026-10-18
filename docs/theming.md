# Theming: the model, the recipe, and widget anatomy

How kiko styles widgets. The model in one line: **states pick tones, parts
pick projections**. A theme owns about a dozen color identities (tones). A
widget owns its named parts (anatomy). The resolver turns "which state,
which part" into paint. A themed widget never paints a raw color directly.

## The model

Every styled cell on screen answers four questions:

```
1. WHICH color family?        → Tone        (the theme owns these)
2. WHICH tone right now?      → WidgetState (interaction picks the tone)
3. HOW does it land as paint? → Projection  (ink / fill / wash / ground)
4. WHO can override it?       → Anatomy     (per-widget style slots, per instance)
```

- A **tone** is a color identity. A plain `Tone` paints as ink or wash; a
  `SurfaceTone` adds a readable foreground and can also fill or ground an
  area. Neither is paintable directly: each becomes a `Style` only through
  a projection. The compiler rejects a raw tone where a `Style` is
  expected, and rejects a fill or a ground of a plain `Tone`, so a fill's
  background can never land on border glyphs by accident.
- A **projection** turns a tone into a `Style`: `ink` (foreground only),
  `fill` (`fg: on, bg: color`), `wash` (background only), or `ground` (the
  pair an area's cells hold before content paints on them).
- **States pick tones; parts pick projections.** The `error` state paints
  a border and a row with the same tone through different projections
  (`ink` vs `fill`). `focused`, `cursor`, `hover` and `pressed` pick no
  tone: each lifts the ground a part sits on.
- **Anatomy slots** let a widget publish its parts as nullable style slots.
  A `null` slot derives from the theme by a documented rule. A non-null
  slot is the caller's exact style and wins verbatim.

Where a new styling knob goes:

> If every widget could have it, it is a **state**. If only this widget has
> it, it is **anatomy**. If it is a color identity the whole app shares, it
> is a **tone**. Nothing else is ever added to `Theme`.

`Theme` stays frozen at about a dozen tones. Widgets grow freely without
touching kiko_core.

## Tones

```dart
/// A color identity. Not paintable: project it with .ink / .wash.
@immutable
class Tone {
  final Color? color; // the identity color (nullable: terminal-default themes)

  const Tone({this.color});

  Style get ink  => Style(fg: color);
  Style get wash => Style(bg: color);
}

/// Adds a readable foreground, so it can also fill or ground an area.
class SurfaceTone extends Tone {
  final Color on; // a color readable on top of `color`

  const SurfaceTone({required this.on, super.color});

  Style get fill => Style(fg: on, bg: color);
}
```

`tone.color` stays public on both classes; `tone.on` only exists on a
`SurfaceTone`. Projections cover the common cases; the raw fields allow
custom derivations.

The tone set:

| Kind    | Group       | Tone         | `color` is…                   | `on` is…               |
| ------- | ----------- | ------------ | ----------------------------- | ---------------------- |
| surface | Intent      | `primary`    | brand / main action           | text on a primary fill |
| surface |             | `secondary`  | second-rank action            | 〃                     |
| surface |             | `accent`     | attention, badges             | 〃                     |
| surface |             | `error`      | destructive / invalid         | 〃                     |
| surface |             | `warning`    | caution                       | 〃                     |
| surface |             | `success`    | confirmation                  | 〃                     |
| surface | Neutral     | `background` | the app base color            | **default text**       |
| surface |             | `surface`    | elevated panels, dialogs      | text on surface        |
| chrome  |             | `border`     | resting chrome                | none                   |
| chrome  |             | `muted`      | secondary text                | none                   |
| chrome  |             | `disabled`   | non-interactive               | none                   |
| surface | Interaction | `selection`  | chosen items                  | text on selection      |

A surface tone is a `SurfaceTone`; `on` is the foreground that reads on it.
A chrome tone is a plain `Tone` and carries no `on`. The compiler rejects a
fill or a ground of a chrome tone, as it rejects a raw tone as a style.

`selection` means chosen items. Search-match styling is widget anatomy, not
a tone.

Focus, cursor, hover and pressed are not tones. Each is a state layer: the
resolver moves a background away from the ground a part sits on (see
"States"). `lighten` is a public `Color` method for ANSI-16 colors only: it
returns the bright variant. `Color.shiftLightness` is the lightness step
below. Themes, anatomy slots, and apps can use both for their own
derivations.

`Color.toOklab()` converts a color to `Oklab`, a perceptual space whose
lightness `l` runs from 0 (black) to 1 (white). Equal steps in `l` look
equal in size on every ground, which equal sRGB steps do not.
`Color.shiftLightness(delta)` moves `l` by `delta` and keeps hue and chroma.
It clamps `l` to 0..1. When the result leaves the sRGB gamut,
`Oklab.toColor()` lowers the chroma until the color fits. ANSI, indexed and
reset colors convert through their RGB value first, and the result is
always RGB.

`ToneSet` holds the tones that reach paint on every tier. `Theme` and
`Ansi16Tones` both implement it.

### A theme is just tones

```dart
static const dark = Theme(
  name:       'Kiko Dark',
  primary:    SurfaceTone(color: Color.rgb(0x58a6b0), on: Color.rgb(0x0d1117)),
  background: SurfaceTone(color: Color.rgb(0x0d1117), on: Color.rgb(0xc9d1d9)),
  surface:    SurfaceTone(color: Color.rgb(0x161b22), on: Color.rgb(0xc9d1d9)),
  border:     Tone(color: Color.rgb(0x343a41)),
  muted:      Tone(color: Color.rgb(0x7b838e)),
  selection:  SurfaceTone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9)),
  ...
);
```

`name` is the one member that is not a tone. It is the label a theme
picker or a status line shows, so a list of themes needs no parallel list
of names.

A theme always carries a background color. The app paints the whole frame
with it, and the `StyleResolver` constructor asserts that the color is set.

Two numbers ride on the theme besides the tones. `Theme.step` (0.12) is one
state step, a distance in OKLab lightness. `Theme.deEmphasis` (0.45) is how
far a de-emphasised part moves toward its ground. See "States" and
"De-emphasis".

### Shipped themes

Every shipped theme is a dark theme. The palette themes take their colors
from their source palette, and each takes the palette's darkest variant
and darkest background. The three neutral rungs `border`, `muted` and
`disabled` are palette grays moved in lightness where the palette's own gray
failed its target (see "Deriving a theme"). Each doc comment in
`packages/kiko_core/lib/src/theme.dart` records how the palette's roles map
onto the tones.

| Theme        | Intent                                                                  |
| ------------ | ----------------------------------------------------------------------- |
| `dark`       | Kiko's own: deep slate base with muted warm accents.                    |
| `catppuccin` | Catppuccin Mocha: soft pastel accents on a cool near-black base.        |
| `rosePine`   | Rosé Pine main: muted rose, gold, and teal on a deep violet-black base. |
| `gruvbox`    | Gruvbox dark: retro-groove pastels on a warm dark-gray base.            |
| `monokai`    | Monokai Pro default filter: vivid accents on a muted plum-gray base.    |
| `nord`       | Nord: arctic, bluish pastels on a dark blue-gray base.                  |
| `tokyoNight` | Tokyo Night, night variant: neon-tinted pastels on a deep blue-black base. |
| `oneDark`    | One Dark, Atom's default: soft syntax hues on a cool charcoal base.     |
| `dracula`    | Dracula: vivid candy hues on a dark purple-gray base.                   |
| `solarized`  | Solarized Dark: low-contrast accents on a deep teal-black base.         |

## Authoring a theme

A theme has two kinds of tones. The intent tones are hues: `primary`,
`error` and the rest each carry a color of their own.
The neutral tones are rungs on one ladder from the background to the text:
only brightness separates them, so their spacing decides whether the app
reads. Space the ladder in this order, darkest first on a dark theme:

    background < surface < border < disabled < muted < text

`text` is `background.on`. `selection` is a fill, not a rung. It must stay
apart from `background` and from `surface`, because a selected row lifts
from the selection color by one step under the cursor.

Check each rung against `background` and against `surface` with
`Color.contrastRatio`. The targets are constants on `ContrastTargets`:

| rung                | target                                                |
| ------------------- | ----------------------------------------------------- |
| `muted`             | at least 4.5:1, it is text                            |
| `disabled`          | at least 3:1 before the resolver adds dim             |
| `surface`           | visibly apart from `background`                       |
| `border`            | at least 1.5:1                                        |

Each rung must meet its target on both grounds. Chrome lands on both: a
dialog draws its border on `surface`, a pane draws it on `background`. A
border that only reads on one of them vanishes on the other.

A monochrome theme has one hue, so brightness is the only separator. Author
it the way the derived ANSI-16 table does: collapse tones on purpose, and
lean on the matrix modifiers (bold, dim, reversed) to keep the states
distinct.

A palette theme takes its role colors from the palette as they are. The
palette's grays can still miss a rung target; `deriveTheme` fixes those.
The contrast page of the theme viewer
(`packages/kiko_widgets/example/theme_viewer`, F4) prints every rung's ratio
and is the check for a new theme.

Page 4, "States", shows every migrated widget forced into each state, once on
the window and once on a surface panel. It is the acceptance check for a
widget's look.

### Deriving a theme

`deriveTheme(theme)` returns a record `(Theme, DerivationReport)`. Call it
on a theme you build. The framework never calls it for you.

The derived theme keeps every role color as published: the grounds, the
text, the intents and the selection. It recomputes only `border`, `muted`
and `disabled`, and only a rung that misses its target on `background` or on
`surface`. The new color keeps the rung's hue and chroma. Its OKLab
lightness moves away from `background`, in steps of 0.005, until the rung
meets the target on both grounds. When black or white is reached first, the
rung keeps the best color found, and the report shows the ratio it reached.
A theme whose rungs all pass comes back equal to the input, so
`deriveTheme` applied twice gives the same theme as applied once.

A role color that fails a check is reported and never changed. A palette
owns its role colors. The checks are:

- each role's `on` against its own color, at 4.5:1 (`primary`, `secondary`,
  `accent`, `error`, `warning`, `success`, `selection`);
- each intent color as ink against `background`, `surface` and `selection`,
  at 3:1.

`DerivationReport` has two lists. `changes` holds one `RungChange` per
replaced rung: its name, the old and new color, the grounds that failed and
the ratios before and after. `leftAlone` holds one `KeptFailure` per failing
role check: its name, the check, the ratio and the target. `hasChanges` says
whether any rung changed. `toString()` prints both lists, one line each.

Every shipped theme is stored already derived: `deriveTheme` returns it
unchanged with an empty `changes` list. Its `leftAlone` list is not empty for
most themes, because the palettes publish role colors such as a red that
reads weakly on the selection fill.

### The system theme

`Theme.system(background)` builds a theme on the terminal's own background.
Pass it `InitMsg.backgroundColor`, the color the startup probe found
(`docs/backend.md`). Build it in the `InitMsg` case of `update`.

The result starts from `Theme.dark`'s hues. The probed color is the
background. The surface is the background moved one `Theme.step` in lightness:
lighter on a dark background, darker on a light one. The text and each
intent color move in lightness until they read at 4.5:1 on both grounds. The
`on` of each intent is whichever of the background and the text reads better
on it. The selection keeps `Theme.dark`'s hue and sits two steps from the
background. Then `deriveTheme` fixes the three rungs. `Theme.system` drops
that report; call `deriveTheme` on the result to read it.

A system theme is not a chosen palette, so its intent colors may move far
from `Theme.dark`'s. Its ANSI-16 table derives from these colors like any other.
A `null` background, from a terminal that never answered, gives `Theme.dark`.

## Projections

| Projection | Produces            | Use for                                                       |
| ---------- | ------------------- | -------------------------------------------------------------- |
| `ink`      | `fg` only           | line glyphs, separators, scrollbars, accent text              |
| `fill`     | `fg: on, bg: color` | filled surfaces: selected rows, button faces, badges          |
| `wash`     | `bg` only           | tints under existing content: a crosshair row/column          |
| `ground`   | `fg: on, bg: color` | the style an area's cells hold before content paints on them  |

`wash` is the one to remember. It changes the background only, so a cell
keeps whatever foreground it already had. A custom `render` that colored a
number red stays red under the wash. `Style.patch` makes this work: a
bg-only style patched over content changes the background and nothing else.

### Grounding an area

A **ground** is the surface tone an area sits on: `background` for the
window, `surface` for a dialog or a popup. The `ground` projection turns it
into the **ground style**, the pair of colors the area's cells hold before
content paints on them. Set the ground style once per area. Paint content on
top with a half-null `Style`; the unset half inherits the ground style
already in the cell.

The style a cell ends up with is a chain, four links long: the ground
style, then a widget's slot or state style, then a line's own style, then a
span's style. Each link patches the one before it, so a null half always
falls through to what the link below already holds. A widget hands its
slot or state style to `paintLine` as `base`, or, where it builds the line
itself, patches the line's own style over that base with `Line.over`. It
never patches a slot or a state onto content — content always patches
last, so a line or a span keeps its own color through every state.

`Cell.setCell` and `Cell.setStyle` patch a cell instead of replacing it, so
a null half falls through to the ground underneath. `Buffer.operator []=`
replaces the whole cell instead, so a raw `Cell` written that way inherits
nothing.

A ground style is a full pair: whoever establishes a background also
establishes the text color that reads on it. The app grounds the frame with one line
at the top of `view`:

```dart
frame.ground(resolver.ground(resolver.tones.background));
```

A pane that changes ground re-grounds locally. A dialog or a popup paints
the `surface` ground style behind its own content, the same way. Styles for
parts on that ground come from a resolver bound to it:

```dart
final inDialog = resolver.on(resolver.tones.surface);
```

Every lift, blend and tint that resolver computes starts from `surface`,
where the window resolver starts from `background`. A row in a dialog sits
the same lightness step from its ground as a row on the window. Read the
tone from `resolver.tones`, so it matches the render policy. The ground
must carry a color. `on` keeps the de-emphasis of the resolver it is called
on.

Every shipped view takes a `StyleResolver`, not a `Theme`, and paints
through it as given. The app builds one resolver per render function and
passes it down. A pane that sits on another ground passes its own bound
resolver to its views. The combobox popup does this itself with
`resolver.on(resolver.tones.surface)`. `modalDialog` does it through its
content builder (see "De-emphasis").

The clean slate these rules assume is per **layer** — a render pass with
its own buffer (`docs/glossary.md`). The base pass is simply the first
layer: `Terminal.swapBuffers` resets its buffer before every frame. An
overlay rendered through `Frame.renderLayer` paints into its own empty
buffer and composites opaquely onto the frame over its rect. A cell a
layer never paints composites as `Cell.empty()` — the terminal's default
ground — under every render policy.

`null` in a style means inherit the ground style already in the cell. `Color.reset`
or `Style.reset` means the terminal's own default color — not the theme's
ground, and not "no color".

In full RGB, the `ground` projection gives the same pair as `fill`. The
two part ways in how they degrade: under `RenderPolicy.ansi16` the ground
style keeps only its foreground, `fg: tone.on`, so the terminal's own
background shows through; under `RenderPolicy.noColor` it carries no color
at all. A **fill** replaces the ground style for emphasis and reverses
under `RenderPolicy.noColor` to stay visible. A ground style never reverses
the screen, at any tier — it is the base the rest of the frame paints on,
not something meant to stand out.

### Why a tone is not paintable

`theme.selection` describes a fill: `on` text on the selection color. A
selected row wants exactly that. Border glyphs do not: a fill painted onto
a border floods every border cell's background, and the border becomes a
solid colored frame around the pane. The two call sites look identical in
code, so a paintable token invites the mistake. A tone does not type-check
where a `Style` is expected; the author must pick `.ink` or `.fill`, and
the projection documents the choice.

### Borders

A derived border style never carries a background. Pass
`resolver.border(...)` or an `.ink` projection to `Container.borderStyle`.
An explicit `Style(fg: …, bg: …)` handed to a border is a deliberate design
choice and always allowed — a filled dialog frame, a status strip.
`Container` takes a plain, unrestricted `Style`; theme-awareness lives one
level up, in the resolver.

## States

```dart
enum WidgetState {
  hover,      // the mouse is over it — mouse only, never keyboard
  selected,   // it is in the chosen set
  cursor,     // it is the current item (keyboard cursor position)
  focused,    // the widget owns keyboard input
  pressed,    // a pointer is held down on it — mouse only
  loading,    // async in flight
  error,      // invalid / failed
  disabled,   // non-interactive — ends the chain, hover and pressed do nothing
}
```

The enum order is not the order states apply. Each active state adds a
**state layer**: that state's contribution to the result. `resolve` applies
the layers in one fixed order, for every paint class:

1. Roles: `selected`, `loading`, `error`. Each patches onto the base in
   turn, so a later role replaces the color of an earlier one.
2. `focused`.
3. `cursor`.
4. `disabled`. It ends the chain: `hover` and `pressed` do nothing once it
   is active.
5. `hover`.
6. `pressed`.
7. De-emphasis, on a resolver from `deEmphasised` (see below).

A **lift** moves a background one OKLab lightness step away from the
ground. A ground with lightness below 0.5 lightens the background; a
lighter ground darkens it. Every lift goes the same way, so hover on top of
a cursor reads as a further step. `Theme.step` (0.12) is one step.
`focused` and `cursor` lift one step, `hover` half a step, and `pressed`
one step on top of hover. A part with no background of its own — `bg` is
null or `Color.reset` — lifts the ground color instead.

The ground is the one the resolver is bound to (see "Grounding an area").
A step is a lightness distance from that ground, so a state moves a row the
same distance on `surface` as on `background`.

A lift keeps two facts on one cell. A selected row under the cursor keeps
the selection color, one step lighter or darker, instead of the cursor
hiding it.

A fill that is both `focused` and `cursor` lifts once, not twice. `focused`
brings the step and the bold; `cursor` adds nothing more. A view therefore
marks its cursor row `{cursor, focused}` while it owns keyboard focus and
`{cursor}` otherwise. The unfocused cursor row lifts the ground one step
with no bold, in the same `resolve` call.

The ink class has no background to lift. `focused` in the ink class patches
the `primary` ink plus bold, unless a role already set the ink; an error
ink still wins over focus on chrome, and keeps the bold. `cursor` and
`hover` do nothing in the ink class.

Under full color, `disabled` blends both `fg` and `bg` of a filled base
toward the ground by `Theme.disabledMix` and adds dim, keeping the pair.
Moving one half of an authored pair would break its contrast; moving both
toward one target scales the contrast down evenly. The exception is a
background that marks a position: under `cursor` or `focused`, `disabled`
blends the ink alone and leaves the lifted background at its full contrast.
Position is a navigation fact and disabled is an item fact, so the row the
user stands on never fades into the ground. A base with a background and no
foreground — a cursor wash — is the same case: it takes the disabled ink
and keeps the wash, so a disabled row shows one ink with or without the
cursor on it. Under a plainer tier, `disabled` keeps the pair and adds dim
alone. On a bare base `disabled` swaps in the disabled ink and adds dim.

**Use honest states.** The keyboard-current item is `WidgetState.cursor`,
never `focused` or `hover`. `focused` means the widget owns keyboard input.
`hover` means the mouse is over the widget; the keyboard never sets it.
`pressed` means a pointer is held down on the widget, mouse only, same as
`hover`. Keyboard position and mouse hover are different facts. They can
coexist and deserve different looks: hover as a faint wash under the
pointer, cursor as the bar you move with arrows.

**`disabled` is a behavior fact.** A widget produces it when its model has
input to refuse. A disabled widget consumes a press and a bound key
without acting on either. An unbound key still declines, and the widget
reports no terminal cursor.

**`error` is a model fact; where it lands follows the chrome rule.** A
widget lands it on chrome it owns, the same way it lands `focused`. A
widget with no chrome of its own paints nothing for it; a border the
caller composes around the widget reads the fact from the model instead.

The table below is the contract: which states each shipped widget
produces, and which part of it each state lands on.

| widget    | produces                                            | lands on                                                                                                             |
| --------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Button    | focused, hover, pressed, loading, disabled           | the face, every state                                                                                                                    |
| Checkbox  | focused, hover, pressed, error, disabled, selected    | focused/disabled: brackets and mark; error: brackets; selected: checked mark; disabled: label and row too; hover and pressed: the row ground |
| RadioGroup | focused, hover, pressed, error, disabled, selected  | focused: the cursor option's brackets and mark; error: every option's brackets; disabled: the option's row, or every row; selected: the chosen mark; hover and pressed: one row's ground |
| TextInput | focused, error, disabled                             | focused: the text (ink + bold), and the composed border; error: no part of its own, the composed border reads it; disabled: text, placeholder, fill, obscured |
| TextArea  | focused, error, disabled                             | as TextInput; disabled also dims the gutter and the selection                                                                            |
| Combobox  | focused, hover, error, disabled                      | focused/hover/error: the toggle; disabled: field and toggle                                                                              |
| ListView  | selected, cursor, disabled (per item), hover          | the row                                                                                                                                   |
| TableView | selected, cursor, hover                              | cursor: row and column wash, cell fill; the rest: the row                                                                                |
| TreeView  | cursor, loading, hover                               | loading: the indicator glyph; the rest: the row                                                                                          |

A state not in a widget's row is not produced by that widget. A state a
widget holds but lands on no part of its own is painted by the chrome the
caller composes, from the widget's field.

## The resolver

`StyleResolver` maps `(state, paint class)` to paint through a built-in
matrix. The state picks the tone; the caller passes the part's class. A
resolver is bound to one ground and computes every lift, blend and tint from
it.

```dart
enum PaintClass { ink, fill, wash }

class StyleResolver {
  /// Bound to the theme's background; adopts StyleResolver.defaultPolicy.
  StyleResolver(Theme theme, {RenderPolicy? policy});

  /// The same resolver bound to [ground]. Keeps the de-emphasis.
  StyleResolver on(SurfaceTone ground);

  /// The same resolver with de-emphasis on. Keeps the ground.
  StyleResolver get deEmphasised;

  /// Resolves [base] under [states] for one paint class. [slots] carries a
  /// widget's own per-state style, keyed by state.
  Style resolve(
    Style? base,
    Set<WidgetState> states, {
    required PaintClass cls,
    Map<WidgetState, Style> slots = const {},
  });

  /// Border style for a set of states.
  Style border(Set<WidgetState> states);

  /// Tone projections under the active policy. Read the tone from [tones].
  Style ink(Tone tone);
  Style fill(SurfaceTone tone);
  Style wash(Tone tone);
  Style ground(SurfaceTone tone);

  /// The active tone set: the theme itself, or its ANSI-16 table under
  /// RenderPolicy.ansi16.
  final ToneSet tones;

  /// The ground this resolver's parts sit on.
  final SurfaceTone groundTone;
}
```

`border` resolves the resting border tone as ink.
`resolver.border({if (m.focused) WidgetState.focused})` replaces a
hand-written `m.focused ? focusInk : restingInk` at every call site.

With a null `base`, the fill class starts from the background of the bound
ground's ground style, with no foreground: the text color stays the area's.
The ink and wash classes start from an empty style. With no states,
`resolve` returns that start unchanged. A part that starts with no
foreground takes the `disabled` ink when it is disabled, so a disabled row
reads in the theme's `disabled` tone with or without the cursor on it.

`slots` lets a widget hand in its own per-state style for one state — a
cursor-row slot, say. A slot replaces that state's layer: `resolve` patches
the slot style onto the result and adds nothing else for the state, no
lift, no bold, no dim. A slot for `disabled` still ends the chain. A slot
for a state that is not active does nothing.

A raw projection (`theme.success.fill`) bypasses the render policy: it
paints RGB on every terminal. App content that paints tones directly — a
title in `primary`, a status badge in `success` — should read the tone
from `resolver.tones` and project it with `resolver.ink` / `fill` / `wash`
instead, so it degrades with the rest of the screen.

### The state × class matrix

This table is the built-in look of kiko. It is the single place where "what
does selected mean on a border" is decided. An em-dash means the state does
not affect that class; modifiers ride on top of the projection.

| state       | tone        | `ink` (chrome/text)       | `fill` (surfaces)                    | `wash` (tints)                 |
| ----------- | ----------- | ------------------------- | ------------------------------------ | ------------------------------- |
| `selected`  | `selection` | `primary.ink`             | `selection.fill`                     | `selection.wash`                |
| `loading`   | `warning`   | `warning.ink` + slowBlink | 〃                                   | —                               |
| `error`     | `error`     | `error.ink`               | `error.fill`                         | `error.wash`                    |
| `focused`   | `primary`   | `primary.ink` + bold      | lift one step + bold                 | —                               |
| `cursor`    | —           | —                         | lift one step                        | lift one step                   |
| `disabled`  | `disabled`  | `disabled.ink` + dim      | blend + dim, or `disabled.ink` + dim on bare | —                       |
| `hover`     | —           | —                         | lift half a step                     | lift half a step                |
| `pressed`   | —           | —                         | lift one more step                   | lift one more step              |

The rows follow the order `resolve` applies them. A dash in the tone column
means the state picks no tone: it lifts the ground a part sits on instead.

Colors are the theme's. The modifiers in this matrix, and `Theme.step`,
belong to the matrix instead: a theme picks which color `primary` or
`disabled` means, never whether `focused` also carries bold. A theme
without that bold would lose the one thing a state still shows once
`NO_COLOR` strips the color away. A theme that needs different modifiers
is a different matrix, not a theme.

Selected chrome — a pane border, a tab underline, a checked mark — is
`primary` ink, plain. Focused chrome is `primary` ink plus bold. One hue
serves both; weight tells a moment (focus) from a fact (selection). The
`selection` color paints fills only, because as ink it is too faint to read.

`selected`, `loading` and `error` patch onto the base exactly as the table
shows. The other states move the result: the table shows what each
produces, a lift or a blend, not a literal patch. A lift of `focused` and
`cursor` is one step, so a fill that has both lifts once. Under `NO_COLOR`
nothing lifts: `cursor` adds bold in the fill class, and `pressed` flips
the `reversed` modifier. Nothing in
the matrix inverts the foreground and background.

Reading examples:

- A selected pane border is `selected` × `ink`: `primary` ink, no
  background, no bold.
- A focused button is `focused` × `fill`: it lifts the face's own
  background one step and keeps its pair, plus bold.
- A button held down is `pressed` × `fill`: it lifts the face one step. On a
  hovered button the hover half step comes first, so the face sits one step
  past hover.
- A selected row under the cursor is `selected` × `fill` then `cursor` ×
  `fill`: the cursor lifts the selection color one step instead of
  replacing it.
- A focused cursor row is `{cursor, focused}` × `fill`: one lift and bold.
  An unfocused one is `{cursor}` × `fill`: one lift, no bold.
- A disabled selected row is `selected` × `fill` then `disabled` × `fill`:
  disabled blends the selection's `fg` and `bg` toward the ground and adds
  dim, keeping the pair readable.
- A disabled row under the cursor is `cursor` × `fill` then `disabled` ×
  `fill`: disabled blends the ink alone, so the cursor bar keeps its
  contrast against the ground and the row stays findable.
- An error input's border is `error` × `ink`; its text keeps the base
  style. The matrix only patches what a state owns.

### De-emphasis

A pane that is present but not the one in use — the host behind a dialog,
an inactive tab — looks one step quieter and stays readable. Such a pane
builds its styles from `resolver.deEmphasised` and passes it to its views:

```dart
final quiet = resolver.deEmphasised;
```

A widget knows nothing about it. De-emphasis is never a `WidgetState`,
because the model does not refuse input.

Every projection of a de-emphasised resolver — `ink`, `fill`, `wash`,
`ground` and `border` — is quieter. Under full color each projection blends
its `fg` and `bg` toward the ground by `Theme.deEmphasis` (0.45). A half
that is null or `Color.reset` stays as it is. A lift shrinks by the same
share, so a state on a quiet part stays quiet. A slot style is blended
before `resolve` patches it. Under ANSI-16 and `NO_COLOR` every projection
and every `resolve` result adds dim.

`resolve` does not blend its `base`. Build the base from the same
de-emphasised resolver's projections, so every color is blended once. A raw
`Style` passed as `base` stays as bright as it is.

`deEmphasised` keeps the ground, and `on` keeps the de-emphasis, so the two
compose in either order.

The modal is the pane that does both. `modalDialog` takes the app's resolver
and a content builder. It calls the builder with the resolver bound to
`surface`, so the widgets in the dialog lift from the dialog's ground.
`renderModalOverlay` takes a builder for the host. It calls that builder with
`resolver.deEmphasised` while a dialog is open and with `resolver` otherwise:

```dart
final dialog = switch (model.modal) {
  final modal? => modalDialog(
    id: modal.id,
    resolver: resolver,
    content: (surface) => Column(
      children: [
        Line('Add 10 to the counter?'),
        Line('Enter confirms', style: surface.ink(surface.tones.muted)),
      ],
    ),
  ),
  null => null,
};

renderModalOverlay(
  frame,
  base: (host) => Container(
    border: BorderType.rounded,
    borderStyle: host.border(const {}),
    child: Button(model: model.okButton, resolver: host),
  ).build(),
  resolver: resolver,
  width: 40,
  height: 7,
  dialog: dialog,
  id: model.modal?.id,
);
```

Build every widget and every chrome style of the host from the builder's
resolver. A style built from the app's resolver stays at full strength behind
the dialog.

### Where each tone lands

The matrix reads state → tone. This table reads the other way: for each
tone, where the shipped widgets paint it. Use it to predict what a tone
change touches. App code can project any tone anywhere; this lists only
what the library itself does.

| Tone         | The library paints it on…                             |
| ------------ | ----------------------------------------------------- |
| `primary`    | a button's resting face (`primary.fill`); focused and selected chrome as ink |
| `secondary`  | nothing — app content only                            |
| `accent`     | nothing — app content only; the app's "look here" color |
| `error`      | error-state chrome and text; failed-load rows         |
| `warning`    | loading-state chrome, blinking                        |
| `success`    | nothing — app content only                            |
| `background` | the app base; `background.on` is the default text     |
| `surface`    | popups and dialogs                                    |
| `border`     | every resting border                                  |
| `muted`      | placeholders, secondary text                          |
| `disabled`   | disabled items and chrome, dim                        |
| `selection`  | selected items as fill                                |

The sparse intent rows are the rule, not a gap. The intent tones are the
app's vocabulary: titles, badges, links, status messages. The library
paints an intent tone only where a state itself carries intent (`error`,
`loading` → `warning`), or where the widget is one — a button is a primary
action, so its resting face is `primary.fill`.

## Theming a widget

The recipe, step by step.

### 1. Classify each part as ink, fill, wash, or ground

List every part of your widget and write down its projection, using the
projection table above. That list is the spec for the next two steps.

### 2. Define an `XStyle` anatomy class

Publish the parts as a class of nullable `Style?` slots. `null` means
"derive from the theme by a documented rule". Non-null is the caller's
exact style and wins verbatim. Copy `TableViewStyle`
(`table_view/types.dart`) as the template. The derivation table goes in the
doc comment and is the widget's styling contract:

```dart
/// FooView's anatomy: one nullable style slot per part.
///
/// A `null` slot is derived from the theme's tones by the rule below; a
/// non-null slot is the caller's exact style and wins verbatim.
///
/// | slot          | derived default              | matrix source     |
/// | ------------- | ---------------------------- | ----------------- |
/// | `item`        | none (inherits)              | —                 |
/// | `selectedItem`| `resolver.fill(selection)`   | selected × fill   |
/// | `cursorItem`  | the ground, one step lifted  | cursor × fill     |
/// | `placeholder` | `resolver.ink(muted)`        | anatomy-specific  |
class FooViewStyle {
  final Style? item;
  final Style? selectedItem;
  final Style? cursorItem;
  final Style? placeholder;
  const FooViewStyle({this.item, this.selectedItem, this.cursorItem, this.placeholder});
}
```

A model never holds a resolved `Style`. Take `style` as a view parameter
(default `const FooViewStyle()`), the way `ListView` and `TableView` do. The
view is rebuilt every frame, so the app builds the look there from the
resolver it holds at that moment; a slot can never go stale after a theme
switch. A fixed definition a model holds — one set once, at construction,
like `TableColumn` — carries a function of the resolver instead, resolved
at paint; see `TableColumn.style`.

Give a slot only to a part you actually paint. ListView has no `indicator`
slot: its `itemBuilder` owns every glyph, so the slot would style nothing.
TreeView has one: its default node builder paints the glyph and reads the
slot, and a custom `nodeBuilder` paints its own row and ignores it. Do not
duplicate a part that already has a home.

### 3. Resolve states through the resolver, with the right class

Hand the resolver the part's own base style. A background the part already
carries lifts under `cursor` or `focused` instead of being replaced, which
is why a selected row keeps its pair under the cursor. A part with no style
of its own passes `null`: the fill class then starts from the bound
ground's background, and the ink and wash classes start empty.

The view paints through the `resolver` its caller passed in.

```dart
var itemStyle = style.item ?? const Style();
itemStyle = resolver.resolve(
  itemStyle,
  {
    if (isSelected) WidgetState.selected,
    if (isCursor) WidgetState.cursor,
    if (isCursor && viewHasFocus) WidgetState.focused,
    if (isDisabled) WidgetState.disabled,
    if (isHover) WidgetState.hover,
  },
  cls: PaintClass.fill,
  slots: {
    if (style.selectedItem != null) WidgetState.selected: style.selectedItem!,
    if (style.cursorItem != null) WidgetState.cursor: style.cursorItem!,
  },
);
```

`cls` is required: the part picks the projection, so every call names its
class. Pass `cls: PaintClass.wash` for a tint and `cls: PaintClass.ink` for
chrome. `slots` carries the part's own anatomy styles, keyed by state: a
slot replaces that state's layer, so the state adds no lift, bold or dim of
its own.

One `resolve` call serves one part. The cursor row of a view that owns
keyboard focus passes `{cursor, focused}`: one lift and bold. The cursor row
of a view that does not passes `{cursor}`: one lift, no bold. The state set
changes; the call and the paint class stay the same. Use a second call only
when two parts of one row need different classes, such as a fill for the
row and ink for its border.

For borders, use the `border` helper:

```dart
borderStyle: resolver.border({if (model.focused) WidgetState.focused})
```

### 4. A per-instance look is a slot

A per-instance look is a slot value passed to that view. Build the style
from the resolver's projections, so it degrades under ANSI-16 and NO_COLOR
like any other style. A value-driven intent, such as a danger button or a
progress bar that reads as success, is a tone through a projection:

```dart
Button(
  model: model.delete,
  resolver: resolver,
  style: ButtonStyle(face: resolver.fill(resolver.tones.error)),
)
```

The theme is never varied per view. A slot is the one place a caller
replaces a part's look.

## Degradation: three tiers of color fidelity

A theme is authored once, in RGB, for every terminal. What changes from
tier to tier is not the theme but how the resolver turns a tone into paint.
The resolver carries a `RenderPolicy` and applies it inside every
projection call, so a widget never branches on the terminal it runs in:

- **`RenderPolicy.color`** — full RGB, as authored. On a 256-color terminal
  termkit downsamples each color to the nearest palette entry on the way
  out; the theme layer does nothing here.
- **`RenderPolicy.ansi16`** — a plain 16-color terminal. The resolver does
  not downsample here. A nearest-color search over sixteen slots would
  quietly lose the theme's intent, so each tone is re-expressed as a named
  ANSI-16 slot: `error` stays red-family, `selection` stays blue-family, and
  the terminal's own palette customization still reads correctly. No theme
  authors this table. `Ansi16Tones.derive` computes it from the theme's
  tones, once per theme, by hue family:
  - The intent tones and `selection` take the family whose OKLab hue angle
    is nearest. The families are red, yellow, green, cyan, blue and magenta.
    Each family's angle is the hue of its dark ANSI color. A tone lighter
    than `Ansi16Tones.brightLightness` takes the bright variant.
  - A tone whose OKLab chroma is under `Ansi16Tones.grayChroma` has no hue.
    It takes one of the four grays (black, dark gray, gray, white) by
    lightness. `selection` takes blue instead, because a gray selection
    would match the lifted ground that a cursor row paints.
  - The neutral tones (`background`, `surface`, `border`, `muted`,
    `disabled`) always take one of the four grays by lightness, whatever
    their chroma.
  - The `on` of a surface tone depends on its slot only. Black, red, blue,
    dark gray, bright red and bright blue take white. The other slots take
    black.
  - An ANSI color passes through unchanged and an indexed color converts
    through its RGB value.

  Tones that land on one slot stay on it. A lift at this tier always steps to the bright
  variant of the slot, whatever the ground: darkening a named slot can
  leave it unchanged, which would hide the step. A slot already at its
  bright variant stays there, so a second lift — hover on top of a state
  lift — collapses into the first instead of adding a further step. Hover
  and pressed lift the same way. A wash has no subtle tint to spend at this
  tier, so it drops entirely. De-emphasis adds dim. A ground style keeps
  only its foreground, so the terminal's own background shows through.
- **`RenderPolicy.noColor`** — color is off (NO_COLOR). Nothing lifts or
  blends at this tier: a base stays as it is, and bold, dim and reversed
  carry the states instead. `focused` adds bold, `pressed` toggles
  reversed, and de-emphasis adds dim. Meaning re-expresses through
  modifiers: `fill` becomes `Modifier.reversed`, `ink` keeps its modifiers
  with the color dropped, and `wash` becomes nothing — a crosshair
  collapses to its cursor cell. A ground style carries no color at all
  here, and — unlike `fill` — never reverses.

The staircase reads the same from richest to plainest: a fill is tint plus
fill in RGB, a real `(fg, bg)` pair from sixteen names at ANSI-16, and
reversed once color is off. A state that must stay distinguishable —
selected, focused, error, disabled — never goes invisible on the way down;
it spends a plainer signal at each step. Under `noColor` no background
moves, so a cursor fill shows as bold, focused or not. A cursor wash
shows nothing. An ink-only state with no modifier
(`selected` × `ink` on a border) also degrades to nothing under NO_COLOR.
That loss is accepted, because every such state stays visible through its
fill projection.

`Application` maps the terminal's color profile to a policy before the
first frame and sets it on `StyleResolver.defaultPolicy`. Every
`StyleResolver(theme)` an app builds adopts it automatically. Route every
style through the resolver and a selected row stays visible however far its
color is stripped.

## Picking a theme at startup

Choosing which `Theme` to render is a different question from the color
tier, and it is the app's call. Kiko never switches a theme on its own. The
startup capability probe reports the terminal's background color on
`InitMsg.backgroundColor` (mirrored on `Backend.backgroundColor`), or `null`
when the terminal never answered.

An app that wants its own look ignores the color and picks a theme, such as
`Theme.nord`. An app that wants the terminal's look reads the color once, in
`update` on the first `InitMsg`, and builds `Theme.system(msg.backgroundColor)`.
A `null` color gives `Theme.dark`. Every shipped theme is dark; an app that
wants a fixed light theme authors one (see "Authoring a theme" above).

## Which knob serves which user

| user                                  | touches                                                                  |
| ------------------------------------- | ------------------------------------------------------------------------ |
| "make it look right"                  | nothing — derived defaults                                               |
| "my colors everywhere"                | the tones of a `Theme`                                                   |
| "this table gets an orange crosshair" | `XStyle(...)` passed to the view                                         |
| "every table in my app is custom"     | a shared `const appTableStyle = TableViewStyle(…)`, passed to every view |
| "this column is green"                | `TableColumn.style`                                                      |
| "one row blinks on my signal"         | an item builder                                                          |
| "this button is red at rest"          | a `ButtonStyle(face: …)` slot on that view                               |
| "this pane is inactive"               | the pane passes `resolver.deEmphasised` to its views                     |
| "this dialog holds a form"            | the dialog passes `resolver.on(resolver.tones.surface)` to its views     |

A widget that serves all nine rows without the author fighting the
framework is themed correctly by construction.

## Shipped widget anatomies

The slot map for every widget that ships one — the reference to copy from
when adding a slot or theming a new widget. A `null` slot derives from the
theme by the rule below; a non-null slot is the caller's exact style and
wins verbatim. Each anatomy class carries its own rows of this table in its
doc comment; that copy is the widget's contract.

| Widget    | Slot              | Derived default                     | Matrix source    |
| --------- | ----------------- | ----------------------------------- | ---------------- |
| TableView | `header`          | inherit + bold                      | anatomy-specific |
|           | `row`             | none (inherits the pane's ground)   | —                |
|           | `separator`       | `resolver.ink(border)`              | resting chrome   |
|           | `selectedRow`     | `resolver.fill(selection)`          | selected × fill  |
|           | `cursorRow`       | the ground, one step lifted         | cursor × wash    |
|           | `cursorColumn`    | the ground, one step lifted         | cursor × wash    |
|           | `cursorCell`      | the ground, one step lifted         | cursor × fill    |
|           | `pending`         | `resolver.ink(muted)`               | anatomy-specific |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| ListView  | `item`            | none (starts from the bound ground) | —                |
|           | `selectedItem`    | `resolver.fill(selection)`          | selected × fill  |
|           | `cursorItem`      | the ground, one step lifted         | cursor × fill    |
|           | `pending`         | `resolver.ink(muted)`               | anatomy-specific |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| TreeView  | `item`            | none (inherits the pane's ground)   | —                |
|           | `cursorItem`      | the ground, one step lifted         | cursor × fill    |
|           | `indicator`       | none (inherits the row)             | loading × ink    |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| Combobox  | `toggle`          | inherit                             | focused × ink    |
|           | `popupGround`     | `resolver.ground(surface)`          | anatomy-specific |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| TextInput | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
|           | `fill`            | `resolver.ink(muted)`               | anatomy-specific |
|           | `obscured`        | none (inherits the base text style) | —                |
| TextArea  | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
|           | `selection`       | `resolver.fill(selection)`          | anatomy-specific |
|           | `lineNumber`      | `resolver.ink(muted)`               | anatomy-specific |
| Checkbox  | `open`            | `resolver.ink(border)`              | resting chrome   |
|           | `close`           | `resolver.ink(border)`              | resting chrome   |
|           | `mark`            | none (inherits the ground)          | —                |
|           | `checkedMark`     | `resolver.ink(primary)`             | selected × ink   |
|           | `label`           | none (inherits the ground)          | —                |
| RadioGroup | `open`           | `resolver.ink(border)`              | resting chrome   |
|            | `close`          | `resolver.ink(border)`              | resting chrome   |
|            | `mark`           | none (inherits the ground)          | —                |
|            | `checkedMark`    | `resolver.ink(primary)`             | selected × ink   |
|            | `label`          | none (inherits the ground)          | —                |

Notes the table cannot carry:

- **TableView** — the crosshair (`cursorColumn`) is enabled by
  `showCrosshair` on the view, not by slot presence: a slot styles a part,
  it does not create the behavior. A cell's base is `row`, patched by the
  column's own style (`TableColumn.style`, resolved at paint). The resolver
  then composes `selected` and, on the exact cursor cell of a focused
  table, `cursor` in the fill class — `selectedRow` and `cursorCell` ride
  in as slots. A cell on the cursor row, or on the crosshair column, that
  is not that focused cursor cell resolves `cursor` again in the wash
  class, through the `cursorRow` slot or the `cursorColumn` slot;
  `cursorRow` wins when a cell sits on both. The wash lifts a selected row
  instead of replacing it, so an unfocused table's cursor washes every row
  it crosses without ever entering the fill class. Hover resolves last, in
  its own fill call: a cell with a background lifts it, a bare cell takes
  the hover wash. The resolved style is the `base` the cell's content
  paints over, so the column's rendered line and its spans always patch
  last, over hover included. The exemplar — copy its shape.
- **ListView** — a row is one `resolve` call in the fill class over `item`.
  The call carries every state the row holds: `selected`, `cursor`,
  `disabled` and `hover`, plus `focused` on the cursor row while the list
  owns focus. A null `item` starts the row from the ground the resolver is
  bound to, so a list in a dialog or a popup lifts that pane's ground.
  An unfocused cursor row is one lift with no bold. `selectedItem` and
  `cursorItem` ride in as slots and replace their state's layer on any
  base. An error cell in a row reads on the selection fill because every
  intent ink is declared to read on `selection`.
- **TreeView** — the expand, collapse, and loading glyph is the
  `indicator` slot; the default node builder paints the glyph and reads
  it, and a custom `nodeBuilder` paints its own row and never sees it.
  A tree has no selection set, so no `selectedItem`.
- **Button** — one slot, `ButtonStyle.face`. A null face derives
  `resolver.fill(primary)`; states ride the matrix — `focused` lifts the
  face's background and adds bold, `loading` reads warning + blink,
  `disabled` blends the face toward the ground and dims it. A press lifts
  the face one step past hover through `WidgetState.pressed`.
- **TextInput / TextArea** — region styles are nullable slots on the
  view's `style`. A null region derives from the theme through the resolver:
  placeholder and fill (TextInput) or placeholder and lineNumber (TextArea)
  are muted ink; TextArea's selection is a selection fill. Base text has no
  color of its own; it inherits the ground it is painted on. The text takes
  the `primary` ink and bold when focused, resolved through the resolver rather
  than a slot; the border a caller composes around the field takes
  `focused` and `error` from the model's own fields.
- **Combobox** — the field styles through `ComboboxStyle.field` and the
  popup's match rows through `ComboboxStyle.list`; the popup border's ink
  styles through `ComboboxStyle.popupBorder` (`docs/combobox.md`).
- **Checkbox** — the row ground is one fill call over the bound ground. Hover
  lifts it half a step and pressed lifts it one more step. The lift covers
  the box, the gap, the label, and any spare cells, and no ink changes.
  Focused puts `primary` ink and bold on `open`, `close`, and whichever mark
  is showing. The checked mark resolves in one call with `selected`, so it
  is `primary` ink, plain. Focus adds bold to it. Error puts error ink on
  `open` and `close` only. Disabled fades every part and the row. A set
  `checkedMark` slot replaces the `selected` look, so it keeps its own color
  while focused, and focus still adds bold.
- **RadioGroup** — the group is one widget. Focus lands on one option, the
  option at the cursor. It never lands on a cursor bar. Error is a group
  fact. It paints on every option's brackets. On the cursor row, error ink
  wins over `primary` ink. The focus bold stays. A disabled option fades its
  own parts and its row. A disabled group fades every option. Hover lifts
  one option's row ground half a step, spare cells included, and pressed
  lifts it one more step. The chosen mark is `primary` ink, plain, and a
  set `checkedMark` slot keeps its own color, like the checkbox's.
  `labelAlign` has no visible effect in a horizontal group.

`ItemState` and `NodeState`, the records passed to item/node builders,
use `cursor` (not `focused`) for the current-item flag. `ItemState` carries
`selected`, `cursor`, `hover`, and `disabled`. `NodeState` carries `cursor`,
`hover`, `loading`, and `expanded`. `CellRenderContext`, passed to
`TableColumn.render`, carries `selected`, `cursorRow`, `cursorCell`, and
`hover` for the same four facts on a cell.
