# Mouse routing: the hit map, capture, and dispatch

The full story of how a pointer event travels from the terminal to a widget.
The summary and the never-rules live in `../CLAUDE.md` (section "Mouse: the Hit
Map and the Router"); this file holds the rationale, the edge cases, and the
worked dispatch example. The widget half — what a model does with a resolved
pointer — lives in `kiko_widgets/CLAUDE.md`, "Widget mouse handling".

A mouse event reaches `update` **already resolved** — it knows which widget it
belongs to, where it landed in that widget's own cells, and what it was.
Nothing above the router hit-tests, and no app stashes a frame to do it.

## Coordinates

**0-based buffer cells, everywhere above the backend** — the same space as
`Rect`, `Buffer` and `Position`. The backend is the boundary and translates the
terminal's 1-based numbers on the way in; see "The Backend Seam" in
`../CLAUDE.md`.

`global` is absolute, `local` is `global - targetRect.topLeft`, and with no
target the two are equal.

**Columns, not graphemes.** `local.x` is a display column. A click on either
column of a 2-wide CJK grapheme resolves to that grapheme, and whoever maps
column→grapheme does it with termunicode widths. The router is width-ignorant,
and knows nothing of scroll offsets or insets either.

## `HitMap` — the one hit-testing type

`HitMap` (`src/widgets/hit_map.dart`) is an immutable spatial index over one
frame's tagged widgets: `hitId(x, y)`, `rectOf(id)`, `hitPath(x, y)`. It is the
*only* type that answers those questions.

**Which frame a map describes is carried by which map you hold, not by which
method you call:**

- `frame.hits` — *this* frame, as far as it has been painted. Its ordering
  constraint enforces itself: `rectOf(id)` is null until `id`'s subtree has
  rendered.
- `ctx.hits` — the **committed** frame the event saw. Each input event is
  stamped at enqueue with the then-current map and resolved against it, so an
  event that waits in the queue while a new frame paints still resolves against
  the cells the user was looking at.

`update` never receives the writable `Frame` — only `UpdateContext` (`hits` +
`area`), which is read-only. A field earns a slot on `UpdateContext` only if
the runtime supplies it, the model and message cannot yield it, and update
logic needs it.

Mark a hit region with `Tagged(id, child)`. It is the one place a plume `tag`
is set. **Where you put the tag decides what `local` means** — tag a bordered
box and a click is counted from the border, tag the content and it is counted
from the content. Nothing downstream compensates. **An id names exactly one
node per frame**; `HitMap` construction asserts it, so wrapping a widget that
already self-tags with its model id trips in debug.

## Viewports and the hit map

A `Viewport` (`src/plume/viewport.dart`, a thin bridge over plume's `Viewport`
render node) shows a scrolled window onto a taller child. Its rect clips hit
**presence**, not hit **geometry** — the two are deliberately different
questions:

- **Presence is visibility-true.** A tagged descendant whose rect falls
  entirely outside a `clipsHits` ancestor's window is *absent* from that
  frame's `HitMap` — `rectOf` answers `null`, exactly as if it had never
  painted. This is not a convenience; it is what keeps capture's abnormal
  terminator working (`latest.rectOf(id) == null` → `PointerCancelMsg`). A
  `Viewport` lays its whole child out every frame regardless of scroll — unlike
  the windowed data widgets, which never build off-screen rows — so without
  presence-clipping a scrolled-away captor would look present forever and a
  gesture would never cancel.
- **Geometry is placement-true.** A *partially* visible widget's `rectOf` is
  its full, unclipped placement rect — including a negative top when scrolled
  above the window — because that rect is the widget's coordinate origin:
  `local = global - targetRect.topLeft` must anchor there, or a wrap-aware
  caret (TextArea) computes against content the user cannot see. Point queries
  (`hitId`/`hitPath`) needed no change for any of this — every node already
  prunes at its own rect on the way down.
- **The accepted residual edge:** a press captured on a half-visible widget,
  released over its *hidden* rows, still counts `inside` (placement rect says
  so) even though the user visually released elsewhere. Small and deliberate;
  revisit only if it bites in practice.
- **The trap:** never scroll something into view by reading
  `ctx.hits.rectOf(id)` — presence-clipping makes a fully scrolled-off widget
  `null` in precisely the case that matters. Scrolling to a widget — including
  scroll-to-focused — is model arithmetic (`ScrollViewModel.ensureVisible`, in
  `kiko_widgets`), never a hit-map read.

A node opts into this with `clipsHits => true` (plume's `RenderNode`, `false`
by default); it is a node capability any future clipping container can adopt,
not a `HitMap` special case. The terminal cursor gets the same treatment:
`BufferSurface.placeCursor` drops a position outside the active clip, so a
focused field whose caret row is scrolled off reports no cursor rather than one
at the wrong cell.

**A `Flexible`/`Expanded` under an unbounded main axis throws.** The classic
contradiction — a flex child inside a scroll viewport, where there is no
bounded space to take a share of — used to be a debug-only assert; asserts are
compiled out under `dart run` and in AOT, exactly the modes a real TUI app runs
in, and the release fallback silently collapsed the child to zero cells
instead. It is now an always-on `StateError` naming the fix (bound the child's
main axis, or make it inflexible). If paint culling is ever added to plume, it
must never cull a `Viewport` node itself — its measurement callback depends on
painting every frame to walk the tag-range map.

## Capture

A button press hands the pointer to whatever was under it, and every move, drag
and press that follows addresses the same target until the button comes up —
even once the cursor has run far off it. This is what makes a drag survive a
cursor that outruns the widget.

- **Implicit, single slot.** No widget asks for it. Any button captures, any
  button releases, and a second press while held goes to the captor.
- **It captures the resolution, `null` included.** A rubber-band drag begun on
  the background does not re-target the instant the cursor crosses a tagged
  widget.
- **Three abnormal terminators**, each dropping capture and delivering
  `PointerCancelMsg` to the captor: a bare `moved` arrives while captured (the
  release happened off-window), the captor is absent from the newest hit map
  (it unmounted or scrolled away), the terminal loses focus. **`up` ends the
  interaction; `cancel` ends it and means do not commit it.**
- **The wheel bypasses capture** — it is no part of a button gesture, so it
  always addresses what is under the cursor. Wheel events are never coalesced:
  a wheel notch is a delta, and merging two would eat one. Moves and drags
  carry a position, so they coalesce.
- **Hover is suspended while capture is held**, and re-derived on release.

`targetRect` is the captor's **current** rect, never one frozen at button-down:
the user aims at the cells now on screen, and `inside` must answer against
those. A widget stores its own grab offset at the `down` — `global` plus
`targetRect` reconstructs everything.

## Leave, and the absence of enter

The router synthesizes `PointerLeaveMsg(targetId)` when a routed event resolves
to a different id, delivered *before* that event. It synthesizes **no enter**:
a widget learns it is hovered from the first `PointerMsg` addressed to it, so
an enter would carry no information. *Synthesize only what the event stream
cannot deliver.*

There is **no `Hoverable` interface**, and the framework holds no hover state
beyond one id. `Focusable` exists only because `FocusGroup` is a generic
external mutator; hover has no external half — whoever owns it sets it in its
own `update` and reads it in its own `build()`. The framework contributes only
what only the framework can know: the router alone knows which *widget* is
hovered; only a list knows which of its *rows* is.

## Dispatch

`PointerMsg`, `PointerLeaveMsg` and `PointerCancelMsg` all implement `Routed`,
so an app forwards every kind of pointer traffic in one generic line. The map
is **app-side**: the runtime routes ids and stops there.

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

`Routed` means *this was routed*, not *this has a target* — `targetId` is
nullable, so `Routed(:final targetId?)` declines background events and lets
them fall through. Keyboard forwards to the **focused** component (one target,
one `focus.focused`); mouse forwards to the **targeted** one (N targets, so a
map). Same `update(Msg)` entry point; the data structure differs exactly as the
target count does. A click that activates a row therefore emits the same
widget→app command a keyboard Enter would, addressed by the same id.

**Propagation is app-side.** Events deliver to the innermost target only; the
framework never bubbles. Build it from `ctx.hits.hitPath(x, y)` plus the
existing decline convention — the addressed model returns `Declined`, and the
app tries the next id out.

`kiko_widgets`' **`FocusRouter` packages this exact pattern** — the targetId
guard, keyboard→focused, pointer→targeted, press-moves-focus, declined-pointer
bubbling — behind a single `route()` call, and most apps should reach for it.
`example/mouse_dispatch.dart` stays hand-rolled on purpose: it *is* the
primitive the router is built from, and the seam to drop to when an app
outgrows the packaged glue.

See `example/mouse.dart` (capture, leave, cancel) and
`example/mouse_dispatch.dart` (one-line routing, hand-rolled).

## The one real hazard

Reading a rect in `update` to anchor something painted **this** tick against
**last** tick's layout. Resolving a click against committed pixels is correct —
the user cannot have clicked a layout they were never shown — but anchoring is
not a query about the past. The fix is not a warning: **anchoring belongs in
`view`**, where `frame.hits` describes the tree being painted.
