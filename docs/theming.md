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
- **States pick tones; parts pick projections.** A selected pane border and
  a selected row use the same tone (`selection`) through different
  projections (`ink` vs `fill`).
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
| surface | Interaction | `focus`      | "you are here" (keyboard)     | text on a focus fill   |
| surface |             | `selection`  | chosen items                  | text on selection      |
| surface |             | `cursor`     | current row/col wash (subtle) | text on cursor cell    |
| chrome  |             | `hover`      | mouse-over wash (subtle)      | none                   |

A surface tone is a `SurfaceTone`; `on` is the foreground that reads on it.
A chrome tone is a plain `Tone` and carries no `on`. The compiler rejects a
fill or a ground of a chrome tone, as it rejects a raw tone as a style.

`selection` means chosen items. Search-match styling is widget anatomy, not
a tone.

`cursor` and `hover` are derived by default, so a theme author writes
thirteen tones, not fifteen. The defaults are lifts of the background:
`cursor` is `background.color.lift(Theme.stateLift)`, the same step a
state takes from any colored base, and `hover` is
`background.color.lift(Theme.hoverLift)`, half that step. `lift` lightens
on a dark theme and darkens on a light one. `lift`, `lighten`, and `darken` are public `Color` methods,
so themes, anatomy slots, and apps can do their own derivations. A theme
may set `cursor` and `hover` explicitly instead. An ANSI-16 table
(`Ansi16Tones`) derives a missing `cursor` from its own `background` by
the same rule.

`ToneSet` holds the tones that reach paint on every tier. `hover` only
washes, and a wash is empty under ANSI-16 and NO_COLOR, so `hover` lives
on `Theme` alone.

### A theme is just tones

```dart
static const dark = Theme(
  name:       'Kiko Dark',
  primary:    SurfaceTone(color: Color.rgb(0x58a6b0), on: Color.rgb(0x0d1117)),
  background: SurfaceTone(color: Color.rgb(0x0d1117), on: Color.rgb(0xc9d1d9)),
  surface:    SurfaceTone(color: Color.rgb(0x161b22), on: Color.rgb(0xc9d1d9)),
  border:     Tone(color: Color.rgb(0x30363d)),
  muted:      Tone(color: Color.rgb(0x6e7681)),
  focus:      SurfaceTone(color: Color.rgb(0x6bc5d2), on: Color.rgb(0x0d1117)),
  selection:  SurfaceTone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9)),
  // cursor, hover: omitted → derived washes over background
  ...
);
```

`name` is the one member that is not a tone. It is the label a theme
picker or a status line shows, so a list of themes needs no parallel list
of names.

**Transparent-background themes.** `background.color == null` keeps the
terminal's own background: fills over it set `bg: null`, and the frame's
ground carries only its foreground, `background.on`. Such a theme should
set `cursor` and `hover` explicitly. A wash cannot be derived from an
unknown background: `hover` comes out fully empty, and `cursor` keeps
`background`'s `on` but carries no color.

### Shipped themes

Every shipped theme is a dark theme. The palette themes use only colors
from their source palette, and each takes the palette's darkest variant
and darkest background; each doc comment in
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

A theme has two kinds of tones. The intent and interaction tones are hues:
`primary`, `focus`, `error` and the rest each carry a color of their own.
The neutral tones are rungs on one ladder from the background to the text:
only brightness separates them, so their spacing decides whether the app
reads. Space the ladder in this order, darkest first on a dark theme:

    background < hover < cursor < surface < border < disabled < muted < text

`text` is `background.on`. `selection` is a fill, not a rung; it must
separate from `cursor`, and from `cursor` over `selection`, since the
resolver lifts a selected row by one step under the cursor.

Check each rung against `background` with `Color.contrastRatio`:

| rung                | target                                                |
| ------------------- | ----------------------------------------------------- |
| `muted`             | at least 4.5:1, it is text                            |
| `disabled`          | at least 3:1 before the resolver adds dim             |
| `cursor`, `surface` | visibly apart from the ground; one `Theme.stateLift` is the floor |
| `border`            | readable on `background` and on `surface`             |

