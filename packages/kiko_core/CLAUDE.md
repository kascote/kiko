# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiko is a Dart framework for building terminal user interfaces: double-buffered rendering, a Bubble Tea-style Model-View-Update runtime, and Flutter-style layout via the `plume` package. It began as a port of [Ratatui](https://ratatui.rs/) and has since diverged into its own design.

## Commands

```bash
make test          # run all tests
make testf FILE=test/foo_test.dart  # single test
make lint          # static analysis
make format        # format code
make cover         # coverage report
```

## Architecture

**Core rendering flow:**

1. `Terminal` manages double-buffered rendering via two `Buffer` instances
2. `Terminal.draw()` accepts callback receiving `Frame`
3. UI is composed from `View`s; `View.build()` inflates a fresh plume `Node` each frame, and `frame.render(view)` lays it out and paints it
4. `Buffer.diff()` computes minimal changes between frames
5. `Backend` (abstract) handles actual terminal I/O

**Key components:**

- `Buffer` - grid of `Cell`s (grapheme + fg/bg/modifiers)
- `Container` (plume) - borders/titles/padding around a child
- `Line`/`Text` - styled text primitives (Views)

**Layout** is handled by the `plume` package — a Flutter-style box model (constraints
down, sizes up), no constraint solver. See `packages/plume/README.md`.

**Dependencies:** plume (layout), termlib (terminal control), termparser (input), termunicode (width)

## Docs — read on demand

Full stories live in `doc/`; open the one covering what you're touching:

- `doc/mouse_routing.md` — hit-map semantics, viewport clipping, capture terminators, the worked dispatch example.
- `doc/event_scheduling.md` — the unified event queue, coalescing, stale-frame dropping.

Cross-package: theming rationale in `specs/theme-doctrine.md`, theming recipe + widget anatomy in `docs/theming-widgets.md`, widget testing in `docs/widget-testing.md` (all at the repo root).

## The Backend Seam

`Backend` (`src/backend/backend.dart`) is the whole surface `Terminal` and `Application`
use to reach a terminal. Two implementations: `TermlibBackend` (real, needs a TTY, not
exported) and `TestBackend` (in-memory, `package:kiko/testing.dart`).

- **One coordinate space above the seam.** A backend delivers events in **0-based buffer
  cells** and accepts draw/cursor calls in 0-based buffer cells. Terminals number from 1;
  that is `TermlibBackend`'s private business, and it translates on the way in and out.
  Never re-introduce a 1-based coordinate above the backend.
- **No foreign types cross it.** `Backend.profile` is kiko's own `ColorProfile`, mapped
  from termlib's `ProfileEnum` at the edge. `TestBackend` imports no termlib.
- **Testing.** `Terminal.create({Backend? backend})` and
  `Application({@visibleForTesting Backend? backend})` both take an injected backend, so the
  render loop and the full MVU drain run under `dart test`. `TestBackend` keeps a `screen`
  buffer that every `draw` applies onto (assert what was *rendered*), a `lastDiff` (assert
  the double buffer redrew only what changed), and `emit(event)` to drive the loop. It is
  **not a terminal emulator**: it parses no escape sequences, and every call but `draw` is
  recorded, not simulated. See `test/terminal_test.dart` and `test/application_test.dart`.
- **`Backend.dispose()` flushes.** The framework never calls `exit()` — `Application.run`
  completes with the exit code on every path, and terminating the process is the caller's
  line (`exit(await Application(...).run(...))`). `dispose()` flushes pending output, closes
  nothing, and exits nothing; `TermlibBackend.dispose` flushes termlib's sink before
  disposing the terminal, since termlib writes through `dart:io stdout`'s async buffer and an
  app-side `exit()` right after `run()` could otherwise truncate the terminal-restore bytes
  this backend just wrote.

## Text measurement

One `TextMeasurer` — a `TermUnicodeMeasurer` by default — rules the whole session:
`Application(measurer:)` / `Terminal.create(measurer:)` own it, `Buffer` carries it
(`buffer.measurer`), and `Frame.render(view)` takes no measurer of its own — it lays out
and paints through `buffer.measurer` every time. That is what makes layout and paint agree
on every glyph's width; a terminal's ambiguous-width behavior does not change mid-run, so
this is fixed for the life of the application, never passed per call. Widgets that measure
text reach the same ruler at layout time, via `LayoutContext.measurer` (a plume `Node`'s
`performLayout`) or the model field it is copied into (`TextInputModel.measurer`,
`TableRenderer.measurer`, and siblings) — never a bare `TermUnicodeMeasurer()` call or raw
termunicode width math.

