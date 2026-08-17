# Mouse routing: the hit map, capture, and dispatch

How a pointer event travels from the terminal to a widget: the machinery, the
edge cases, and a worked dispatch example. The widget half — what a model does
with a resolved pointer — is "The widget side" at the end of this page.

A mouse event reaches `update` **already resolved**. The message names the
target widget, the position inside that widget's own cells, and the kind of
event. No code above the router hit-tests, and no app keeps a frame around to
do it.

## Coordinates

**Everything above the backend uses 0-based buffer cells** — the same space as
`Rect`, `Buffer` and `Position`. The backend is the boundary; it translates
the terminal's 1-based numbers on the way in (`docs/backend.md`).

`global` is the absolute position. `local` is `global - targetRect.topLeft`.
With no target the two are equal.

**Positions are columns, not graphemes.** `local.x` is a display column. A
click on either column of a 2-wide CJK grapheme resolves to that grapheme.
Code that maps a column to a grapheme must use the session `TextMeasurer`, not
a bare termunicode call (see "Text measurement" in `docs/architecture.md`).
The router knows nothing of glyph widths, scroll offsets, or insets.

## Intake — no terminal types on a message

`PointerMsg`, `FocusMsg` and `PasteMsg` store kiko's own types:
`PointerButton`, `PointerAction`, and plain fields. Intake maps the terminal
event exactly once (`pointerFieldsFrom` in `mouse_router.dart`, `eventToMsg`
in `msg.dart`). Nothing downstream imports termparser to read a message.

## `HitMap` — the one hit-testing type

`HitMap` (`packages/kiko_core/lib/src/widgets/hit_map.dart`) is an immutable
spatial index over one frame's tagged widgets: `hitId(x, y)`, `rectOf(id)`,
`hitPath(x, y)`, `isLive(id)`. It is the only type that answers those
questions.

Which frame a map describes depends on the map you hold, not on the method
you call:

- `frame.hits` describes *this* frame, as far as it has been painted.
  `rectOf(id)` is null until `id`'s subtree has rendered, so the ordering
  constraint enforces itself.
- `ctx.hits` describes the **committed** frame the event saw. The queue
  stamps each input event at enqueue with the then-current map, and the event
  resolves against that map. An event that waits in the queue while a new
  frame paints still resolves against the cells the user was looking at.

`update` never receives the writable `Frame`. It receives `UpdateContext`
(`hits` + `area`), which is read-only. A field earns a slot on `UpdateContext`
only if the runtime supplies it, the model and message cannot yield it, and
update logic needs it.

App code tags a node in two spellings that build the same tree: the `id:`
parameter on a container view (`Container`, `Column`, `Row`, `Stack`), or
`Tagged(id, child)` for a view the caller does not construct. Widgets
self-tag with their model id (see "The widget side"). Every spelling stamps
a case of the sealed `HitTag` vocabulary (`hit_tag.dart`) into plume's
opaque `tag` slot: `IdTag(id)` for an addressable node, `ScopeTag(name)` for
a scope (next section). Apps pass plain strings; the sealed type appears
only at the stamping sites and in `HitMap`. No segment may contain `/`, the
path separator; the constructors assert it.

**Where you put the tag decides what `local` means.** Tag a bordered box and
a click is counted from the border; tag the content and it is counted from
the content. Nothing downstream compensates. **A path names exactly one node
per frame** — for a widget under no scope, the path is its bare id. Two
guards enforce this in debug. `Tagged.build` asserts that its child's node
carries no tag yet; this catches wrapping a widget that tags its own root
node, or a container that already took an `id:`. `HitMap` construction
asserts that no path lands on two nodes; this catches what a wrap site
cannot see — a sibling or an inner node tagged with the same id.

## Scopes — a composite owns its parts

