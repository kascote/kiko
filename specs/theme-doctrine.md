# Theme Doctrine — a ground-up model for styling kiko

**Status: LANDED 2026-07-06 — D1–D7 ratified (§8); phases P1–P6 shipped (mikos
0135). Deviations recorded in §11.**
This is not a patch plan. It rebuilds the theme story from first principles; the
current `Theme`/`StyleResolver` are treated as a prototype we learn from, not a
constraint. Supersedes `theme-review.md`, `theme-action-plan.md`,
`theme-expert-review.md`, and `theme-resolver-implementation.md` as doctrine
(they remain as history). This spec is the source of truth.

---

## 1. What the prototype taught us

Three failures observed in real code, each pointing at a missing concept:

**F1 — One token, two kinds of paint.** `theme.highlight` is designed as a
fill (fg+bg pair for a selected row). Painted onto box-border glyphs it floods
the border cells' background — the "ugly selected border". `theme.focus` only
works on borders *by luck* (it happens to carry no bg). The missing concept:
a token is not paint; **how a token lands depends on what is being painted**.

**F2 — Anatomy faked with borrowed states.** The table renderer styles the
cursor row as `WidgetState.hover` (a mouse concept) and the cursor cell as
`WidgetState.focused` (a widget-level concept) — because "current row/column/
cell" have no home. Adding a crosshair (current row + current column) has
nothing left to borrow. The missing concept: **widget parts are anatomy, not
states**, and each widget's anatomy needs a place to live that isn't the
global theme.

**F3 — Role resolution hand-rolled at every call site.** Every example writes
`input.focused ? theme.focus : theme.border` for its box borders. That is the
app manually doing (state → token → paint) resolution, because the system has
no vocabulary for it.

One meta-lesson: the prototype's doc comment already *says* the right thing —
"fg: the primary color, bg: the contrast color; use `.inverted` for surfaces" —
but nothing *enforces* it, so raw tokens get painted directly and F1 happens.
The rebuild makes the projection step explicit and type-checked.

---

## 2. The model on one page

Four questions, four layers. Every styled cell on screen is the answer to:

```
1. WHICH color family?            → Tone        (the theme owns these)
2. WHICH tone right now?          → WidgetState (interaction picks the tone)
3. HOW does it land as paint?     → Projection  (the part's paint class: ink / fill / wash)
4. WHO can override it?           → Anatomy     (per-widget style slots, per-instance)
```

- A **Tone** is a color pair `(color, on)`. It is **not paintable** — it has no
  way to become cells on screen except through a projection. This is the core
  type-safety move: F1 becomes a compile error, not a code-review catch.
- A **Projection** turns a tone into a `Style` for one paint class:
  - `ink` — fg only. Line glyphs, separators, scrollbars, accent text.
  - `fill` — `fg: on, bg: color`. Surfaces: selected rows, button faces, badges.
  - `wash` — bg only. Tints the background *under* existing content, preserving
    each cell's own fg (exactly what a crosshair row/column needs).

  Projections constrain what the **derivation** produces, not what a style may
  be. "A derived border style never carries bg" is the invariant that kills F1;
  an *explicit* `Style(fg: …, bg: …)` handed to a border is a deliberate design
  choice and always allowed (§4, §6).
- **States pick tones, parts pick projections.** A selected pane border and a
  selected row use the *same* tone (`selection`) through *different*
  projections (`ink` vs `fill`) — that single sentence is the fix for F1.
- **Anatomy slots** let a widget publish its parts (`cursorColumn`, `header`,
  …) as nullable style slots: `null` = derived from tones by documented rules,
  non-null = the user's exact style wins. That is the fix for F2, and the
  escape hatch for "I want something fancy the theme never imagined".

The doctrine line for "where does a new styling knob go":

> If every widget could have it, it is a **state**. If only this widget has
> it, it is **anatomy**. If it's a color identity the whole app shares, it is
> a **tone**. Nothing else is ever added to `Theme`.

`Theme` therefore stays frozen at ~a dozen tones forever; widgets grow
freely without touching core.

---

## 3. Layer 1 — Tones

