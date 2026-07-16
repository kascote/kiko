# ScrollView: scrolling composed content

The full reference for `ScrollView`/`ScrollViewModel`
(`lib/src/widgets/scroll_view/`). The boundary rules and traps live in
`../CLAUDE.md` (section "ScrollView & scrolling composed content"); this file
holds the details. Worked end to end in `example/scrollable_form.dart`.

ScrollView scrolls a composed region — a form, a settings panel, a sidebar —
built from ordinary Views, not a data widget. It wraps a plume `Viewport` node
(`kiko_core`'s `Viewport` View bridges it) instead of windowing a `DataView`;
the geometry half lives in plume, the scroll policy (offset, wheel, keys,
`ensureVisible`) in `ScrollViewModel`.

## Boundary: composed UI vs data

ScrollView lays its ENTIRE child out every frame (eager, O(content)) and clips
the paint — right for a form or a panel, wrong at data scale. List/Table/Tree
keep their lazy, windowed `DataView` for exactly that reason; a 100k-row list
stays on the data widgets, never inside a `ScrollView`. `ScrollViewModel` is
deliberately not `Loadable`.

## Content-area-only, and the chrome recipe

ScrollView tags only its own content area — no built-in border, scrollbar, or
help text; compose those around it. Because the whole content area is the hit
region, a wheel over a GAP between composed children already resolves to it —
no `Tagged` needed for that case. A border or other chrome drawn AROUND it is a
separate region no model owns, so it needs its own `Tagged(frameId, ...)` —
point that id at the SAME `ScrollViewModel` in your targets map (two ids, one
Component, is legal) and a wheel on the border scrolls the view exactly like
one over the content. `example/scrollable_form.dart`'s bordered frame is this
recipe.

## Wheel doctrine — uniform across every scrollable

Every scrollable (List, Table, Tree, ScrollView) declines a wheel notch that
would move nothing in that direction — the viewport is already at that edge —
and consumes any notch that moves it at all, even partially. Consuming
unconditionally at a limit would make nesting permanently dead; declining lets
the app offer the notch to the next scrollable ancestor out.

## `offerOutward`

`offerOutward(msg, ctx, targets)` (`lib/src/widgets/offer_outward.dart`) is the
ready-made version of that offer: it walks `ctx.hits.hitPath` from the
declining widget outward, offering the message to each enclosing id present in
`targets` (the SAME map your generic pointer-routing line already reads), and
returns the first `Handled` or a `Declined` if nobody answers. Only for a
positional `PointerMsg` — never call it for a
`PointerLeaveMsg`/`PointerCancelMsg`, neither carries a position to walk from.
A region the app handles directly, with no `Component` behind it, is not
reachable through `targets` — keep the inline `hitPath` walk for that case.

## `ensureVisible(id)` and the trap

`ensureVisible(id)` scrolls the minimum amount to bring a tagged descendant
fully into view — by tag, not index, so it works for ANY tagged content: the
Tab-walks-off-screen case and a scroll-to-invalid-field-on-validation-failure
case are the same call, just a different id. **Never** implement
scroll-to-focused (or scroll-to-anything) by reading `ctx.hits.rectOf(id)` — a
Viewport's presence-clipping (see `kiko_core/doc/mouse_routing.md`, "Viewports
and the hit map") makes a fully scrolled-off id answer `null` in exactly the
case that matters. The model's own tag-range map, refreshed each paint, is the
only correct source.

## Keyboard is `KeyBinding`-driven, never hardcoded

`ScrollViewAction` (`lineUp`/`lineDown`/`pageUp`/`pageDown`/`top`/`bottom`) +
`defaultScrollViewBindings` + a `KeyBinding<ScrollViewAction>? keyBinding` ctor
param defaulting to a copy — the identical pattern List/Table/Tree use. Users
remap, alias, or extend via `map`/`remove`/`unbind`/`addAll`. The keyboard path
sits behind the focus gate (a `ScrollView` only reads keys while focused); the
wheel does not — it scrolls whether or not the view owns focus, matching every
other scrollable.

## `getScrollState()`

Mirrors `TableScrollState` — `(offset, viewportRows, contentRows)` — for an
external scrollbar to read `progress`/`thumbSize` from. No built-in `Scrollbar`
widget ships; this is the seam a future one would consume.
