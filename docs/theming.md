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
thirteen tones, not fifteen. The defaults are subtle lifts of the
background: `cursor` is `background.color.lift(0.10)` and `hover` is
`background.color.lift(0.08)`. `lift` lightens on a dark theme and darkens
on a light one. `lift`, `lighten`, and `darken` are public `Color` methods,
so themes, anatomy slots, and apps can do their own derivations. A theme
may set `cursor` and `hover` explicitly instead.

`ToneSet` holds the tones that reach paint on every tier. `hover` only
washes, and a wash is empty under ANSI-16 and NO_COLOR, so `hover` lives
on `Theme` alone.

### A theme is just tones

```dart
static const dark = Theme(
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

**Transparent-background themes.** `background.color == null` keeps the
terminal's own background: fills over it set `bg: null`, and the frame's
ground carries only its foreground, `background.on`. Such a theme should
set `cursor` and `hover` explicitly. A wash cannot be derived from an
unknown background: `hover` comes out fully empty, and `cursor` keeps
`background`'s `on` but carries no color.

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
the `surface` ground behind its own content, the same way.

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
  loading,    // async in flight
  error,      // invalid / failed
  disabled,   // non-interactive — overrides everything
}
```

Declaration order is priority order: when several states apply, a later
state's contribution patches over an earlier one's. `cursor` beats
`selected`, so the cursor bar stays visible while it moves over a selected
run. `disabled` is last and overrides everything.

**Use honest states.** The keyboard-current item is `WidgetState.cursor`,
never `focused` or `hover`. `focused` means the widget owns keyboard input.
`hover` means the mouse is over the widget; the keyboard never sets it.
Keyboard position and mouse hover are different facts. They can coexist and
deserve different looks: hover as a faint wash under the pointer, cursor as
the bar you move with arrows.

## The resolver

`StyleResolver` maps `(state, paint class)` to paint through a built-in
matrix. The state picks the tone; the caller passes the part's class.

```dart
enum PaintClass { ink, fill, wash }

class StyleResolver {
  StyleResolver(this.theme); // adopts StyleResolver.defaultPolicy

  /// Resolves [base] under [states] for one paint class.
  Style resolve(
    Style? base,
    Set<WidgetState> states, {
    PaintClass cls = PaintClass.fill,
    Map<WidgetState, Style>? overrides, // per-instance escape hatch
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

A raw projection (`theme.success.fill`) bypasses the render policy: it
paints RGB on every terminal. App content that paints tones directly — a
title in `primary`, a status badge in `success` — should read the tone
from `resolver.tones` and project it with `resolver.ink` / `fill` / `wash`
instead, so it degrades with the rest of the screen.

### The state × class matrix

This table is the built-in look of kiko. It is the single place where "what
does selected mean on a border" is decided. An em-dash means the state does
not affect that class; modifiers ride on top of the projection.

| state       | tone        | `ink` (chrome/text)       | `fill` (surfaces)            | `wash` (tints)   |
| ----------- | ----------- | ------------------------- | ---------------------------- | ---------------- |
| `hover`     | `hover`     | —                         | —                            | `hover.wash`     |
| `selected`  | `selection` | `selection.ink`           | `selection.fill`             | `selection.wash` |
| `cursor`    | `cursor`    | —                         | `cursor.fill` + bold         | `cursor.wash`    |
| `focused`   | `focus`     | `focus.ink` + bold        | `focus.fill` + bold          | —                |
| `loading`   | `warning`   | `warning.ink` + slowBlink | 〃                           | —                |
| `error`     | `error`     | `error.ink`               | `error.fill`                 | `error.wash`     |
| `disabled`  | `disabled`  | `disabled.ink` + dim      | 〃                           | —                |

Reading examples:

- A selected pane border is `selected` × `ink`: a foreground tint of the
  selection color, no background.
- A focused button is `focused` × `fill`: `focus.fill` plus bold.
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
| `hover`      | the wash under the mouse                              |

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

Hold the anatomy on the model as a mutable `styles` field (default
`const FooViewStyle()`), the way `TableViewModel.styles` does. An app can
then swap the look at runtime.

Give a slot only to a part you actually paint. ListView and TreeView have
no `indicator` slot: their `itemBuilder`/`nodeBuilder` owns every glyph, so
the slot would style nothing. Do not duplicate a part that already has a
home. TreeView keeps its expand glyph on `indicatorStyle` and its
loading/error placeholder text on the `loadingIndicator`/`errorIndicator`
`Line`s, which carry their own style, so `TreeViewStyle` does not
re-declare them.

### 3. Resolve states through the resolver, with the right class

For each part, fall back from the slot to the resolver:

```dart
late final _resolver = StyleResolver(theme);

Style _selectedItemStyle() =>
    model.styles.selectedItem ?? _resolver.resolve(null, const {WidgetState.selected}, overrides: styleOverrides);

Style _cursorItemStyle() =>
    model.styles.cursorItem ?? _resolver.resolve(null, const {WidgetState.cursor}, overrides: styleOverrides);