```dart
/// A color identity. Not paintable: project it with .ink / .fill / .wash.
@immutable
class Tone {
  final Color? color; // the identity color (nullable: terminal-default bg themes)
  final Color? on;    // a color readable on top of `color`

  const Tone({this.color, this.on});

  Style get ink  => Style(fg: color);
  Style get fill => Style(fg: on, bg: color);
  Style get wash => Style(bg: color);
}
```

Raw halves (`tone.color`, `tone.on`) stay accessible for custom derivations —
projections are the blessed 95% path, not a cage.

### Proposed tone set (D2)

| Group       | Tone         | `color` is…                  | `on` is…            |
| ----------- | ------------ | ---------------------------- | ------------------- |
| Intent      | `primary`    | brand / main action          | text on a primary fill |
|             | `secondary`  | second-rank action           | 〃                  |
|             | `accent`     | attention, badges            | 〃                  |
|             | `error`      | destructive / invalid        | 〃                  |
|             | `warning`    | caution                      | 〃                  |
|             | `success`    | confirmation                 | 〃                  |
| Neutral     | `background` | the app base color           | **default text**    |
|             | `surface`    | elevated panels, dialogs     | text on surface     |
|             | `border`     | resting chrome               | (rarely used)       |
|             | `muted`      | secondary text               | —                   |
|             | `disabled`   | non-interactive              | —                   |
| Interaction | `focus`      | "you are here" (keyboard)    | text on a focus fill |
|             | `selection`  | chosen items                 | text on selection   |
|             | `cursor`     | current row/col wash (subtle)| text on cursor cell |
|             | `hover`      | mouse-over wash (subtle)     | —                   |

Notes:

- `highlight` is renamed `selection` — "highlight" was doing double duty
  (search matches vs selected items); search-match styling is widget anatomy
  (e.g. a future `SearchStyle.match`), not a global tone.
- `cursor` and `hover` are **derived by default** so theme authors write 12
  tones, not 14: `cursor.color ??= lift(background.color, 0.10)`,
  `hover.color ??= lift(background.color, 0.08)` — where `lift` = lighten on
  dark themes, darken on light ones. A theme *may* set them explicitly
  (e.g. Ember could use a faint warm wash). This settles the parked
  "hover intensity 10%?" question: it's a default, not a law. **(D4)**

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

Compare with the prototype, where `bg: Color.rgb(0x0d1117)` is hand-repeated
into eight palette entries — that repetition was the pair model trying to
exist without a type for it.

---

## 4. Layer 2 — Projections (the role layer)

### The worked example that motivates everything

A pane whose content is selected, drawn with `Box`. The *tone* is `selection`
in both worlds; only the projection differs per part:

```
PROTOTYPE (token = paintable Style, no projection step)      REBUILT (tone + explicit projection)

borderStyle: theme.highlight                                 borderStyle: theme.selection.ink
┌────────────────────┐                                       ┌────────────────────┐
│ every border cell  │ ← border glyphs get bg 0x264a5c:      │ glyphs tinted; the │ ← fg-only tint;
│ drags a navy       │   a hollow picture-frame of           │ cells behind keep  │   bg untouched
│ picture-frame      │   background color around the pane    │ their background   │
└────────────────────┘                                       └────────────────────┘

row fill (want the navy bg):                                 row fill:
style = theme.highlight        // happens to work            style = theme.selection.fill   // says what it means
```

The prototype's failure mode isn't a bad color choice — it's that *nothing
distinguishes the two call sites*. With tones, the raw `theme.selection`
doesn't type-check where a `Style` is expected; the author must pick a
projection, and the projection is self-documenting.

### Wash: the projection the prototype didn't have

`wash` exists for exactly one reason: tint an area's background **without
touching the fg of what's already there**. A cursor-column wash over a table
must not repaint cell text that a custom `render` colored (negative amounts
in red stay red). `Style.patch` semantics make this free: a bg-only style
patched over content changes bg and nothing else.

```dart
// current column, painted after cell content:
surface.patchRow(y, x, width, theme.cursor.wash);
```

### Box stays theme-free

