# Theming Widgets with Kiko

A recipe for styling a widget so it looks right by construction — in every theme,
and with colors stripped. The full reasoning lives in `specs/theme-doctrine.md`;
this is the short version you follow while writing a widget.

The model in one line: **states pick tones, parts pick projections.** A theme owns
a dozen color identities (`Tone`s); a widget owns its parts (anatomy); the resolver
turns "which state, which part" into paint. You never paint a color directly.

## 1. Classify each part of your widget as ink / fill / wash

A `Tone` is a color pair `(color, on)` — it is **not paintable**. It becomes a
`Style` only through a *projection*, and the projection is chosen by what the part
is, not by the tone:

| Projection | Produces            | Use for                                            |
| ---------- | ------------------- | -------------------------------------------------- |
| `ink`      | `fg` only           | line glyphs, separators, scrollbars, accent text   |
| `fill`     | `fg: on, bg: color` | filled surfaces: selected rows, button faces, badges |
| `wash`     | `bg` only           | tints *under* existing content: a crosshair row/column |

`wash` is the one to remember: it changes background only, so a cell keeps whatever
foreground it already had (a custom `render` that colored a number red stays red
under the wash).

List every part of your widget and write down its projection. That table is the
spec for the next two steps.

## 2. Define an `XStyle` anatomy class

Publish your parts as a class of **nullable `Style?` slots**. `null` = derive from
the theme by a documented rule; non-null = the caller's exact style, which wins
verbatim. Copy `TableViewStyle` (`table_view/types.dart`) as the template — the
derivation table goes in the doc comment and *is* the widget's styling contract:

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

Hold the anatomy on the model as a mutable `styles` field (default `const
FooViewStyle()`), the way `TableViewModel.styles` does, so an app can swap the look
at runtime.

**Only give a slot to a part you actually paint.** ListView and TreeView have no
`indicator` slot because their `itemBuilder`/`nodeBuilder` owns every glyph — a slot
that styles nothing is dead. And don't duplicate a part that already has a home:
TreeView keeps its expand glyph on `indicatorStyle` and its loading/error
placeholder text on the `loadingIndicator`/`errorIndicator` `Line`s (which carry
their own style), so `TreeViewStyle` doesn't re-declare them.

## 3. Resolve states through `StyleResolver` with the right `PaintClass`

For each part, fall back from the slot to the resolver. The resolver maps `(state,
PaintClass)` through the built-in matrix — states pick tones, you pass the class:

```dart
late final _resolver = StyleResolver(theme);

Style _selectedItemStyle() =>
    model.styles.selectedItem ?? _resolver.resolve(null, const {WidgetState.selected}, overrides: styleOverrides);

Style _cursorItemStyle() =>
    model.styles.cursorItem ?? _resolver.resolve(null, const {WidgetState.cursor}, overrides: styleOverrides);
```

`resolve` defaults to `PaintClass.fill` (the surface case). Pass `cls:
PaintClass.wash` for a tint, `cls: PaintClass.ink` for chrome. Layer parts by
patching in the matrix's priority order — base → selected → cursor → disabled —
each `Style.patch` over the last, so the cursor stays visible over a selected run
and disabled dims everything:

```dart
var s = model.styles.item ?? const Style();
if (isSelected) s = s.patch(_selectedItemStyle());
if (isCursor)   s = s.patch(_cursorItemStyle());
if (isDisabled) s = s.patch(_resolver.resolve(null, const {WidgetState.disabled}));
```

For box borders use the `border` helper — it is the fix for the hand-rolled
`focused ? theme.focus : theme.border` that used to live at every call site:

```dart
borderStyle: resolver.border({if (model.focused) WidgetState.focused})
```

### Use honest states

The keyboard cursor position is `WidgetState.cursor`, **not** `focused` or `hover`.
`focused` means *the widget owns keyboard input*; `hover` is *the mouse is over it*
(mouse only). Borrowing one of those for "the current row" is the mistake the
anatomy model exists to prevent — if a fact is "which item is current", it is
`cursor`.

## 4. Never paint a `Tone` directly

`theme.selection` is not a `Style` and won't type-check where paint is expected —
that is deliberate. It stops a fill's background from bleeding onto border glyphs (a
selected pane border is `selection.ink`, a selected row is `selection.fill` — same
tone, different projection).

A **derived** border therefore never carries a background — pass `resolver.border`
(or a `.ink`) to `Box.borderStyle`. An **explicit** `Style(fg: …, bg: …)` handed to
a border is a deliberate design choice (a filled dialog frame, a status strip) and
is always allowed. `Box` takes a plain, unrestricted `Style`; the theme-awareness
lives one level up in the resolver.

## 5. Expose per-state `styleOverrides`

Take an optional `Map<WidgetState, Style>? styleOverrides` and thread it into every
`resolve` call. It is the per-instance escape hatch for state-dependent bits (one
row blinks on the app's signal) without a whole custom `XStyle`.

## 6. NO_COLOR is free

You don't handle it. The resolver carries a `RenderPolicy`; under a `NO_COLOR`
terminal it re-expresses meaning through modifiers in one place — `fill →
Modifier.reversed`, `ink →` its modifiers with the color dropped, `wash →` nothing
(a crosshair correctly collapses to the cursor cell). `Application` sets the policy
from the terminal profile before the first frame, so every `StyleResolver(theme)`
you build adopts it automatically. Just route through the resolver and a selected
row stays visible when its color is stripped.

## Which knob serves which user

| user                                  | touches                                            |
| ------------------------------------- | -------------------------------------------------- |
| "make it look right"                  | nothing — derived defaults                         |
| "my colors everywhere"                | the ~12 tones of a `Theme`                         |
| "this table gets an orange crosshair" | `XStyle(...)` on that instance                     |
| "every table in my app is custom"     | a shared `const appTableStyle = TableViewStyle(…)` |
| "one row blinks on my signal"         | per-state `styleOverrides` / a custom `render`     |

If you can serve all five without the author fighting the framework, the widget is
themed correctly by construction.

---

MVU, events, and focus: see the root `CLAUDE.md`. Theme doctrine and rationale:
`specs/theme-doctrine.md`.