A composite widget is built from other widgets: a combobox embeds a text
field and a list, and each part self-tags with its own id. A **scope** makes
those parts belong to the composite. A scope is a node tagged
`ScopeTag(name)`, stamped by `Tagged.scope(name, child)` or by the
composite's own `build` — the same idiom widgets use for their id. A scope
qualifies every tag beneath it: an id under scopes records as the **hit
path** `scope/.../id`. The last segment of a path is its **leaf** — the id
of the node itself. A widget under no scope keeps its bare id and behaves
exactly as it did before scopes existed; flat widgets never see paths. Inner
widgets keep their real ids: tests and tooling still address the field by
the field's id, as a path.

Every `HitMap` query keys by full path: `hitId` answers paths, and `rectOf`,
`regionAt` and `isLive` accept them. The duplicate assert applies to full
leaf paths. A scope name is a qualifier, not an addressable id, so one name
may sit on several nodes in one frame — a composite paints its field in the
base tree and its popup in an overlay pass, and both areas belong to it.
`hitPath` reports scope entries too, each with the rect of the node that
carried it.

A press on a scope's own cells — no inner tag under the point — resolves to
the scope's path and delivers with no region. `rectOf` answers `null` for a
scope path, because a scope has no single rect. Presence is a separate
question: `isLive(id)` is true for a leaf path while its rect is recorded,
and for a scope path while any node carries the scope. Capture asks
`isLive`, never `rectOf` (see "Capture").

**A scope's rect is its press claim, so a scope must hug its content.** A
scope node laid out larger than what it paints swallows presses over
everything beneath it — an overlay scope above the base tree most of all.
Size the scope to the content it owns.

Delivery is the routers' half: a path resolves to the component registered
under its longest prefix and arrives as-is, and the owner reads the leaf to
dispatch. The addressing rules live in `docs/components.md`; the packaged
routing in `docs/focus-router.md`.

## Hit regions — the part under the pointer

A tag answers *which widget*; a **hit region** answers *which part of it*. A
view marks its discrete parts — a row, a sticky header, an expand indicator —
while painting. The router resolves the innermost marked part under the
pointer and delivers it on `PointerMsg.region`, a nullable `Region`. `Region`
is kiko's own open marker interface, carried opaquely the way `Msg` and `Cmd`
are. A widget model switches over its own region types instead of computing
the part from a coordinate.

**The carrier mirrors `tag`.** A plume `RenderNode` stores paint-marked
regions the same way it stores `tag`: a list of `(key, rect)` pairs. The node
appends a pair with `markRegion` from its `paintSelf`. The paint traversal
clears the list before each repaint, so a mark always describes the last
committed frame. Plume never reads the marks; kiko interprets them. `Region`
is the key type kiko recognizes; any other key is ignored, exactly as a
non-string `tag` is.

**One walk, scoped by subtree.** `HitMap` construction records an id→node
index in the same walk that collects tag rects. A per-widget lookup —
`regionAt(id, x, y)` — therefore descends only that widget's subtree, never
the whole tree. It resolves the innermost marked region containing the point;
a smaller part painted over a row wins the overlap. The descent stops at any
nested tagged widget. A region can therefore only originate from the widget
that receives it, and no model needs a defensive case for a neighbour's types.
The router resolves the pointer's target (`hitId`) and its region (`regionAt`
against that target) together, and attaches the region to the `PointerMsg` it
already builds. A debug assert enforces one region key per widget per frame —
the sibling of the one-tag-per-frame assert.

**Wheel, capture, the bare-scope press, leave:**

- **The wheel is target-scoped, above all region logic.** A notch cares which
  widget it is over, never which part, so it scrolls the same over a
  separator, a header, or a row. A widget's wheel case sits above its region
  switch. Nesting the wheel inside a region case would make the gaps between
  parts scroll-dead.
- **A captured gesture recomputes the region on every event**, against the
  captor's own subtree. The region is `null` whenever the pointer is outside
  the captor.
- **A bare-scope press carries no rect.** A press on a scope's own cells —
  no inner tag under the point — resolves to the scope's path with
  `targetRect: null`, because a scope has no single rect (see "Scopes"
  above). `PointerMsg.local` then falls back to the global position, since
  there is no rect to subtract it from. A caret-placing widget reads the
  missing rect as its cue to leave the caret where it is; it still consumes
  the press.