`Box` keeps taking a plain `Style`, and that style is unrestricted — a border
with an explicit bg (a filled dialog frame, a status strip) is a legitimate
design. What changes is the *default* path: when the style comes from the
theme, callers hand Box an ink (`resolver.border(states)`), so a tone can
never bleed a surprise bg onto border glyphs. This resolves the parked
"should Block require a Theme?" question: **no**. The theme-awareness lives
one level up, in the resolver helper (§5), which kills the F3 boilerplate.

---

## 5. Layer 3 — States

### Revised state set (D3)

```dart
enum WidgetState {
  hover,      // mouse is over it — mouse only, never keyboard
  selected,   // it is in the chosen set
  cursor,     // it is the current item (keyboard position)  ← NEW
  focused,    // the widget owns keyboard input
  unfocused,  // its container lost focus (dim)
  loading,    // async in flight
  error,      // invalid / failed
  disabled,   // non-interactive — overrides everything
}
```

Changes from the prototype:

- **`cursor` added.** Keyboard position and mouse hover are different facts
  that can coexist and deserve different looks (hover = faint wash under the
  pointer; cursor = the bar you move with arrows). The prototype's renderers
  borrowing `hover` for the cursor row is F2.
- **Order fixed.** Declaration order is priority order (later wins).
  The prototype *documents* "disabled overrides all" but declares `loading`
  and `error` after it. Here `disabled` is genuinely last. `cursor` beats
  `selected` (the bar must stay visible while moving over a selected run —
  file-manager behavior).

### The resolver: states pick tones, call sites pick projections

```dart
enum PaintClass { ink, fill, wash }

class StyleResolver {
  final Theme theme;
  const StyleResolver(this.theme);

  /// Resolve [base] under [states] for one paint class.
  Style resolve(
    Style? base,
    Set<WidgetState> states, {
    PaintClass cls = PaintClass.fill,
    Map<WidgetState, Style>? overrides,   // per-instance escape hatch, unchanged
  });

  /// The F3 killer: border style for a set of states.
  /// `resolver.border({if (m.focused) WidgetState.focused})`
  /// replaces every `m.focused ? theme.focus : theme.border` in app code.
  Style border(Set<WidgetState> states) =>
      resolve(theme.border.ink, states, cls: PaintClass.ink);
}
```

### The state × class matrix

This table **is** the built-in look of kiko. It is the single place where
"what does selected mean on a border" is decided. (em-dash = state does not
affect that class; modifiers ride on top of the projection.)

| state       | tone        | `ink` (chrome/text)     | `fill` (surfaces)          | `wash` (tints)      |
| ----------- | ----------- | ----------------------- | -------------------------- | ------------------- |
| `hover`     | `hover`     | —                       | —                          | `hover.wash`        |
| `selected`  | `selection` | `selection.ink`         | `selection.fill`           | `selection.wash`    |
| `cursor`    | `cursor`    | —                       | `cursor.fill` **+ bold**   | `cursor.wash`       |
| `focused`   | `focus`     | `focus.ink` **+ bold**  | `focus.fill` **+ bold**    | —                   |
| `unfocused` | `muted`     | `muted.ink`             | `muted.ink` + `surface.wash` | —                 |
| `loading`   | `warning`   | `warning.ink` + slowBlink | 〃                       | —                   |
| `error`     | `error`     | `error.ink`             | `error.fill`               | `error.wash`        |
| `disabled`  | `disabled`  | `disabled.ink` + dim    | `disabled.ink` + dim       | —                   |

Reading examples:

- Selected pane border = row `selected` × col `ink` = fg-tint of the selection
  color. No bg. F1 is structurally gone.
- A focused button = `focused` × `fill` = `focus.fill` + bold — the full
  inversion doctrine survives, now as one matrix cell instead of per-widget code.
- An error'd input's border = `error` × `ink`; its text = base style — the
  matrix only patches what the state owns.

---

## 6. Layer 4 — Widget anatomy

Every widget publishes its parts as a style class with **nullable slots**:
`null` = derived from tones via a documented table; non-null = wins verbatim.
Slots are plain `Style` — at this layer the user is stating exact paint, so
tones/projections are not forced on them **(D5)**.

### TableView as the exemplar

