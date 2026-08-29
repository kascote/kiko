# Glossary

The canonical vocabulary for kiko documentation and discussion. Every term of
art used in `docs/` or a CLAUDE.md is either ordinary English, a code
identifier, or an entry here. One term, one meaning; if two terms compete for
one concept, the entry names the winner.

An entry is one or two sentences; the full story belongs to the topic page.
A term of art added to a page gets its entry here in the same change.

## Runtime and rendering

- **backend** — the seam between kiko and a real terminal. Everything above it
  uses 0-based buffer cells; terminal event types stop at intake
  (`docs/backend.md`).
- **buffer** — the grid of cells a frame is painted into. Two buffers are
  diffed to find the minimal terminal update.
- **frame** — the `Frame` object `Terminal.draw` hands the view callback: one
  drawn screen, built from a base render pass and any layers composited over
  it. A frame follows every processed message, at most `fps` a second; no
  frame is drawn while the queue is idle (`docs/architecture.md`).
- **tick** (`Tick`, `TickMsg`) — a one-shot timer `update` arms. Its one
  `TickMsg` is addressed to the owner by id and carries the owner's
  generation `key` and the time since arming. An animation re-arms from its
  `TickMsg` case and drops a stale key (`docs/architecture.md`).
- **layer** — a render pass with its own buffer and its own clean slate.
  Compositing a layer (`Frame.renderLayer`) replaces the frame's cells under
  its rect; layers composite in call order.
- **view** — a stateless description of UI (`View`); its `build()` produces a
  fresh plume node tree each frame.
- **measurer** — the single `TextMeasurer` that decides every glyph's display
  width for one application session.
- **coalescing** — merging queued messages of the same kind so only the latest
  is processed (pointer moves and drags, resizes).
- **intake** — the point where a terminal event becomes a kiko message
  (`eventToMsg`, `pointerFieldsFrom`). No terminal type travels past it
  (`docs/backend.md`).
- **report** (`FrameReport`) — a layout fact paint hands back to the widget
  that owns it, as an addressed message the runtime queues after the frame
  commits. Paint reports; it never writes into a model. Paint reports a fact
  only when it differs from the fact the model holds, so a frame caused by a
  report settles (`docs/architecture.md`).

## MVU

- **model** — the mutable state object an `update` function owns.
- **message** (`Msg`) — an event delivered to `update`: a keystroke, a pointer
  event, a tick, a custom app event.
- **command** (`Cmd`) — a value returned from `update` describing an effect
  the runtime (or the app) should perform.
- **component** — a widget model implementing `Component`: it has a stable
  `id` and an `update` that returns a verdict (`docs/components.md`).
- **verdict** — a widget update's return: `Handled` (consumed, with an
  optional command) or `Declined` (not consumed, still in flight).
- **decline** — returning `Declined`: the widget did not consume the message,
  so the caller may offer it elsewhere.
- **id / addressing** — a component's stable string identity. Widget→app
  commands and async results carry it as their address.
- **addressed message** — a message implementing `Addressed`: it names the
  widget it is for by id, and the router delivers it there (`LoadResult`,
  `FrameReport`, `TickMsg`; `docs/components.md`). Distinct from pointer traffic, whose
  target the hit map resolves.
- **focus gate** — the `if (!focused) return const Declined();` line that
  keeps a widget's keyboard handling inactive while unfocused.

## Keyboard

- **spec string** — the canonical string form of a keystroke (`'q'`,
  `'ctrl+a'`, `'shift+tab'`). `KeyMsg.key` carries one; `KeyBinding` matches
  on them (`docs/keyboard.md`).

## Pointer

- **hit map** — the per-frame spatial index (`HitMap`) answering which tagged
  widget is at a cell (`docs/mouse.md`).
- **tag** — the `HitTag` a widget attaches to its node so the hit map can
  find it: an id (`IdTag`) or a scope name (`ScopeTag`). Answers *which
  widget*.
