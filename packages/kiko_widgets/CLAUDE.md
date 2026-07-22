# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

Higher-level widgets package for Kiko TUI framework. Depends on `kiko_core` for rendering primitives.

See root `/CLAUDE.md` for monorepo commands (`make test`, `make lint`, etc.) and core architecture.

## Docs — read on demand

Full stories live in `doc/`; open the one covering what you're touching:

- `doc/async_loading.md` — the keyed load-slot machine: primitives, per-widget map, worked handler.
- `doc/scroll_view.md` — ScrollView in full: boundaries, chrome recipe, `offerOutward`, `getScrollState`.

Cross-package: the widget-authoring tutorial (model + view + mouse, worked end to end
over `example/custom_widget.dart`) in `docs/building-widgets.md`, theming recipe +
per-widget anatomy in `docs/theming-widgets.md`, theming rationale in
`specs/theme-doctrine.md`, widget testing in `docs/widget-testing.md` (all at the repo
root). The mouse framework half (router, hit map, capture) is `kiko_core/CLAUDE.md` +
`kiko_core/doc/mouse_routing.md`.

## Shipped widgets

- `TextInput` / `TextInputModel` — single-line text input, readline keybindings
- `TextArea` / `TextAreaModel` — multi-line editor (wrap-aware caret, selection)
- `ListView`, `TableView`, `TreeView` — windowed data widgets (lazy; see Async Loading)
- `Button` / `ButtonModel` — emits `ButtonPressCmd`
- `ScrollView` / `ScrollViewModel` — scrolls composed content (see below)
- `ModalModel` + `modalDialog(...)` — `modalDialog` frames ANY content as a bordered,
  tagged dialog; `ModalModel` exists only for the static confirm/cancel shape (Enter →
  `ModalConfirmCmd`, Escape → `ModalCancelCmd`). The app owns whether a modal is open
  (typically a nullable model field); a dialog with its own state renders its own model as
  the content — no wrapper.
- `FocusRouter`, `FocusSlot`, `focusOnPress`, `routeToTarget`, `offerOutward` — focus and
  pointer-dispatch glue; `FocusRouter` packages the whole dispatch doctrine behind one
  `route()` call. See **FocusRouter** below.

## Widget Pattern

Kiko models are **mutable components** (Bubble Tea style, not Elm) — see root `CLAUDE.md`. Widget models mutate in place.

Two update shapes coexist, asymmetric by design:

- **App update** — `(M, Msg, UpdateContext) → (M, Cmd?)`: keeps a model slot so small value-like app models _may_ stay immutable.
- **Widget update** — `UpdateResult update(Msg)`: always mutable, so it returns no model — only whether it consumed the message (`Handled`, carrying an optional effect `Cmd`) or not (`Declined`). A parent switches on the result; a `Declined` message is still in flight and can be offered to the next candidate.

Widgets follow MVU (Model-View-Update):

```dart
// Model holds state + config
class TextInputModel {
  UpdateResult update(Msg msg) { ... }  // reports Handled (with optional Cmd) or Declined
}

// Widget is a stateless View, built from the model
final class TextInput implements View {
  final TextInputModel model;
  Node build() { ... }
}
```

Usage in app's update/view:

```dart
update: (model, msg, _) {
  return switch (model.textInput.update(msg)) {
    Handled(:final cmd) => (model, cmd),  // consumed → run its effect
    Declined() => (model, null),          // not consumed → try app keys, or fall through
  };
}
view: (model, frame) {
  frame.render(TextInput(model.textInput));
}
```

## Widget→App Addressing

Some widget commands are **events the app must intercept**, not runtime effects:
`TableActionCmd`, `ListActionCmd`, `TreeExpandCmd`, `TreeCollapseCmd`, `TreeActionCmd`,
`ButtonPressCmd`, plus the shared `LoadRequest` (List/Table/Tree page and child fetches;
see **Async Loading** below). They travel **up** the call stack to the app's `update`.
Every one addresses its owner by a **stable `String id`** carried by value.

Non-obvious rules a contributor will otherwise miss:

- **Address by `id`, not by reference or by command type.** The app resolves a command to
  its owner by matching the id (`id == model.table.id`), or via a `Map<String, …>` registry
  for N instances. Never disambiguate by `identical(...)`, and never assume one instance per
  command type.
- **Async effect results must carry the id home.** When the app fires a `Task` in response
  to a `LoadRequest(id, key)`, thread both the `id` _and_ the `key` into the _result_
  message (`onSuccess: (data) => LoadResult(id, key: key, data: data)`) and route the
  receipt by `r.id`. This is the **most-forgettable rule** — omit it and the app is
  silently single-instance-only.