```dart
class TableViewStyle {
  final Style? header;        // sticky header text
  final Style? row;           // base row (usually null: inherit pane fill)
  final Style? separator;     // column separator glyphs
  final Style? selectedRow;   // rows in the selection set
  final Style? cursorRow;     // crosshair: current row      ← painted as wash
  final Style? cursorColumn;  // crosshair: current column   ← painted as wash
  final Style? cursorCell;    // row ∩ column                ← painted as fill
  final Style? loadingRow;    // windowed-out placeholder rows
  final Style? placeholder;   // empty-state line
  const TableViewStyle({ ... all optional ... });
}
```

Derivation table (the widget's contract, in its doc comment):

| slot           | derived default                          | matrix source        |
| -------------- | ---------------------------------------- | ------------------- |
| `header`       | `Style(fg: theme.background.on)` + bold  | anatomy-specific    |
| `row`          | none (inherits)                          | —                   |
| `separator`    | `theme.border.ink`                       | resting chrome      |
| `selectedRow`  | `theme.selection.fill`                   | selected × fill     |
| `cursorRow`    | `theme.cursor.wash`                      | cursor × wash       |
| `cursorColumn` | `theme.cursor.wash`                      | cursor × wash       |
| `cursorCell`   | `theme.cursor.fill` + bold               | cursor × fill       |
| `loadingRow`   | `theme.muted.ink`                        | anatomy-specific    |
| `placeholder`  | `theme.muted.ink`                        | anatomy-specific    |

Paint order at a cell: `row base → selectedRow (fill) → cursorRow/Column
(wash) → cursorCell (fill)` — washes layer over fills by patching bg only;
the cursor cell wins outright. Crosshair is enabled by config
(`showCrosshair` on the model/config), not by slot presence — a slot styles a
part, it doesn't create the behavior.

### The user-story tiers this buys

| user                                | touches                                          |
| ----------------------------------- | ------------------------------------------------ |
| "make it look right"                | nothing — derived defaults                       |
| "my colors everywhere"              | the ~12 tones of a `Theme`                       |
| "this table gets an orange crosshair" | `TableViewStyle(...)` on that instance         |
| "every table in my app is custom"   | a shared `const appTableStyle = TableViewStyle(…)` |
| "one row blinks on my signal"       | per-state `styleOverrides` / custom `col.render` |

The fancy user never fights the framework:

```dart
TableView(
  model: m,
  theme: theme,
  styles: const TableViewStyle(
    cursorRow:    Style(bg: Color.rgb(0x2a1d10)),          // warm wash
    cursorColumn: Style(bg: Color.rgb(0x2a1d10)),
    cursorCell:   Style(fg: Color.rgb(0x0a0908), bg: Color.rgb(0xe07830),
                        addModifier: Modifier.bold),        // ember block cursor
  ),
)
```

ListView/TreeView get the same treatment (`ListViewStyle`, `TreeViewStyle`)
— same shape, own anatomy (`indicator`, `expandIcon`, `errorPlaceholder`, …),
mirroring how the three data widgets already share the keyed load-slot pattern.

---

## 7. Degradation — three tiers of color fidelity

A theme is authored once, in RGB, for every terminal. What changes tier to
tier is not the theme but how the resolver turns a tone into paint:

1. **RGB, downsampled automatically.** A theme's tones are free RGB. On a
   256-color terminal termkit downsamples that RGB to the nearest palette
   entry on the way out, invisibly; a truecolor terminal renders it
   untouched. The theme layer does nothing here — this tier is the
   transport's job.
2. **ANSI-16: a named tone table, not a downsample.** A plain 16-color
   terminal has no free hues left to downsample into — only the sixteen
   slots the user has already picked colors for, and a nearest-color search
   over just sixteen entries quietly loses a theme's intent (error can land
   on whatever hue happens to be numerically closest). So at this tier the
   resolver does not downsample: each tone is re-expressed through a *named*
   ANSI-16 pair (`Theme.tones16`) — `error` is always red-family, `selection`
   is always blue-family, and so on — so the terminal's own palette
   customization still reads correctly. A theme may hand-author this table
   for full control; one that leaves it unset gets a table derived
   automatically from its RGB tones (nearest-color search plus a fresh
   black-or-white `on` chosen by contrast) as a fallback, never a requirement.
   A wash has nothing to spend at this tier either — the sixteen names carry
   no subtle tints — so it drops entirely, same as NO_COLOR.