- **scope** — a node whose name qualifies every tag beneath it, so a
  composite widget owns its parts' hit identity. A scope name is not an
  addressable id; it may sit on several nodes in one frame. Chrome wrapped in
  a scope named by a member's id becomes part of that member's own hit
  territory (`docs/mouse.md`).
- **hit path** — a tagged node's full identity: its enclosing scope names and
  its id, joined with `/` (`cb/field-3`). A node under no scope has a bare
  id; "path" for short where the pointer context is clear.
- **leaf** — the last segment of a hit path: the id of the node itself. The
  owner of a delivered path reads the leaf to dispatch
  (`docs/components.md`).
- **hit region** — a part a view marks while painting (a row, a header).
  Answers *which part* of the widget; delivered on `PointerMsg.region`.
- **hit presence** — whether a tagged widget appears in a frame's hit map at
  all. A widget entirely outside a clipping ancestor's window is absent:
  `rectOf` answers `null` (`docs/mouse.md`).
- **hit geometry** — the rect the hit map stores for a present widget: the
  full, unclipped placement rect. `local` coordinates anchor to its top-left.
- **capture** — while a button is held, all pointer traffic goes to whatever
  was under the press, even if the cursor leaves it.
- **captor** — the widget holding capture: the target resolved at button-down.
  Every captured event addresses it until the button comes up or the gesture
  cancels.
- **reading mode** — how a widget reads a resolved pointer: switch on marked
  regions (discrete parts) or read `local` (a continuous surface). Both modes
  are permanent (`docs/mouse.md`).
- **wheel rule** — decline a wheel notch that would move nothing in its
  direction; consume any notch that moves at all. Uniform across every
  scrollable (`docs/mouse.md`).
- **chrome** — decoration the app composes around a widget (a border, a title
  row) that no widget model owns.

## Data loading

- **load slot** — a widget's per-key loading state: idle, loading, or error
  (`docs/async-loading.md`).
- **load key** — the typed name of the thing being loaded (a page number, a
  tree path); never a direction or an intent.
- **query key** — a combobox's load key, naming a query by the field's text
  when it was asked (`QueryKey`). Only the newest query's answer installs
  (`docs/async-loading.md`).
- **demand** — a windowed widget's pass that computes which pages the viewport
  needs and requests the missing ones.
- **slice status** — the shared answer for what a view is about to paint
  (`SliceStatus`): ready, filling (missing, fetch in flight), stalled
  (missing, nothing coming), or failed. Stalled names every permanent load
  failure. A refusal produces it legitimately, so it is reported and tested,
  never asserted.
- **refusal** — the app answering a load request with `declineLoad`: nothing
  failed, nothing loads, the slot returns to idle.
- **page window** — the sparse cache of fixed-size pages a windowed widget
  stores its rows in (`PageWindow`). A page is fetched whole, held whole, and
  evicted whole (`docs/async-loading.md`).
- **short page** — a page that comes back with fewer rows than the page size.
  It marks the end of the data.
- **windowed widget** — a data widget (List/Table/Tree) that builds only the
  rows in view, not the whole data set.

## Theming

- **tone** — a color pair `(color, on)`; not paintable until projected
  (`docs/theming.md`).
- **projection** — turning a tone into a paintable style: `.ink` (fg only),
  `.fill` (fg + bg), `.wash` (bg only), `.ground` (fg + bg, the base under
  content).
- **ground** — the style an area's cells hold before content paints on it;
  a full `(fg, bg)` pair, set once per area (`docs/theming.md`).
- **anatomy** — the named parts of a widget that can be styled (`XStyle`
  classes of nullable slots).
- **matrix** — the built-in state × class table: the style each
  `WidgetState` contributes to each paint class (`docs/theming.md`).
- **tier** — one of three levels of color fidelity a style degrades
  through: full RGB, the named ANSI-16 table, NO_COLOR modifiers
  (`docs/theming.md`). The word is reserved for this meaning.