## Resize events

A window resize reaches `update` as `ResizeMsg` — `width`/`height` in cells plus
`widthPixels`/`heightPixels` (0 when the terminal does not report pixel dimensions, which
most terminals do not). `Application` enables resize reporting **unconditionally** at
startup, with no constructor flag: the backend owns the choice between in-band reporting and
a signal fallback, seeded by the one-time probe in `Backend.init()`, and callers never see
which mechanism fired. A resize is position-valued, so several queued resizes coalesce to
the latest.

The enable-time size report that in-band mode sends back is startup noise, not a real resize;
`MvuRuntime.flushStartupEvents` drops any resize held before the first frame commits. A
resize emitted after that reaches `update` normally.

Rendering never depends on any of this: `Terminal.draw` polls the backend's size before
building every frame, as the correctness backstop on terminals that report no resize events
at all. `ResizeMsg` is purely informational — the app uses it to react (recompute a scroll
clamp, reflow content), never to make resizing work. See `example/resize.dart`.

## Keyboard contract

A `KeyMsg` **is** a keystroke — a press, or an auto-repeat (`repeat: true`) from a key
held down; a plain terminal that cannot report repeats redelivers the held key as ordinary
presses with `repeat: false`, so nothing may depend on that flag being accurate. A key-up
is a different class, `KeyReleaseMsg`, and a bare modifier tap (Shift alone, no other key
involved, kitty-only) is `ModifierKeyMsg` — both are structurally incapable of matching a
`case KeyMsg(key: ...)` pattern, so no widget or app code needs a transition check. The
one-line rule for everything downstream: **bind on `key`, insert `text`, never derive one
from the other** — `key` is the canonical spec string (`'ctrl+a'`, `'q'`, shift folded in:
`'A'`, `'!'`, `'shift+tab'`); `text` is the literal text the keystroke types, null for
named keys and ctrl/alt chords.

`KeyBinding.map` canonicalizes every spec through the parser round-trip, so `'shift+a'`
and `'A'` register as the same binding regardless of which form a caller writes.
`KeyBinding.resolve` accepts both press and repeat (a held arrow or backspace keeps
resolving to its action for as long as it repeats), and falls back from `key` to
`baseKey` — the spec projected onto the key's standard-US-layout position — on a primary
miss, so a shortcut bound to `'ctrl+z'` still fires from Ctrl+Я on a Cyrillic layout.

`Application(keyboardEnhancement: bool?)` controls the kitty keyboard protocol request
and defaults to `null` — automatic: the full protocol is requested when the startup
capability probe confirms the terminal supports it, and a terminal that fails the probe
gets plain behavior with no further ceremony. `false` always forces it off; `true` forces
the request regardless of what the probe found. Apps should generally leave this unset.

The enhancement, wherever it is active, only **adds** fidelity to the contract above —
exact typed text instead of a guess, `repeat` marked accurately instead of resent as plain
presses, releases and bare modifiers reported instead of invisible — it never changes how
a correctly written handler behaves. Concretely: not one example app needed a code change
when the enhancement went from breaking typing to working in full.

## Mouse: the Hit Map and the Router

A mouse event reaches `update` **already resolved** — it knows which widget it belongs to,
where it landed in that widget's own cells, and what it was. Nothing above the router
hit-tests, and no app stashes a frame to do it. The widget half (what a model does with a
resolved pointer) is `kiko_widgets/CLAUDE.md`'s "Widget mouse handling"; the full framework
story — rationale, edge cases, worked dispatch example — is `doc/mouse_routing.md`. The
rules that must survive any edit:

- **0-based buffer cells everywhere above the backend** — the same space as
  `Rect`/`Buffer`/`Position`. `local = global - targetRect.topLeft`. `local.x` is a display
  **column**, not a grapheme index; map column→grapheme with the session measurer (see
  "Text measurement" above), never a bare termunicode call.
- **No termparser type crosses into any `Msg`.** `PointerMsg`, `FocusMsg` and `PasteMsg`
  store kiko's own `PointerButton`/`PointerAction`/plain fields, mapped from the terminal
  event exactly once at intake (`mouse_router.dart`'s `pointerFieldsFrom`, `msg.dart`'s
  `eventToMsg`) — nothing downstream imports termparser to read one.
- **`HitMap` (`src/widgets/hit_map.dart`) is the only hit-testing type**: `hitId`, `rectOf`,
  `hitPath`. Which frame a map describes is carried by which map you hold: `frame.hits` =
  the frame being painted (use in `view`); `ctx.hits` = the committed frame the event saw
  (use in `update`). `update` never receives the writable `Frame` — only the read-only
  `UpdateContext` (`hits` + `area`).