3. **NO_COLOR: modifiers carry meaning.** Color is off entirely. Stripping
   color is correct per-cell but blind to intent — a selection whose entire
   identity is its background becomes *invisible*, not merely degraded — so
   meaning is re-expressed through modifiers, at the one place that still
   knows the intent: the projection. `fill → Modifier.reversed`, `ink →`
   its modifiers with color dropped (bold/dim survive), `wash → nothing` (a
   wash cannot exist without color — the crosshair degrades to the cursor
   cell only, which is correct behavior, not a loss).

The staircase reads the same way at every tier, from richest to plainest: a
fill is **tint + fill** in full RGB, **fill only** through the named ANSI-16
pair (still a real `(fg, bg)`, just fewer of them to pick from), and
**reversed only** once color is off completely. A state that must stay
distinguishable — selected, cursor, focused, error — never goes invisible on
the way down; it just spends a plainer signal at each step. Mechanically this
lives in one place: the resolver applies the active `RenderPolicy` inside
every projection call, so a widget never branches on which tier it is
running under.

**Transparent-background themes**: `background.color = null` → fills over it
set `bg: null` (terminal default). Washes cannot be derived from an unknown
background, so such themes must either provide explicit `cursor`/`hover`
tones or accept modifier-based fallbacks.

**Picking dark or light is a separate question from any of the above** — it
is which `Theme` instance an app renders with, not which color tier the
terminal supports. The startup capability probe answers it as a tri-state:
`InitMsg.hasDarkBackground` (mirrored on `Backend.hasDarkBackground`) is
`true` when the terminal's own background reads dark, `false` when it reads
light, and `null` when the terminal never answered — treat `null` as dark by
convention, since most terminal defaults are. Kiko never switches a theme on
its own; it hands the app this one fact, and the app's `update` reads it
(typically once, from `InitMsg`, to pick `Theme.dark` or `Theme.light` for
the initial model) and keeps owning that choice for the rest of the run.

---

## 8. Decisions — all DECIDED 2026-07-06

**D1 — Token shape: non-paintable `Tone`. DECIDED.** F1 becomes
unrepresentable; theme definitions lose the repeated-bg noise; projections
self-document call sites. (Rejected: keep `Style`-as-token + prose doctrine —
prose doctrine is exactly what already failed.)

**D2 — Tone set: §3 table ratified.** `highlight → selection` rename; derived
`cursor` + `hover`; no `info` until needed. `secondary` stays — confirmed
needed, not `muted` in disguise.

**D3 — State set: §5 ratified.** `cursor` added; `hover` mouse-only; priority
order `hover < selected < cursor < focused < unfocused < loading < error <
disabled`. Noted: `hover` and `focused` look ~90% the same in practice, but
`hover` earns its place the way `secondary` does. `unfocused` kept as a state
for now; revisit alongside the focus-coordination work.

**D4 — Derived washes: ratified, with the helpers public.** Defaults
`hover = lift(bg, 0.08)`, `cursor = lift(bg, 0.10)` (lift = lighten on dark
themes, darken on light). The color helpers — `lift`, `lighten`, `darken` and
friends — are public API so themes, anatomy slots, and apps can do their own
derivations. (Rejected: Material-style container variants per tone — doubles
the tone count for a subtlety terminals can't always render; a theme that
wants a different wash sets the tone explicitly.)

**D5 — Anatomy slots: plain `Style?`. DECIDED.** Plus the existing per-state
`styleOverrides` map for state-dependent bits. (Rejected: callback slots —
not const/equatable, invite logic into style objects; `Tone?` slots — block
the "exact style" tier, the whole point of the escape hatch.)

**D6 — Degradation: ratified, later extended to three tiers (see §7).**
RGB downsamples automatically on a 256-color terminal; a 16-color terminal
re-expresses tones through a named ANSI-16 table instead of downsampling,
so a theme's identity survives a nearest-color search over only sixteen
slots; NO_COLOR re-expresses meaning through modifiers alone. All of this
lives at the projection, one place, so widgets never know which tier they
are running under.