The `border` rule matters because chrome lands on both grounds: a dialog
draws its border on `surface`, a pane draws it on `background`. A border
that only reads on one of them vanishes on the other.

A monochrome theme has one hue, so brightness is the only separator. Author
it the way the ANSI-16 tables do: collapse tones on purpose, and lean on
the matrix modifiers (bold, dim, reversed) to keep `focus` and `loading`
distinct.

A palette theme takes its colors from the palette as they are, so a rung
can miss a target; that is the palette's choice, not a bug. The contrast
page of the theme viewer (`packages/kiko_widgets/example/theme_viewer`,
F4) prints every rung's ratio and is the check for a new theme.

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

A **ground** is the style an area's cells hold before content paints on
them. Set it once per area. Paint content on top with a half-null `Style`;
the unset half inherits the ground already in the cell.

The style a cell ends up with is a chain, four layers deep: the ground,
then a widget's slot or state style, then a line's own style, then a
span's style. Each layer patches the one before it, so a null half always
falls through to what the layer below already holds. A widget hands its
slot or state style to `paintLine` as `base`, or, where it builds the line
itself, patches the line's own style over that base with `Line.over`. It
never patches a slot or a state onto content — content always patches
last, so a line or a span keeps its own color through every state.

`Cell.setCell` and `Cell.setStyle` patch a cell instead of replacing it, so
a null half falls through to the ground underneath. `Buffer.operator []=`
replaces the whole cell instead, so a raw `Cell` written that way inherits
nothing.

A ground is a full pair: whoever establishes a background also establishes
the text color that reads on it. The app grounds the frame with one line
at the top of `view`:

```dart
frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));
```

A pane that changes surface re-grounds locally. A dialog or a popup paints
the `surface` ground behind its own content, the same way. A part that
sits on that surface takes the same ground as its base style, so a state
lifts the surface instead of patching a fill derived from `background`.
The combobox hands its popup ground to the embedded list as
`ListViewStyle.item` for this reason: the cursor fill the theme derives
from `background` barely reads on `surface`.

The clean slate these rules assume is per **layer** — a render pass with
its own buffer (`docs/glossary.md`). The base pass is simply the first
layer: `Terminal.swapBuffers` resets its buffer before every frame. An
overlay rendered through `Frame.renderLayer` paints into its own empty
buffer and composites opaquely onto the frame over its rect. A cell a
layer never paints composites as `Cell.empty()` — the terminal's default
ground — under every render policy.

`null` in a style means inherit the ground already in the cell. `Color.reset`
or `Style.reset` means the terminal's own default color — not the theme's
ground, and not "no color".

In full RGB, a ground is the same pair as a fill. The two part ways in how
they degrade: under `RenderPolicy.ansi16` a ground keeps only its
foreground, `fg: tone.on`, so the terminal's own background shows through;
under `RenderPolicy.noColor` a ground carries no color at all. A **fill**
replaces the ground for emphasis and reverses under `RenderPolicy.noColor`
to stay visible. A **ground** never reverses the screen, at any tier — it
is the base the rest of the frame paints on, not something meant to stand
out.

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

Declaration order sets the order states apply. `selected`, `loading` and
`error` patch onto the base first, each patch replacing the last. `cursor`,
`focused` and `disabled` transform the patched result next, in that order.
`hover` and `pressed` transform last.

`cursor` and `focused` lift a base that already carries a background,
instead of replacing it. On a bare base — `bg` is null or `Color.reset` —
each patches a fallback style instead: its fill in the fill class, its wash
in the wash class. A lift keeps two facts on one cell: a selected row under
the cursor keeps the selection color, one step brighter or darker, instead
of the cursor's own color hiding it.

A lift's direction follows the ground, not the color it lifts. The ground
is `tones.background.color`. A dark ground — luminance below 0.5, or no
color — lightens; a light ground darkens. A second lift then continues the
first instead of reversing it, so hover on top of a state lift always reads
as a further step. A state lifts by `Theme.stateLift`; hover lifts by
`Theme.hoverLift`, half a step. The derived `cursor` tone takes the same
`Theme.stateLift` from the background, so the cursor bar is one step
whether the row was bare or already selected.