- **Where you put `Tagged(id, child)` decides what `local` means** — tag a bordered box and
  clicks count from the border; nothing downstream compensates. An id names exactly one
  node per frame (asserted at `HitMap` construction).
- **A tag answers *which widget*; a hit region answers *which part*.** A view marks its
  discrete parts (rows, a header, an indicator) while painting via `RenderNode.markRegion`;
  the router resolves the innermost marked `Region` under the pointer — one `regionAt` walk
  of the target's own subtree — and delivers it on `PointerMsg.region` (nullable, opaque,
  scoped so a widget only ever sees its own). `region` is the default for discrete parts;
  `local` stays for continuous surfaces (a wrap-aware caret) and is never legacy. Full story:
  `doc/mouse_routing.md`, "Hit regions".
- **A `Viewport` clips hit *presence*, not *geometry*.** A fully scrolled-off tagged widget
  is absent from the map (`rectOf` → null); a partially visible one answers its full,
  unclipped placement rect. Therefore **never scroll something into view by reading
  `ctx.hits.rectOf(id)`** — it is null exactly when it matters; scroll-to-widget is model
  arithmetic (`ScrollViewModel.ensureVisible`, in `kiko_widgets`).
- **A `Flexible`/`Expanded` under an unbounded main axis throws an always-on `StateError`**
  — a flex child inside a scroll viewport has no bounded space to take a share of.
- **Capture is implicit and single-slot**: a press hands the pointer to whatever was under
  it — `null` included — until the button comes up. `up` ends the interaction;
  `PointerCancelMsg` ends it and means *do not commit*. **The wheel bypasses capture** and
  is never coalesced (a notch is a delta); moves and drags carry a position, so they
  coalesce.
- **Leave, no enter**: the router synthesizes `PointerLeaveMsg` only — the first
  `PointerMsg` addressed to a widget *is* the enter. No `Hoverable` interface; hover is the
  owning model's own field.
- **Dispatch is app-side and id-keyed.** `PointerMsg`/`PointerLeaveMsg`/`PointerCancelMsg`
  implement `Routed`; the app forwards by `targetId` into the same `update(Msg)` the
  keyboard uses (keyboard = one focused target; mouse = a `Map<String, Component>`). Events
  deliver to the innermost target only; bubbling is app-side via `ctx.hits.hitPath` plus
  the decline convention. `kiko_widgets`' **`FocusRouter` packages this whole pattern**
  behind one `route()` call — `example/mouse_dispatch.dart` is the hand-rolled primitive
  underneath it.
- **The one real hazard**: reading a rect in `update` to *anchor* something painted this
  tick against last tick's layout. Resolving a click against committed pixels is correct;
  anchoring belongs in `view`, where `frame.hits` describes the tree being painted.

See `example/mouse.dart` (capture, leave, cancel) and `example/mouse_dispatch.dart`
(one-line routing).

## MVU Identity & Addressing

- `Component` (`src/mvu/focus.dart`) is the widget-model contract: `UpdateResult update(Msg)`
  **plus `String get id`**. `update` reports whether the model consumed the message —
  `Handled` (carrying an optional effect `Cmd`) or `Declined` — never a bare `Cmd?`. The `id`
  is the model's stable identity; widget→app commands carry it as their address. A focus-only
  model still has an `id` — addressing is just one _use_ of identity.
- `autoId(String prefix)` (`src/mvu/auto_id.dart`) mints human-readable ids (`'tableview-1'`)
  from a single shared monotonic counter, used when a model is constructed without an
  explicit id. It is a **sequential per-isolate counter**: auto ids are **not stable across
  runs and not unique across isolates** — fine, because ids never cross isolates by design.
  Pass an explicit id when matching must survive a restart. `resetAutoIdCounter()` is
  `@visibleForTesting`.

## Theming types live here

`Theme`, `Tone`, `StyleResolver`, `WidgetState` and `KeyBinding` are kiko_core code, but
the styling doctrine is documented where it is consumed: `specs/theme-doctrine.md` (the
model and its never-rules), `docs/theming-widgets.md` (the recipe and per-widget anatomy),
and `kiko_widgets/CLAUDE.md` (the doctrine summary). Touch `style_resolver.dart`,
`theme.dart` or `tone.dart` only with those open.

## Code Style

- Uses `very_good_analysis` lints
- Strict casts/inference/raw-types enabled
- `public_member_api_docs` required