**D7 — App-wide component themes: PARKED, confirmed.** Shared `const` style
objects cover it; revisit only if real apps prove that tedious. (Same
reasoning that parked Layer-3/`routeLoad` in the load work.)

---

## 9. Out of scope

- Focus *coordination* (who is focused, FocusEscapeCmd, Direction) — separate
  work; this spec only defines how focus *looks*.
- Search-match styling, scrollbar anatomy, combobox — they slot into Layer 4
  when they land; listed here only to show they don't touch `Theme`.
- Runtime theme switching mechanics (already works; tones don't change it).

## 10. Blast radius (for planning, not for fear)

`Theme` (rewrite), `StyleResolver` (rewrite), `WidgetState` (reorder + add),
every widget view/renderer in kiko_widgets (mechanical: pick projections,
grow style classes), every example (mostly deletions — the `focused ? a : b`
boilerplate dies), goldens re-blessed once. `Style`, `Buffer`, plume: untouched
— the paint substrate is fine; this is all about who decides what to paint.

## 11. Deviations at landing (this spec stays source of truth)

Recorded per the delivery plan (mikos 0135). Each is a judgment call the
implementation made; the reasoning is here so the next reader trusts the code
over a stale plan.

**Anatomy slots are pruned to real parts (§6).** ListView and TreeView get **no
`indicator` slot** — their `itemBuilder`/`nodeBuilder` owns every glyph, so a
slot would style nothing. TreeView gets **no `selectedItem`** (a tree has no
selection set) and does **not** re-declare `expandIcon`/`loadingIndicator`/
`errorIndicator` as style slots: the expand glyph stays on
`TreeViewModel.indicatorStyle` and the loading/error placeholder rows carry
their style on the existing `loadingIndicator`/`errorIndicator` `Line`s. This is
the plan's "align slot names, do not duplicate them" resolved toward *don't add
a second home*. Net anatomy: `ListViewStyle {item, selectedItem, cursorItem,
placeholder}`, `TreeViewStyle {item, cursorItem, placeholder}`.

**Button resting face = `primary.fill` (§5/§6).** A button is a primary action,
so its resting face is `theme.primary.fill`, and its states ride the built-in
matrix (focused → `focus.fill` + bold, loading → warning + blink, disabled →
dim) rather than per-widget default overrides. The prototype's `surface.fill`
resting + `primary.fill`-on-focus is gone, and so is the `widgetDefaults` map.

**Honest-state rename.** `ItemState.focused` and `NodeState.focused` (the record
passed to item/node builders) became `cursor`, matching `WidgetState.cursor`.

**NO_COLOR wiring is a process-wide default, not a threaded resolver (§7/D6).**
The plan said "Application constructs the resolver with the policy", but the
theme is *app-owned* (the runtime's `view` callback carries no theme; the app's
`ThemeSwitcher` holds it) and widgets build their own `StyleResolver(theme)`. So
the policy travels as a static `StyleResolver.defaultPolicy` that `Application`
sets once from the terminal color profile before the first frame — "one place,
widgets never know" preserved, via an ambient set-once process fact rather than
dependency injection. The resolver constructor is therefore no longer `const`.

**The D6 "reversed untested" gap was a real termkit bug.** `termlib`'s
`Style.render()` returned the text unchanged under `ProfileEnum.noColor`,
dropping bold/faint/reverse along with colors — so `Modifier.reversed` never
reached the terminal. Fixed upstream (termkit branch
`fix/nocolor-keeps-text-attributes`): the noColor profile now skips only the
color parameters; NO_COLOR forbids color, not styling. Ink-only states with no
modifier (`selection.ink` on a border, `error.ink`) therefore degrade to nothing
under NO_COLOR — accepted, because each required-distinguishable state
(selected/cursor/focused/disabled/error) stays visible through its **fill**
projection (reversed / dim / blink); a bare colored border losing its tint is
the same benign loss as a wash collapsing.

**Not done (documentation).** The four superseded specs the header names
(`theme-review.md`, `theme-action-plan.md`, `theme-expert-review.md`,
`theme-resolver-implementation.md`) no longer exist as files in the repo, so the
planned "add a superseded-by header to each" was moot — this header already
records the supersession.
