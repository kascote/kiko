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
3. HOW does it land as paint? → Projection  (the part's paint class: ink / fill / wash)
4. WHO can override it?       → Anatomy     (per-widget style slots, per instance)
```

- A **tone** is a color pair `(color, on)`. It is not paintable: it becomes
  a `Style` only through a projection. The compiler rejects a raw tone
  where a `Style` is expected, so a fill's background can never land on
  border glyphs by accident.
- A **projection** turns a tone into a `Style` for one paint class: `ink`
  (foreground only), `fill` (`fg: on, bg: color`), or `wash` (background
  only).
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
/// A color identity. Not paintable: project it with .ink / .fill / .wash.
@immutable
class Tone {
  final Color? color; // the identity color (nullable: terminal-default themes)
  final Color? on;    // a color readable on top of `color`

  const Tone({this.color, this.on});

  Style get ink  => Style(fg: color);
  Style get fill => Style(fg: on, bg: color);
  Style get wash => Style(bg: color);
}
```

The raw halves (`tone.color`, `tone.on`) stay public. Projections cover the
common cases; the raw halves allow custom derivations.

The tone set:

| Group       | Tone         | `color` is…                   | `on` is…               |
| ----------- | ------------ | ----------------------------- | ---------------------- |
| Intent      | `primary`    | brand / main action           | text on a primary fill |
|             | `secondary`  | second-rank action            | 〃                     |
|             | `accent`     | attention, badges             | 〃                     |
|             | `error`      | destructive / invalid         | 〃                     |
|             | `warning`    | caution                       | 〃                     |
|             | `success`    | confirmation                  | 〃                     |
| Neutral     | `background` | the app base color            | **default text**       |
|             | `surface`    | elevated panels, dialogs      | text on surface        |
|             | `border`     | resting chrome                | (rarely used)          |
|             | `muted`      | secondary text                | —                      |
|             | `disabled`   | non-interactive               | —                      |
| Interaction | `focus`      | "you are here" (keyboard)     | text on a focus fill   |
|             | `selection`  | chosen items                  | text on selection      |
|             | `cursor`     | current row/col wash (subtle) | text on cursor cell    |
|             | `hover`      | mouse-over wash (subtle)      | —                      |

`selection` means chosen items. Search-match styling is widget anatomy, not
a tone.

`cursor` and `hover` are derived by default, so a theme author writes
thirteen tones, not fifteen. The defaults are subtle lifts of the
background: `cursor` is `background.color.lift(0.10)` and `hover` is
`background.color.lift(0.08)`. `lift` lightens on a dark theme and darkens
on a light one. `lift`, `lighten`, and `darken` are public `Color` methods,
so themes, anatomy slots, and apps can do their own derivations. A theme
may set `cursor` and `hover` explicitly instead.

### A theme is just tones

```dart
static const dark = Theme(
  primary:    Tone(color: Color.rgb(0x58a6b0), on: Color.rgb(0x0d1117)),
  background: Tone(color: Color.rgb(0x0d1117), on: Color.rgb(0xc9d1d9)),
  surface:    Tone(color: Color.rgb(0x161b22), on: Color.rgb(0xc9d1d9)),
  border:     Tone(color: Color.rgb(0x30363d)),
  muted:      Tone(color: Color.rgb(0x6e7681)),
  focus:      Tone(color: Color.rgb(0x6bc5d2), on: Color.rgb(0x0d1117)),
  selection:  Tone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9)),
  // cursor, hover: omitted → derived washes over background
  ...
);
```

**Transparent-background themes.** `background.color = null` keeps the
terminal's own background; fills over it set `bg: null`. Such a theme
should set `cursor` and `hover` explicitly. A wash cannot be derived from
an unknown background, so the derived tones come out empty.

## Projections

| Projection | Produces            | Use for                                              |
| ---------- | ------------------- | ---------------------------------------------------- |
| `ink`      | `fg` only           | line glyphs, separators, scrollbars, accent text     |
| `fill`     | `fg: on, bg: color` | filled surfaces: selected rows, button faces, badges |
| `wash`     | `bg` only           | tints under existing content: a crosshair row/column |

`wash` is the one to remember. It changes the background only, so a cell
keeps whatever foreground it already had. A custom `render` that colored a
number red stays red under the wash. `Style.patch` makes this work: a
bg-only style patched over content changes the background and nothing else.

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
  unfocused,  // its container lost focus (dim)
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
}
```

`border` resolves the resting border tone as ink.
`resolver.border({if (m.focused) WidgetState.focused})` replaces the
hand-written `m.focused ? theme.focus : theme.border` at every call site.

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
| `unfocused` | `muted`     | `muted.ink`               | `muted.ink` + `surface.wash` | —                |
| `loading`   | `warning`   | `warning.ink` + slowBlink | 〃                           | —                |
| `error`     | `error`     | `error.ink`               | `error.fill`                 | `error.wash`     |
| `disabled`  | `disabled`  | `disabled.ink` + dim      | 〃                           | —                |

Reading examples:

- A selected pane border is `selected` × `ink`: a foreground tint of the
  selection color, no background.
- A focused button is `focused` × `fill`: `focus.fill` plus bold.
- An error input's border is `error` × `ink`; its text keeps the base
  style. The matrix only patches what a state owns.

## Theming a widget

The recipe, step by step.

### 1. Classify each part as ink, fill, or wash

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
/// | slot          | derived default            | matrix source     |
/// | ------------- | -------------------------- | ----------------- |
/// | `item`        | none (inherits)            | —                 |
/// | `selectedItem`| `theme.selection.fill`     | selected × fill   |
/// | `cursorItem`  | `theme.cursor.fill` + bold | cursor × fill     |
/// | `placeholder` | `theme.muted.ink`          | anatomy-specific  |
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
  so it drops entirely.
- **`RenderPolicy.noColor`** — color is off (NO_COLOR). Meaning
  re-expresses through modifiers: `fill` becomes `Modifier.reversed`, `ink`
  keeps its modifiers with the color dropped, and `wash` becomes nothing —
  a crosshair collapses to its cursor cell.

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
when adding a slot or theming a new widget:

- **TableView** — `TableViewStyle {header, row, separator, selectedRow,
  cursorRow, cursorColumn, cursorCell, loadingRow, placeholder}`. The
  crosshair is enabled by `showCrosshair` on the model, not by slot
  presence: a slot styles a part, it does not create the behavior. A cell
  paints base → hover → selectedRow → cursorRow/cursorColumn → cursorCell,
  each patched over the last. The exemplar — copy its shape.
- **ListView** — `ListViewStyle {item, selectedItem, cursorItem,
  placeholder}`.
- **TreeView** — `TreeViewStyle {item, cursorItem, placeholder}`. The
  expand glyph stays on `indicatorStyle`; placeholder text stays on the
  `loadingIndicator`/`errorIndicator` `Line`s. A tree has no selection set,
  so no `selectedItem`.
- **Button** — no anatomy class. The resting face is `theme.primary.fill`;
  states ride the matrix (focused → `focus.fill` + bold, loading → warning
  + blink, disabled → dim).
- **TextInput / TextArea** — region styles (`TextInputStyle` /
  `TextAreaStyle`: placeholder, fill, obscured; selection, lineNumber) via
  `fromTheme`; base text and focus through the resolver.

`ItemState` and `NodeState`, the records passed to item/node builders,
expose `cursor` (not `focused`): the current-item flag.