- **Derive collection ids from stable domain keys (`user.id`), never the list index.**
  Indexes shift on insert/delete, so an index-derived id routes a result onto the wrong row.
- **Widgets never perform async I/O.** The app drives _every_ fetch via `Task` and routes
  the result home by id; a widget signals "I need data" by _returning a `LoadRequest`_, not
  by fetching. It is tempting to `await dataSource.getChildren(...)` inside the widget —
  don't: that loses the runtime cancellation token and races the message loop.
- **An id that resolves to no owner is logged + dropped, never silently ignored** — the
  observable failure that reference-addressing could not give you.

## Widget keyboard handling

A widget resolves its own keyboard behind the focus gate — `if (!focused) return const
Declined();` — the shape worked end to end in `docs/building-widgets.md`. The rules:

- **Resolve bindings first.** Route `key` (and its repeats) through a
  `KeyBinding<Action>` table (`ButtonAction`, `TextInputAction`, …) so an app can rebind
  without touching the model; a raw `switch` on `key` is fine for something small enough
  that a table would be overkill.
- **Editors insert `msg.text`, never `msg.key`.** Once nothing binds, an editable model
  falls through to inserting `text` — the literal text the keystroke types, already
  shift- and layout-resolved by the terminal. `text` is null for named keys and ctrl/alt
  chords, so the fallthrough naturally does nothing for `tab` or `ctrl+s`.
- **Decline `KeyReleaseMsg` and `ModifierKeyMsg`.** Neither carries a binding or
  insertable text; a widget that adds no special case for them declines by falling
  through the same tail every unbound key does. The shared suite
  `test/widgets/decline_unknown_test.dart` covers both for every shipped model — add a
  new widget to that suite rather than writing a one-off release/modifier test.
- **Never check a press/repeat/release transition.** `KeyMsg.repeat` is informational
  only — do not gate behavior on it, since a terminal without the kitty enhancement
  never sets it. The three message classes already make a release or a bare modifier
  edge unreachable from a `KeyMsg` pattern, so there is nothing to track between
  messages.

## Widget mouse handling

A widget CONSUMES the resolved `PointerMsg` the framework delivers. The framework half —
router, hit map, capture, leave/cancel — is `kiko_core/CLAUDE.md` ("Mouse") and its
`doc/mouse_routing.md`; read those first. Worked end to end in `example/mouse_widgets.dart`
and `example/scrollable_form.dart`. The rules:

- **The pointer branch sits ABOVE the focus gate.** `if (!focused) return const Declined();`
  gates only the keyboard: a wheel scrolls, a click selects, a hover highlights whether or
  not the widget is focused, so the pointer (and leave/cancel) arms run above that line.
- **Consume with `Handled`, refuse with `Declined` — the rule that gets forgotten.** A
  blanket `return const Handled()` silently kills app-side bubbling: a wheel a `TextInput`
  cannot use must come back `Declined()` or it never reaches the scrollable around it.
  Decline every pointer you do not consume.
- **Click emits the keyboard's command.** The widget moves its cursor to the clicked row
  and returns the SAME id-addressed command Enter returns; the app cannot tell which device
  fired it. A widget NEVER emits a focus command — moving focus on a press belongs to
  whoever owns the `FocusGroup`: `FocusRouter` (or `focusOnPress`) does it in one line.
- **Hover is a plain model field** (`int? hoverRow`), set from the pointer's `local` in
  `update`, folded into the `WidgetState` set in `build`, cleared by `PointerLeaveMsg`.
  There is no enter message — the first `PointerMsg` addressed to the widget IS the enter.
- **Scrolling rides `ScrollableModel`** (`lib/src/widgets/scrollable_model.dart`):
  `scrollOffset`/`visibleCount`, `scrollBy(rows)` (clamped, returns rows actually moved),
  `localToRow(local)` (sticky header and indent accounted for), `wheelScrollLines` (3). A
  wheel notch moves the VIEWPORT and leaves the cursor; the next keypress snaps the
  viewport back (Vim behaviour). Near-edge scrolling triggers the same load threshold as
  cursor navigation.
- **Wheel doctrine, uniform across every scrollable** (List, Table, Tree, ScrollView): a
  notch that would move nothing in its direction — `scrollBy` returned 0 at that edge — is
  `Declined()`, per-direction; any notch that moves at all, even partially, is consumed.
  This is what makes nested scrolling work: the inner scrollable at its limit declines,
  and the app (via `offerOutward` or `FocusRouter`) offers the notch to the next scrollable
  ancestor out.