The ink class is the exception: an ink has no background to lift, so
`focused` × `ink` patches the focus ink plus bold at its declaration
position, and an error ink still wins over it on chrome.

Under full color, when the ground has a color, `disabled` blends both `fg`
and `bg` of a filled base toward it by `Theme.disabledMix` and adds dim,
keeping the pair. Moving one half of an authored pair would break its
contrast; moving both toward one target scales the contrast down evenly.
The exception is a background that marks a position: under `cursor` or
`focused`, `disabled` blends the ink alone and leaves the lifted
background at its full contrast. Position is a navigation fact and
disabled is an item fact, so the row the user stands on never fades into
the ground. A base with a background and no foreground — the cursor wash
an unfocused list already applied — is the same case: it takes the
disabled ink and keeps the wash, so a disabled row shows one ink with or
without the cursor on it. Otherwise — under a plainer tier, or when the
ground has no color — `disabled` keeps the pair and adds dim alone. On a
bare base `disabled` swaps in the disabled ink and adds dim. Either way,
`disabled` ends the chain: `hover` and `pressed` do nothing once it is
active.

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
| Checkbox  | focused, hover, pressed, error, disabled, selected    | focused/pressed/disabled: brackets and mark; error: brackets; selected: checked mark; disabled: label too; hover: the row                |
| RadioGroup | focused, hover, pressed, error, disabled, selected  | focused: the cursor option's brackets and mark; error: every option's brackets; disabled: the option's row, or every row; selected: the chosen mark; hover: one row; pressed: one row's box |
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
matrix. The state picks the tone; the caller passes the part's class.

```dart
enum PaintClass { ink, fill, wash }

class StyleResolver {
  StyleResolver(this.theme); // adopts StyleResolver.defaultPolicy

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
}
```

`border` resolves the resting border tone as ink.
`resolver.border({if (m.focused) WidgetState.focused})` replaces the
hand-written `m.focused ? theme.focus : theme.border` at every call site.

`slots` lets a widget hand in its own per-state style for one state — a
cursor-row slot, say. A slot replaces the theme's contribution for that
state: the fallback a lift uses on a bare base, or the matrix cell for
`selected`, `loading` or `error`. It never replaces the style the call
composes, so a background the base itself carries still lifts under
`cursor` or `focused` even when a slot is set for that state.

A raw projection (`theme.success.fill`) bypasses the render policy: it
paints RGB on every terminal. App content that paints tones directly — a
title in `primary`, a status badge in `success` — should read the tone
from `resolver.tones` and project it with `resolver.ink` / `fill` / `wash`
instead, so it degrades with the rest of the screen.

### The state × class matrix

This table is the built-in look of kiko. It is the single place where "what
does selected mean on a border" is decided. An em-dash means the state does
not affect that class; modifiers ride on top of the projection.

| state       | tone        | `ink` (chrome/text)       | `fill` (surfaces)                             | `wash` (tints)                 |
| ----------- | ----------- | ------------------------- | ------------------------------------------------ | ------------------------------- |
| `selected`  | `selection` | `selection.ink`           | `selection.fill`                                  | `selection.wash`                |
| `cursor`    | `cursor`    | —                         | lift, or `cursor.fill` + bold on bare             | lift, or `cursor.wash` on bare   |
| `focused`   | `focus`     | `focus.ink` + bold        | lift, or `focus.fill` + bold on bare              | —                                |
| `loading`   | `warning`   | `warning.ink` + slowBlink | 〃                                                | —                                |
| `error`     | `error`     | `error.ink`               | `error.fill`                                      | `error.wash`                    |
| `disabled`  | `disabled`  | `disabled.ink` + dim      | blend + dim, or `disabled.ink` + dim on bare      | —                                |

Colors are the theme's. The modifiers in this matrix, and `Theme.hoverLift`,
belong to the matrix instead: a theme picks which color `focus` or
`disabled` means, never whether `focused` also carries bold. A theme
without that bold would lose the one thing a state still shows once
`NO_COLOR` strips the color away. A theme that needs different modifiers
is a different matrix, not a theme.

