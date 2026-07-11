# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiko is a Dart port of [Ratatui](https://ratatui.rs/) - a Rust TUI framework. Builds terminal user interfaces using a double-buffered rendering approach.

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
3. Widgets implement `Widget.render(Rect area, Buffer buffer)`
4. `Buffer.diff()` computes minimal changes between frames
5. `Backend` (abstract) handles actual terminal I/O

**Key components:**

- `Buffer` - grid of `Cell`s (grapheme + fg/bg/modifiers)
- `Block` - base widget for borders/titles/padding
- `Line`/`Text` - styled text primitives (Views)

**Layout** is handled by the `plume` package — a Flutter-style box model (constraints
down, sizes up), no constraint solver. See `packages/plume/README.md`.

**Dependencies:** plume (layout), termlib (terminal control), termparser (input), termunicode (width)

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
  the double buffer redrew only what changed), `emit(event)` to drive the loop, and a
  recorded `exitCode` — `flushThenExit` never exits the test process. It is **not a terminal
  emulator**: it parses no escape sequences, and every call but `draw` is recorded, not
  simulated. See `test/terminal_test.dart` and `test/application_test.dart`.

## Mouse: the Hit Map and the Router

A mouse event reaches `update` **already resolved** — it knows which widget it belongs to,
where it landed in that widget's own cells, and what it was. Nothing above the router
hit-tests, and no app stashes a frame to do it. Widget-level mouse handling (scrolling a
list, clicking a table row) is **spec 0143** and lands in `kiko_widgets`; everything below
is the framework half.

### Coordinates

**0-based buffer cells, everywhere above the backend** — the same space as `Rect`, `Buffer`
and `Position`. The backend is the boundary and translates the terminal's 1-based numbers
on the way in; see The Backend Seam above.

`global` is absolute, `local` is `global - targetRect.topLeft`, and with no target the two
are equal.

**Columns, not graphemes.** `local.x` is a display column. A click on either column of a
2-wide CJK grapheme resolves to that grapheme, and whoever maps column→grapheme does it
with termunicode widths. The router is width-ignorant, and knows nothing of scroll offsets
or insets either.

### `HitMap` — the one hit-testing type

`HitMap` (`src/widgets/hit_map.dart`) is an immutable spatial index over one frame's
tagged widgets: `hitId(x, y)`, `rectOf(id)`, `hitPath(x, y)`. It is the *only* type that
answers those questions.

**Which frame a map describes is carried by which map you hold, not by which method you
call:**

- `frame.hits` — *this* frame, as far as it has been painted. Its ordering constraint
  enforces itself: `rectOf(id)` is null until `id`'s subtree has rendered.
- `ctx.hits` — the **committed** frame the event saw. Each input event is stamped at
  enqueue with the then-current map and resolved against it, so an event that waits in
  the queue while a new frame paints still resolves against the cells the user was
  looking at.

`update` never receives the writable `Frame` — only `UpdateContext` (`hits` + `area`),
which is read-only. A field earns a slot on `UpdateContext` only if the runtime supplies
it, the model and message cannot yield it, and update logic needs it.

Mark a hit region with `Tagged(id, child)`. It is the one place a plume `tag` is set.
**Where you put the tag decides what `local` means** — tag a bordered box and a click is
counted from the border, tag the content and it is counted from the content. Nothing
downstream compensates. **An id names exactly one node per frame**; `HitMap` construction
asserts it, so wrapping a widget that already self-tags with its model id trips in debug.

### Capture

A button press hands the pointer to whatever was under it, and every move, drag and press
that follows addresses the same target until the button comes up — even once the cursor has
run far off it. This is what makes a drag survive a cursor that outruns the widget.

- **Implicit, single slot.** No widget asks for it. Any button captures, any button
  releases, and a second press while held goes to the captor.
- **It captures the resolution, `null` included.** A rubber-band drag begun on the
  background does not re-target the instant the cursor crosses a tagged widget.
- **Three abnormal terminators**, each dropping capture and delivering `PointerCancelMsg`
  to the captor: a bare `moved` arrives while captured (the release happened off-window),
  the captor is absent from the newest hit map (it unmounted or scrolled away), the
  terminal loses focus. **`up` ends the interaction; `cancel` ends it and means do not
  commit it.**
- **The wheel bypasses capture** — it is no part of a button gesture, so it always
  addresses what is under the cursor. Wheel events are never coalesced: a wheel notch is a
  delta, and merging two would eat one. Moves and drags carry a position, so they coalesce.
- **Hover is suspended while capture is held**, and re-derived on release.

`targetRect` is the captor's **current** rect, never one frozen at button-down: the user
aims at the cells now on screen, and `inside` must answer against those. A widget stores
its own grab offset at the `down` — `global` plus `targetRect` reconstructs everything.

### Leave, and the absence of enter

The router synthesizes `PointerLeaveMsg(targetId)` when a routed event resolves to a
different id, delivered *before* that event. It synthesizes **no enter**: a widget learns
it is hovered from the first `PointerMsg` addressed to it, so an enter would carry no
information. *Synthesize only what the event stream cannot deliver.*

There is **no `Hoverable` interface**, and the framework holds no hover state beyond one
id. `Focusable` exists only because `FocusGroup` is a generic external mutator; hover has
no external half — whoever owns it sets it in its own `update` and reads it in its own
`build()`. The framework contributes only what only the framework can know: the router
alone knows which *widget* is hovered; only a list knows which of its *rows* is.

### Dispatch

`PointerMsg`, `PointerLeaveMsg` and `PointerCancelMsg` all implement `Routed`, so an app
forwards every kind of pointer traffic in one generic line. The map is **app-side**: the
runtime routes ids and stops there.

```dart
final targets = <String, Component>{'table-1': m.table, 'list-1': m.list};

case PointerMsg(targetId: 'table-1') p => handleTableSpecially(model, p);  // domain case
case Routed(:final targetId?) when targets.containsKey(targetId):          // generic
  return switch (targets[targetId]!.update(msg)) {                         // same update(Msg) keyboard uses
    Handled(:final cmd) => (model, cmd),                                   // consumed → run its effect
    Declined() => (model, null),                                           // not consumed → could try the next id out
  };
case PointerMsg p => handleBackground(model, p);   // targetId == null → background
```

`Routed` means *this was routed*, not *this has a target* — `targetId` is nullable, so
`Routed(:final targetId?)` declines background events and lets them fall through. Keyboard
forwards to the **focused** component (one target, one `focus.focused`); mouse forwards to
the **targeted** one (N targets, so a map). Same `update(Msg)` entry point; the data
structure differs exactly as the target count does. A click that activates a row therefore
emits the same widget→app command a keyboard Enter would, addressed by the same id.

**Propagation is app-side.** Events deliver to the innermost target only; the framework
never bubbles. Build it from `ctx.hits.hitPath(x, y)` plus the existing decline convention
— the addressed model returns `Declined`, and the app tries the next id out.

See `example/mouse.dart` (capture, leave, cancel) and `example/mouse_dispatch.dart`
(one-line routing).

### The one real hazard

Reading a rect in `update` to anchor something painted **this** tick against **last**
tick's layout. Resolving a click against committed pixels is correct — the user cannot have
clicked a layout they were never shown — but anchoring is not a query about the past. The
fix is not a warning: **anchoring belongs in `view`**, where `frame.hits` describes the tree
being painted.

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

## Code Style

- Uses `very_good_analysis` lints
- Strict casts/inference/raw-types enabled
- `public_member_api_docs` required