- **Widgets self-tag** (`..tag = model.id` in `build`) — routing is free the moment
  `mouseEvents: true`. `Tagged(id, child)` is only for regions the APP composes that no
  model owns. Never wrap a self-tagging widget in a `Tagged` of a different id — it
  relocates the id, and the same id on two nodes trips the one-tag-per-frame assert.

## FocusRouter

`FocusRouter` packages the app-side interaction glue — focus traversal, click-to-focus,
pointer dispatch, chrome aliases, declined-pointer bubbling — behind one `route()` call
made as one arm of the app's `update`. It owns none of the widgets it routes to: the
`FocusGroup`, `extras` and `aliases` are held by reference and re-read every call, so
there is no registration step. Simplest wiring: `example/text_input.dart`; everything at
once: `example/scrollable_form.dart`; the hand-rolled primitive underneath it:
`kiko_core/example/mouse_dispatch.dart`.

**The routing contract: route by address, never by message class.** `route()` has three
arms, and only three:

1. A `KeyMsg` is resolved against the traversal `bindings` first — the traversal channel
   is reserved, which is what keeps a consume-everything widget escapable. An unbound key
   goes to the focused member.
2. Pointer traffic (`Routed`) goes to its addressed target — members and `extras` by id,
   chrome via `aliases`. A background press or unknown id declines; positional traffic is
   never re-aimed at the focused member.
3. **Everything else goes to the focused member and its verdict returns as-is** — paste,
   a future input class, a message the router has never heard of. The router never
   decides for a widget which messages it can handle; that is the widget's
   `Handled`/`Declined` verdict, and `Declined` means nothing consumed it, so it is
   still the app's.

The contract rests on one discipline: **a widget consumes only what it understands and
declines everything else.** A catch-all `Handled` tail turns a widget into a black hole
for messages that were never its business (`test/widgets/decline_unknown_test.dart` pins
this for every model — keep new widgets in that suite).

**Calling convention** — the order of arms in the app's `update`:

1. Domain messages first: widget→app commands and async results the app must intercept.
2. Any app-level pre-route intercepts — a message the app wants before a widget sees it
   (rare; prefer switching on the `Handled(cmd)` the router returns).
3. The one delegate line: `switch (model.router.route(msg, ctx))`.
4. Fallback keys on `Declined` only — they run for input every widget declined, so a
   quit key can never fire while someone is typing into a focused editor.

**Escape hatches, in escalation order** — the router has no feature flags; each hatch is
composition:

- `bindings:` — extend or replace the traversal keys (`defaultFocusBindings()` is
  Tab/Shift+Tab; add jumps with `..map(['alt+1'], const FocusTo('sidebar'))`).
- `extras:` — components reachable by pointer but never by focus (a wheel-only scroll
  surface, a status strip).
- `aliases:` — chrome stands in for the member it decorates (below).
- `onFocusChange` — the single funnel for every focus move, keyboard or click alike
  (scroll-the-focused-field-into-view lives here, and nowhere else).
- `clickToFocus: false` — presses deliver without moving focus.
- Copy the assembly — the pieces are public: `focusOnPress` + `routeToTarget` +
  `offerOutward`, and the focused path is the one line `focus.focused.update(msg)`.
  `focus_router.dart` is deliberately one readable file; it IS the reference assembly.

**Chrome aliases re-address, never forward raw.** An alias entry maps a chrome id (a
border, a title row — tagged by the app, never a member itself) to the member it
decorates. A press on chrome click-focuses the member, and the pointer is rebuilt
against the member's committed rect: `targetId`, `local` and `targetRect` all describe
the member (a border cell above the content yields a negative `local.y` — correct, not a
bug). A leave or cancel via alias delivers verbatim — it carries no position to rebuild
from. `FocusSlot` rounds out the group: a focusable placeholder that declines
everything, giving a widget-less pane a place in the focus order.

## ScrollView & scrolling composed content

`ScrollView`/`ScrollViewModel` (`lib/src/widgets/scroll_view/`) scrolls a composed region —
a form, a settings panel — built from ordinary Views, not a data widget. Full story:
`doc/scroll_view.md`; worked example: `example/scrollable_form.dart`. The rules:

- **Composed UI only, never data scale.** ScrollView lays its ENTIRE child out every frame
  and clips the paint — right for a form, wrong for 100k rows. Data stays on the windowed
  List/Table/Tree; `ScrollViewModel` is deliberately not `Loadable`.
- **It tags only its own content area** — no built-in border/scrollbar/help; compose chrome
  around it. Chrome needs its own `Tagged(frameId, …)` pointed at the SAME model in your
  targets map (two ids, one Component, is legal) so a wheel on the border still scrolls.