```

`resolve` defaults to `PaintClass.fill`, the surface case. Pass
`cls: PaintClass.wash` for a tint and `cls: PaintClass.ink` for chrome.

Layer parts by patching in the matrix's priority order — base → selected →
cursor → disabled — each `Style.patch` over the last. The cursor then stays
visible over a selected run, and disabled dims everything:

```dart
var s = model.styles.item ?? const Style();
if (isSelected) s = s.patch(_selectedItemStyle());
if (isCursor)   s = s.patch(_cursorItemStyle());
if (isDisabled) s = s.patch(_resolver.resolve(null, const {WidgetState.disabled}));
```

For borders, use the `border` helper:

```dart
borderStyle: resolver.border({if (model.focused) WidgetState.focused})
```

### 4. Expose per-state `styleOverrides`

Take an optional `Map<WidgetState, Style>? styleOverrides` and thread it
into every `resolve` call. It is the per-instance escape hatch for
state-dependent bits — one row blinks on the app's signal — without a whole
custom `XStyle`.

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
  (`Ansi16Tones.derive`). A wash has no subtle tint to spend at this tier,
  so it drops entirely. A ground keeps only its foreground, so the
  terminal's own background shows through.
- **`RenderPolicy.noColor`** — color is off (NO_COLOR). Meaning
  re-expresses through modifiers: `fill` becomes `Modifier.reversed`, `ink`
  keeps its modifiers with the color dropped, and `wash` becomes nothing —
  a crosshair collapses to its cursor cell. A ground carries no color at
  all here, and — unlike `fill` — never reverses.

The staircase reads the same from richest to plainest: a fill is tint plus
fill in RGB, a real `(fg, bg)` pair from sixteen names at ANSI-16, and
reversed once color is off. A state that must stay distinguishable —
selected, cursor, focused, error, disabled — never goes invisible on the
way down; it spends a plainer signal at each step. An ink-only state with
no modifier (`selection.ink` on a border) does degrade to nothing under
NO_COLOR. That loss is accepted, because every such state stays visible
through its fill projection.

`Application` maps the terminal's color profile to a policy before the
first frame and sets it on `StyleResolver.defaultPolicy`. Every
`StyleResolver(theme)` a widget builds adopts it automatically. Route every
style through the resolver and a selected row stays visible however far its
color is stripped.

## Picking dark or light at startup

Choosing which `Theme` to render — `Theme.dark` vs `Theme.light` — is a
different question from the color tier, and it is the app's call. Kiko
never switches a theme on its own. The startup capability probe reports the
terminal's background as a tri-state on `InitMsg.hasDarkBackground`
(mirrored on `Backend.hasDarkBackground`): `true` for dark, `false` for
light, `null` when the terminal never answered. Treat `null` as dark; most
terminal defaults are. A typical app reads it once, in `update` on the
first `InitMsg`, and picks its starting theme.

## Which knob serves which user

| user                                  | touches                                            |
| ------------------------------------- | -------------------------------------------------- |
| "make it look right"                  | nothing — derived defaults                         |
| "my colors everywhere"                | the tones of a `Theme`                             |
| "this table gets an orange crosshair" | `XStyle(...)` on that instance                     |
| "every table in my app is custom"     | a shared `const appTableStyle = TableViewStyle(…)` |
| "one row blinks on my signal"         | per-state `styleOverrides` / a custom `render`     |

A widget that serves all five rows without the author fighting the
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
|           | `loadingRow`      | `resolver.ink(muted)`               | anatomy-specific |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| ListView  | `item`            | none (inherits the pane's ground)   | —                |
|           | `selectedItem`    | `resolver.fill(selection)`          | selected × fill  |
|           | `cursorItem`      | `resolver.fill(cursor)` + bold      | cursor × fill    |
|           | `loadingItem`     | `resolver.ink(muted)`               | anatomy-specific |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| TreeView  | `item`            | none (inherits the pane's ground)   | —                |
|           | `cursorItem`      | `resolver.fill(cursor)` + bold      | cursor × fill    |
|           | `placeholder`     | `resolver.ink(muted)`               | anatomy-specific |
| Combobox  | `toggle`          | inherit                             | focused × ink    |
|           | `popupGround`     | `resolver.ground(surface)`          | anatomy-specific |
|           | `loadingRow`      | `resolver.ink(muted)`               | anatomy-specific |
|           | `errorRow`        | `resolver.ink(muted)`               | anatomy-specific |
|           | `stalledRow`      | `resolver.ink(muted)`               | anatomy-specific |
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

Notes the table cannot carry:

- **TableView** — the crosshair (`cursorColumn`) is enabled by
  `showCrosshair` on the model, not by slot presence: a slot styles a part,
  it does not create the behavior. A cell paints base → hover → selectedRow
  → cursorRow/cursorColumn → cursorCell, each patched over the last. The
  exemplar — copy its shape.
- **TreeView** — the expand glyph stays on `indicatorStyle`; placeholder
  text stays on the `loadingIndicator`/`errorIndicator` `Line`s. A tree has
  no selection set, so no `selectedItem`.
- **Button** — no anatomy class. The resting face is `resolver.fill(primary)`;
  states ride the matrix (focused → `resolver.fill(focus)` + bold, loading →
  warning + blink, disabled → dim).
- **TextInput / TextArea** — region styles are nullable slots on
  `model.style`. A null region derives from the theme through the resolver:
  placeholder and fill (TextInput) or placeholder and lineNumber (TextArea)
  are muted ink; TextArea's selection is a selection fill. Base text has no
  color of its own; it inherits the ground it is painted on. Focus resolves
  through the resolver, not through slots.
- **Combobox** — the field's own look stays `TextInputModel`'s business,
  and the popup's match rows style through the embedded `ListViewStyle`,
  not through `ComboboxStyle` (`docs/combobox.md`).
- **Checkbox** — hover washes the whole row: the box, the gap, the label,
  and any spare cells, as the row's ground. Focused puts focus ink and bold
  on `open`, `mark`, and `close`. Error puts error ink on `open` and `close`
  only. Disabled dims every part. A set `checkedMark` slot keeps its own
  color; the `selected` state fills in only a null slot.

`ItemState` and `NodeState`, the records passed to item/node builders,
expose `cursor` (not `focused`): the current-item flag.