`selected`, `loading` and `error` patch onto the base exactly as the table
shows. `cursor`, `focused` and `disabled` transform the patched result
instead: the table shows what each produces, a lift or a blend, not a
literal patch. Hover transforms next, lifting a background by
`Theme.hoverLift` as a second step on top of any lift already there, or
washing a part that has none. Pressed transforms last, inverting the
result; under `NO_COLOR` it flips the `reversed` modifier instead.

Reading examples:

- A selected pane border is `selected` × `ink`: a foreground tint of the
  selection color, no background.
- A focused button is `focused` × `fill`: it lifts the face's own
  background one step and keeps its pair, plus bold.
- A selected row under the cursor is `selected` × `fill` then `cursor` ×
  `fill`: the cursor lifts the selection color a further step and adds
  bold, instead of replacing it.
- A disabled selected row is `selected` × `fill` then `disabled` × `fill`:
  disabled blends the selection's `fg` and `bg` toward the ground and adds
  dim, keeping the pair readable.
- A disabled row under the cursor is `cursor` × `fill` then `disabled` ×
  `fill`: disabled blends the ink alone, so the cursor bar keeps its
  contrast against the ground and the row stays findable.
- An error input's border is `error` × `ink`; its text keeps the base
  style. The matrix only patches what a state owns.

### Where each tone lands

The matrix reads state → tone. This table reads the other way: for each
tone, where the shipped widgets paint it. Use it to predict what a tone
change touches. App code can project any tone anywhere; this lists only
what the library itself does.

| Tone         | The library paints it on…                             |
| ------------ | ----------------------------------------------------- |
| `primary`    | a button's resting face (`primary.fill`) — nowhere else |
| `secondary`  | nothing — app content only                            |
| `accent`     | nothing — app content only                            |
| `error`      | error-state chrome and text; failed-load rows         |
| `warning`    | loading-state chrome, blinking                        |
| `success`    | nothing — app content only                            |
| `background` | the app base; `background.on` is the default text     |
| `surface`    | popups and dialogs                                    |
| `border`     | every resting border                                  |
| `muted`      | placeholders, secondary text                          |
| `disabled`   | disabled items and chrome, dim                        |
| `focus`      | focused borders and faces, bold                       |
| `selection`  | selected items as fill; a selected border as ink      |
| `cursor`     | the current row/column bar                            |
| `hover`      | the wash under the mouse on grounded content; a filled part lifts its own color instead |

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
/// | slot          | derived default             | matrix source     |
/// | ------------- | ---------------------------- | ----------------- |
/// | `item`        | none (inherits)              | —                 |
/// | `selectedItem`| `resolver.fill(selection)`   | selected × fill   |
/// | `cursorItem`  | `resolver.fill(cursor)` + bold | cursor × fill   |
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
theme it holds at that moment; a slot can never go stale after a theme
switch. A fixed definition a model holds — one set once, at construction,
like `TableColumn` — carries a function of the resolver instead, resolved
at paint; see `TableColumn.style`.

Give a slot only to a part you actually paint. ListView has no `indicator`
slot: its `itemBuilder` owns every glyph, so the slot would style nothing.
TreeView has one: its default node builder paints the glyph and reads the
slot, and a custom `nodeBuilder` paints its own row and ignores it. Do not
duplicate a part that already has a home.

### 3. Resolve states through the resolver, with the right class

Hand the resolver the part's own base style, not `null`. A background the
part already carries lifts under `cursor` or `focused` instead of being
replaced, which is why a selected row keeps its pair under the cursor:

```dart
late final _resolver = StyleResolver(theme);

var itemStyle = style.item ?? const Style();
itemStyle = _resolver.resolve(
  itemStyle,
  {
    if (isSelected) WidgetState.selected,
    if (isCursor) WidgetState.cursor,
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
slot replaces the theme's contribution for that state — the fallback a
lift uses on a bare base, or the matrix cell for `selected` — but never the
style the call composes.

A part that owns keyboard focus paints its cursor in the fill class; one
that does not paints it in the wash class, in its own `resolve` call.
Compose several calls when a part's states need different classes:
`selected` and `disabled` in one fill call, `cursor` in a wash call of its
own for a part that does not own focus.

For borders, use the `border` helper:

```dart
borderStyle: resolver.border({if (model.focused) WidgetState.focused})
```

### 4. A per-instance state look is a theme variant

A per-instance state look is a theme variant passed to that view. The variant
goes through the same derivation as everything else, so it degrades under
ANSI-16 and NO_COLOR like any other theme:

```dart
Button(model: model.delete, theme: theme.copyWith(focus: theme.error))
```

`copyWith` drops a hand-authored `tones16` table when a tone changes, so the
resolver derives the variant's ANSI-16 table from the new tones. Pass
`tones16` to the same call to keep a hand-authored table in control.

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
  quietly lose the theme's intent, so each tone is re-expressed through a
  named ANSI-16 pair from `Theme.tones16`: `error` stays red-family,
  `selection` stays blue-family, and the terminal's own palette
  customization still reads correctly. A theme may hand-author this table.
  One that does not gets a table derived from its RGB tones
  (`Ansi16Tones.derive`). A lift at this tier always steps to the bright
  variant of the slot, whatever the ground: darkening a named slot can
  leave it unchanged, which would hide the step. A slot already at its
  bright variant stays there, so a second lift — hover on top of a state
  lift — collapses into the first instead of adding a further step. Hover
  lifts the same way. A wash has no subtle tint to spend at this tier, so
  it drops entirely. A ground keeps only its foreground, so the terminal's
  own background shows through.
- **`RenderPolicy.noColor`** — color is off (NO_COLOR). Nothing lifts or
  blends at this tier: a base that already carries a background stays as
  it is, a bare base takes the fallback style, and bold and dim carry the
  states instead. Meaning re-expresses through modifiers: `fill` becomes
  `Modifier.reversed`, `ink` keeps its modifiers with the color dropped,
  and `wash` becomes nothing — a crosshair collapses to its cursor cell. A
  ground carries no color at all here, and — unlike `fill` — never
  reverses.

The staircase reads the same from richest to plainest: a fill is tint plus
fill in RGB, a real `(fg, bg)` pair from sixteen names at ANSI-16, and
reversed once color is off. A state that must stay distinguishable —
selected, cursor, focused, error, disabled — never goes invisible on the
way down; it spends a plainer signal at each step. `cursor` is the
exception when a widget paints it only as a wash: a widget that does not
own keyboard focus gives it no fill projection to fall back on, so it
drops to nothing under `ansi16` and `noColor` on a bare row, same as an
ink-only state. An ink-only state with no modifier (`selection.ink` on a
border) does degrade to nothing under NO_COLOR. That loss is accepted,
because every such state stays visible through its fill projection.

`Application` maps the terminal's color profile to a policy before the
first frame and sets it on `StyleResolver.defaultPolicy`. Every
`StyleResolver(theme)` a widget builds adopts it automatically. Route every
style through the resolver and a selected row stays visible however far its
color is stripped.

## Picking dark or light at startup

Choosing which `Theme` to render is a different question from the color
tier, and it is the app's call. Kiko never switches a theme on its own. The
startup capability probe reports the terminal's background as a tri-state
on `InitMsg.hasDarkBackground` (mirrored on `Backend.hasDarkBackground`):
`true` for dark, `false` for light, `null` when the terminal never
answered. Treat `null` as dark; most terminal defaults are. A typical app
reads it once, in `update` on the first `InitMsg`, and picks its starting
theme. Every shipped theme is dark; an app that wants a light theme authors
one (see "Authoring a theme" above) and picks it here.

## Which knob serves which user

| user                                  | touches                                                                  |
| ------------------------------------- | ------------------------------------------------------------------------ |
| "make it look right"                  | nothing — derived defaults                                               |
| "my colors everywhere"                | the tones of a `Theme`                                                   |
| "this table gets an orange crosshair" | `XStyle(...)` passed to the view                                         |
| "every table in my app is custom"     | a shared `const appTableStyle = TableViewStyle(…)`, passed to every view |
| "this column is green"                | `TableColumn.style`                                                      |
| "one row blinks on my signal"         | an item builder                                                          |
| "this button focuses red"             | a theme variant on that view                                             |

A widget that serves all seven rows without the author fighting the
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
|           | `cursorRow`       | `resolver.wash(cursor)`             | cursor × wash    |
|           | `cursorColumn`    | `resolver.wash(cursor)`             | cursor × wash    |
|           | `cursorCell`      | `resolver.fill(cursor)` + bold      | cursor × fill    |
|           | `pending`         | `resolver.ink(muted)`               | anatomy-specific |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| ListView  | `item`            | none (inherits the pane's ground)   | —                |
|           | `selectedItem`    | `resolver.fill(selection)`          | selected × fill  |
|           | `cursorItem`      | `resolver.fill(cursor)` + bold      | cursor × fill    |
|           | `pending`         | `resolver.ink(muted)`               | anatomy-specific |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| TreeView  | `item`            | none (inherits the pane's ground)   | —                |
|           | `cursorItem`      | `resolver.fill(cursor)` + bold      | cursor × fill    |
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
|           | `checkedMark`     | `resolver.ink(selection)`           | selected × ink   |
|           | `label`           | none (inherits the ground)          | —                |
| RadioGroup | `open`           | `resolver.ink(border)`              | resting chrome   |
|            | `close`          | `resolver.ink(border)`              | resting chrome   |
|            | `mark`           | none (inherits the ground)          | —                |
|            | `checkedMark`    | `resolver.ink(selection)`           | selected × ink   |
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
- **TreeView** — the expand, collapse, and loading glyph is the
  `indicator` slot; the default node builder paints the glyph and reads
  it, and a custom `nodeBuilder` paints its own row and never sees it.
  A tree has no selection set, so no `selectedItem`.
- **Button** — one slot, `ButtonStyle.face`. A null face derives
  `resolver.fill(primary)`; states ride the matrix — `focused` lifts the
  face's background and adds bold, `loading` reads warning + blink,
  `disabled` blends the face toward the ground and dims it. A press
  inverts the resolved face through `WidgetState.pressed`.
- **TextInput / TextArea** — region styles are nullable slots on the
  view's `style`. A null region derives from the theme through the resolver:
  placeholder and fill (TextInput) or placeholder and lineNumber (TextArea)
  are muted ink; TextArea's selection is a selection fill. Base text has no
  color of its own; it inherits the ground it is painted on. The text takes
  the focus ink and bold when focused, resolved through the resolver rather
  than a slot; the border a caller composes around the field takes
  `focused` and `error` from the model's own fields.
- **Combobox** — the field styles through `ComboboxStyle.field` and the
  popup's match rows through `ComboboxStyle.list`; the popup border's ink
  styles through `ComboboxStyle.popupBorder` (`docs/combobox.md`).
- **Checkbox** — hover washes the whole row: the box, the gap, the label,
  and any spare cells, as the row's ground. Focused puts focus ink and bold
  on `open`, `close`, and whichever mark is showing, `mark` or
  `checkedMark`, so a checked box reads focused too. Error puts error ink on
  `open` and `close` only. Disabled dims every part. A set `checkedMark`
  slot keeps its own color while unfocused; the `selected` state fills in
  only a null slot. A press inverts
  `open`, `close`, `mark`, and `checkedMark`; the label does not react.
- **RadioGroup** — the group is one widget. Focus lands on one option, the
  option at the cursor. It never lands on a cursor bar. Error is a group
  fact. It paints on every option's brackets. On the cursor row, error ink
  wins over focus ink. The focus bold stays. A disabled option dims its
  own parts. A disabled group dims every option's parts. Hover washes one
  option's row, spare cells included. Pressed inverts one option's box. A
  set `checkedMark` slot keeps its own color, like the checkbox's.
  `labelAlign` has no visible effect in a horizontal group.

`ItemState` and `NodeState`, the records passed to item/node builders,
use `cursor` (not `focused`) for the current-item flag. `ItemState` carries
`selected`, `cursor`, `hover`, and `disabled`. `NodeState` carries `cursor`,
`hover`, `loading`, and `expanded`. `CellRenderContext`, passed to
`TableColumn.render`, carries `selected`, `cursorRow`, `cursorCell`, and
`hover` for the same four facts on a cell.