- **`ensureVisible(id)` scrolls a tagged descendant into view — by tag, not index.** Never
  implement it (or scroll-to-focused) by reading `ctx.hits.rectOf(id)`: presence-clipping
  answers null exactly when it matters. The model's own tag-range map, refreshed each
  paint, is the only correct source.
- **Keyboard via `KeyBinding<ScrollViewAction>`** (the same pattern List/Table/Tree use),
  behind the focus gate; the wheel is not. `getScrollState()` feeds an external scrollbar.

## Async Loading

ListView, TableView and TreeView load data the **same way**: one keyed load-slot state
machine in `lib/src/load/`, shared by all three. Full reference — primitives, per-widget
map, worked handler: `doc/async_loading.md`. The doctrine extends Widget→App Addressing
above — a load is an id-addressed request whose result must come home. The contract:

- **The widget owns the state machine; the app owns the I/O.** Slots are named by typed
  sealed keys (`ListLoadKey.self`, `TableLoadKey.{forward,backward}`, Tree's
  `RootsKey()`/`PathKey(path)`), each `idle → loading → error`; success clears back to
  idle. The widget flips a slot → loading the instant it returns the `LoadRequest` (the
  self-dedup lives inside the widget, not in an app-side guard), and → idle/error when
  `applyLoad` receives the matching `LoadResult`. The id-guard and the staleness guard
  ("is this key still expected?") both live inside `applyLoad` — a late result for a
  collapsed branch drops.
- **`DataView.itemAt` MUST NOT await — reads are synchronous by contract.** "Data not here
  yet" is tracker state + a placeholder, never an awaited read. Reads go through
  `DataView<T>` (sync, read-only); mutation lives only on the concrete `DataBuffer<T>`;
  the fetcher is an app-owned closure, never a model field.
- **The app is only the I/O ferry**: see the `LoadRequest`, fire a `Task`, thread **both
  `id` and `key`** into the `LoadResult`, route the receipt with one generic line
  (`if (msg case final LoadResult<Object?> r)` → `applyLoad` by id). The only per-widget
  code is the request→fetch mapping.
- **Total count is exempt by design**: a TableView app-fired one-shot with no slot — a
  missing count is benign (indeterminate scrollbar), not a failure to recover from.

## Theming

Every widget is styled the same way: **states pick tones, parts pick projections.** A
`Theme` owns ~12 color identities (`Tone`s); a widget owns its parts (anatomy); the
`StyleResolver` turns "which state, which part" into a `Style`. Rationale:
`specs/theme-doctrine.md`. Recipe + per-widget anatomy reference: `docs/theming-widgets.md`.

The four layers:

- **Tone** — a color pair `(color, on)`, **not paintable**. Project it with `.ink` (fg
  only), `.fill` (`fg: on, bg: color`), or `.wash` (bg only). The *part* picks the
  projection: a selected border is `selection.ink`, a selected row is `selection.fill` —
  same tone, no bg bleed onto the border glyphs.
- **WidgetState** — declaration order is priority order (later wins): `hover < selected <
  cursor < focused < unfocused < loading < error < disabled`.
- **StyleResolver** — `resolve(base, states, {cls, overrides})` walks the matrix (defaults
  to `PaintClass.fill`); `border(states)` replaces every hand-rolled
  `focused ? theme.focus : theme.border`.
- **Anatomy** — an `XStyle` class of nullable `Style?` slots on the model; `null` derives
  from tones by a doc-comment table, non-null wins verbatim. `TableViewStyle` is the
  template.

The never-rules:

- **Never borrow a state for the cursor.** The keyboard-current item is
  `WidgetState.cursor`; `focused` = the widget owns input; `hover` = mouse-over.
  `ItemState`/`NodeState` (passed to item/node builders) expose `cursor` — the honest
  current-item flag.
- **Never paint a `Tone` directly** — it won't type-check where paint is expected; project
  it, or a fill's bg bleeds onto chrome.
- **Never give a slot to a part you don't paint**, and never duplicate a part that already
  has a home (Tree's expand glyph stays on `indicatorStyle`).
- **Never hand a derived bg to a border.** Pass `resolver.border(...)` (an ink) to
  `Container.borderStyle`; an *explicit* `Style(fg:, bg:)` on a border is a deliberate
  choice and fine.
- **Never handle NO_COLOR or ANSI-16 yourself.** `Application` sets
  `StyleResolver.defaultPolicy` from the terminal's color profile (full RGB, a
  16-color terminal's named `Theme.tones16` table, or NO_COLOR's modifiers-only
  re-expression); route through the resolver and every tier is free.

## Code Style

Same as root: `very_good_analysis`, strict mode, `public_member_api_docs` required.