- **Leave and cancel carry no position, and therefore no region.**

**Regions and `local` are two reading modes, both permanent.** The tag is the
only requirement for routing. Past it, a widget with discrete parts marks
regions and switches on `region`. That switch is correct by construction: the
code that painted the part wrote the mark. A widget over a continuous
surface — a text editor's wrap-aware click-to-caret — marks no regions, so
its `region` is always `null`, and it reads `local` instead. `local` stays on
every message in both modes. Reading `local` is a first-class mode: regions
complement `local`, they never replace it.

## Viewports and the hit map

A `Viewport` (`packages/kiko_core/lib/src/plume/viewport.dart`, a thin bridge
over plume's `Viewport` render node) shows a scrolled window onto a taller
child. Its rect clips hit **presence**, not hit **geometry**. The two are
deliberately different questions:

- **Presence follows visibility.** A tagged descendant whose rect falls
  entirely outside a `clipsHits` ancestor's window is absent from that
  frame's `HitMap`: `rectOf` answers `null`, exactly as if it had never
  painted. This is not a convenience; it is what keeps capture's abnormal end
  working (the captor stops being `isLive` → `PointerCancelMsg`). A `Viewport`
  lays out its whole child every frame regardless of scroll, unlike the
  windowed widgets, which never build off-screen rows. Without presence
  clipping, a scrolled-away captor would look present forever and its gesture
  would never cancel.
- **Geometry follows placement.** A *partially* visible widget's `rectOf` is
  its full, unclipped placement rect — including a negative top when scrolled
  above the window. That rect is the widget's coordinate origin:
  `local = global - targetRect.topLeft` must anchor there, or a wrap-aware
  caret (TextArea) computes against content the user cannot see. Point
  queries (`hitId`/`hitPath`) need no clip awareness; every node prunes at
  its own rect on the way down.
- **The accepted residual edge:** a press captured on a half-visible widget
  and released over its *hidden* rows still counts as `inside`, because the
  placement rect says so — even though the user visually released elsewhere.
  The edge is small and deliberate; revisit it only if it bites in practice.
- **The trap:** never scroll something into view by reading
  `ctx.hits.rectOf(id)`. Presence clipping makes a fully scrolled-off widget
  `null` in precisely the case that matters. Scrolling to a widget —
  including scroll-to-focused — is model arithmetic
  (`ScrollViewModel.ensureVisible`, in `kiko_widgets`), never a hit-map read.

A node opts into presence clipping with `clipsHits => true` (plume's
`RenderNode`, `false` by default). It is a node capability any future
clipping container can adopt, not a `HitMap` special case. The terminal
cursor gets the same treatment: `BufferSurface.placeCursor` drops a position
outside the active clip. A focused field whose caret row is scrolled off
therefore reports no cursor, rather than a cursor at the wrong cell.

**A `Flexible` or `Expanded` under an unbounded main axis throws.** This is
the classic contradiction: a flex child inside a scroll viewport has no
bounded space to take a share of. The throw is an always-on `StateError` that
names the fix — bound the child's main axis, or make it inflexible — and
deliberately not a debug assert. Asserts compile out under `dart run` and in
AOT, exactly the modes a real TUI app runs in, and a silent fallback would
collapse the child to zero cells. A related rule for plume itself: if
paint culling is ever added, it must never cull a `Viewport` node. The
viewport reports its metrics — including each tagged descendant's ancestor
tag chain and content-relative row range (`ViewportMetrics.entries`) — from a
callback that runs during paint, so it must paint every frame.

## Capture

A button press hands the pointer to whatever was under it. Every move, drag
and press that follows addresses that same target — the **captor** — until
the button comes up, even after the cursor has left it. Capture is what makes
a drag survive a cursor that leaves the widget mid-gesture.

- **Capture is implicit, and there is one slot.** No widget asks for it. Any
  button captures, any button releases, and a second press while one is held
  goes to the captor.
- **Capture holds the resolution, `null` included.** A drag that starts on
  the background stays on the background; it does not re-target the instant
  the cursor crosses a tagged widget.
- **Capture holds the hit path, and prefix routing applies while it is
  held.** The router replays what `hitId` answered, so a drag off a
  composite keeps the gesture on the captured path.
- **Three conditions end capture abnormally.** Each drops capture and
  delivers `PointerCancelMsg` to the captor: a bare `moved` arrives while
  captured (the release happened off-window); the captor is absent from the
  newest hit map (it unmounted or scrolled away); the terminal loses focus.
  `up` ends the interaction. `cancel` ends it and means: do not commit it.
  Absence asks `isLive`, never `rectOf`. A captured bare scope has no rect
  but is still on screen; it survives, its messages carry a null
  `targetRect`, and `local` equals `global`. A scope painted out entirely
  still cancels.
- **The wheel bypasses capture.** A notch is not part of a button gesture, so
  it always addresses what is under the cursor. Wheel events are never
  coalesced: a notch is a delta, and merging two would eat one. Moves and
  drags carry a position, so they coalesce.
- **Hover is suspended while capture is held**, and re-derived on release.

`targetRect` is the captor's **current** rect, never one frozen at
button-down. The user aims at the cells now on screen, and `inside` must
answer against those. A widget stores its own grab offset at the `down`
event; `global` plus `targetRect` reconstructs everything else.

## Leave, and the absence of enter

When a routed event resolves to a different id than the last one, the router
synthesizes `PointerLeaveMsg(targetId)` and delivers it before that event. It
synthesizes no enter message. A widget learns it is hovered from the first
`PointerMsg` addressed to it, so an enter would carry no information. The
rule: synthesize only what the event stream cannot deliver.

There is no `Hoverable` interface, and the framework holds no hover state
beyond one id. `Focusable` exists only because `FocusGroup` is a generic
external mutator; no external code mutates hover. The model that owns hover
sets it in its own `update` and reads it in its own `build()`. The framework
contributes only what only the framework can know: the router knows which
*widget* is hovered; only a list knows which of its *rows* is.

## Dispatch

`PointerMsg`, `PointerLeaveMsg` and `PointerCancelMsg` all implement
`Routed`, so an app forwards every kind of pointer traffic in one generic
line. The target map is **app-side**: the runtime routes ids and stops there.

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

`Routed` means *this was routed*, not *this has a target*. `targetId` is
nullable, so `Routed(:final targetId?)` declines background events and lets
them fall through. Keyboard forwards to the **focused** component: one
target, one `focus.focused`. Mouse forwards to the **targeted** component: N
targets, so a map. Both use the same `update(Msg)` entry point; the data
structure differs exactly as the target count does. A click that activates a
row therefore emits the same widget→app command a keyboard Enter would,
addressed by the same id.

**Propagation is app-side.** Events deliver to the innermost target only; the
framework never bubbles. Build propagation from `ctx.hits.hitPath(x, y)` plus
the existing decline convention: the addressed model returns `Declined`, and
the app tries the next id out.

A composite's parts deliver as paths, so a hand-rolled target map resolves
`targetId` with `HitTag.resolve` — the longest registered prefix — instead
of an exact `containsKey`. A flat app whose ids are all bare needs no
change; a bare id resolves only exactly. The addressing rules live in
`docs/components.md`.

`FocusRouter` in `kiko_widgets` packages this exact pattern — the targetId
guard, keyboard→focused, pointer→targeted, press-moves-focus,
declined-pointer bubbling — behind a single `route()` call
(`docs/focus-router.md`). Most apps should reach for it.
`packages/kiko_core/example/mouse_dispatch.dart` stays hand-rolled on
purpose. It is the primitive `FocusRouter` is built from, and the pattern to
drop back to when an app outgrows the packaged routing.

See `packages/kiko_core/example/mouse.dart` (capture, leave, cancel) and
`packages/kiko_core/example/mouse_dispatch.dart` (one-line routing,
hand-rolled).

## The one real hazard

Reading a rect in `update` to anchor something painted **this** tick against
**last** tick's layout. Resolving a click against the committed frame is
correct; the user cannot have clicked a layout they were never shown. But
anchoring is not a question about the past. The fix is structural, not a
warning: **anchoring belongs in `view`**, where `frame.hits` describes the
tree being painted.

## The widget side

A widget consumes the resolved `PointerMsg` the framework delivers. The
router, hit map, capture and leave/cancel machinery above this section is the
framework's half. `packages/kiko_widgets/example/mouse_widgets.dart` and
`packages/kiko_widgets/example/scrollable_form.dart` work the widget half end
to end. The rules:

- **The pointer cases sit above the focus gate.** The focus gate
  (`if (!focused) return const Declined();`) gates only the keyboard. A
  wheel scrolls, a click selects, and a hover highlights whether or not the
  widget is focused, so the pointer, leave and cancel cases run above that
  line.
- **Consume with `Handled`, refuse with `Declined` — the rule that gets
  forgotten.** A blanket `return const Handled()` silently kills app-side
  bubbling. A wheel a `TextInput` cannot use must come back `Declined()`, or
  it never reaches the scrollable around it. Decline every pointer you do not
  consume.
- **A click emits the keyboard's command.** The widget moves its cursor to
  the clicked row and returns the same id-addressed command Enter returns;
  the app cannot tell which device fired it. A widget never emits a focus
  command. Moving focus on a press belongs to whoever owns the `FocusGroup`;
  `FocusRouter` (or `focusOnPress`) does it in one line.
- **Read discrete parts from hit regions, not coordinates.** A view marks
  each row, header, or indicator as a `Region` while it paints
  (`markRegion`). The framework resolves the one under the pointer and
  delivers it on `pointer.region`, so a model switches on the part instead of
  computing it from `local`. Rows share `RowRegion(index)` (a `RowScoped`)
  and go through `handleRowPointer`; a widget-specific part
  (`TableHeaderRegion`, `TreeIndicatorRegion`) gets its own case. `local`
  stays on the message for continuous surfaces (a text editor's
  click-to-caret); that mode marks no regions and is permanent. See "Hit
  regions" above.
- **Hover is a plain model field** (`int? hoverRow`). The shared
  `handleRowPointer` sets it from the resolved row in `update`; `build` folds
  it into the `WidgetState` set; `PointerLeaveMsg` clears it. There is no
  enter message — the first `PointerMsg` addressed to the widget is the
  enter.
- **Scrolling goes through `ScrollableModel`**
  (`packages/kiko_widgets/lib/src/widgets/scrollable_model.dart`):
  `scrollOffset` and `visibleCount`; `scrollBy(rows)`, which clamps and
  returns the rows actually moved; `handleRowPointer(...)`, the shared row
  handler that sets hover, moves the cursor, and activates; `wheelScrollLines`
  (3). A wheel notch moves the viewport and leaves the cursor in place; the
  next keypress snaps the viewport back (Vim behavior). Near-edge scrolling
  triggers the same load threshold as cursor navigation.
- **The wheel rule is uniform across every scrollable** (List, Table, Tree,
  ScrollView). A notch that would move nothing in its direction — `scrollBy`
  returned 0 at that edge — is `Declined()`, per direction. Any notch that
  moves at all, even partially, is consumed. This is what makes nested
  scrolling work: the inner scrollable at its limit declines, and the app
  (via `offerOutward` or `FocusRouter`) offers the notch to the next
  scrollable ancestor out.
- **Widgets self-tag** (`..tag = IdTag(model.id)` in `build`); routing works
  the moment `mouseEvents: true` is on. `Tagged(id, child)` is only for areas
  the app composes that no widget model owns. Never wrap a self-tagging
  widget in a `Tagged`. In debug one of two guards trips: `Tagged.build`
  asserts the child's node is untagged, and `HitMap` construction asserts no
  path lands on two nodes. In release the guards compile out and the wrap
  overwrites the widget's own tag, so routing addresses the wrong id.
