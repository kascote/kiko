# Components: identity, the update contract, and addressing

A widget model is a `Component`: it has a stable id, and its `update` reports
whether it consumed a message. Every command a widget sends up to the app
carries that id as its address. Every async result the app sends back down
carries it too, and the router delivers it by that id. This page is the
contract; the authoring tutorial is `docs/building-widgets.md`.

## The Component contract

`Component` (kiko_core, `src/mvu/focus.dart`) is the widget-model contract:
`UpdateResult update(Msg)` plus `String get id`. `update` reports whether the
model consumed the message: `Handled`, carrying an optional effect `Cmd`, or
`Declined`. It never returns a bare `Cmd?`. The `id` is the model's stable
identity, and widget→app commands carry it as their address. A focus-only
model still has an `id`; addressing is just one use of identity.

`autoId(String prefix)` (kiko_core, `src/mvu/auto_id.dart`) generates
human-readable ids (`'tableview-1'`) from one shared monotonic counter.
Models constructed without an explicit id use it. The counter is sequential
and per-isolate, so auto ids are not stable across runs and not unique
across isolates. That is fine: ids never cross isolates by design. Pass an
explicit id when matching must survive a restart. `resetAutoIdCounter()` is
`@visibleForTesting`.

## The widget pattern

Kiko models are mutable components (Bubble Tea style, not Elm); see
`docs/architecture.md`. Widget models mutate in place.

Two update shapes coexist, and the asymmetry is deliberate:

- **App update** — `(M, Msg, UpdateContext) → (M, Cmd?)`. The model slot
  lets a small value-like app model stay immutable.
- **Widget update** — `UpdateResult update(Msg)`. A widget model is always
  mutable, so it returns no model. It returns only a verdict: `Handled`,
  carrying an optional effect `Cmd`, or `Declined`. The parent switches on
  the verdict. A `Declined` message is still in flight; the parent may offer
  it to the next candidate.

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

Usage in the app's update and view:

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

## Widget→app addressing

Some widget commands are events the app must intercept, not runtime effects:
`TableActivateEvent`, `ListActivateEvent`, `TreeExpandEvent`, `TreeCollapseEvent`,
`TreeActivateEvent`, `ButtonPressEvent`, and the shared `LoadRequest` for data
fetches (`docs/async-loading.md`). They travel up the call stack to the
app's `update`. Each one addresses its owner by a stable `String id`,
carried by value.

Rules a contributor will otherwise miss:

- **Address by `id`, never by reference or by command type.** The app
  resolves a command to its owner by matching the id
  (`id == model.table.id`), or through a `Map<String, …>` registry for N
  instances. Never disambiguate with `identical(...)`. Never assume one
  instance per command type.
- **Async results must carry the id home.** When the app fires a `Task` in
  response to a `LoadRequest(id, key)`, thread both the `id` and the `key`
  into the result message
  (`onSuccess: (data) => LoadResult(id, key: key, data: data)`). This is the
  easiest rule to forget. Omit the id and the result reaches nobody.
- **Derive collection ids from stable domain keys (`user.id`), never from
  the list index.** Indexes shift on insert and delete, so an index-derived
  id routes a result onto the wrong row.
- **Widgets never perform async I/O.** A widget signals "I need data" by
  returning a `LoadRequest`; the app drives every fetch through `Task` and
  routes the result home by id. Do not `await dataSource.getChildren(...)`
  inside a widget. That loses the runtime's cancellation token and races the
  message loop.
- **Log and drop a command whose id resolves to no owner; never ignore it
  silently.** The failure stays observable — the advantage id addressing has
  over reference addressing.

### Addressed messages — the inbound half

`Addressed` (kiko_core, `src/mvu/addressed.dart`) is the interface for a
message that names the widget it is for: `String get id`. It is the inbound
half of id addressing. Widget→app commands carry an id up; an `Addressed`
message carries one down. `LoadResult`, `FrameReport` and `TickMsg`
implement it.
`FocusRouter` delivers an `Addressed` message to the component registered
under its id, or under the longest registered prefix of it, without moving
focus (`docs/focus-router.md`); an id nothing registers comes back `Declined`,
into the app's fall-through.

`Addressed` is not `Routed`. A `Routed.targetId` is nullable and is resolved
by the hit map, so null there means the background. An `Addressed` id is
never null: whoever built the message chose the widget.

Rules for the receiving model:

- **A model owns a message whose id's leaf is its own id, and declines every
  other.** The guard compares the leaf (`HitTag.leafOf`), not the whole id. A
  composite forwards a part's message with the path it arrived under
  (`combo/list`), and the part recognizes itself in it, as it does for
  pointer traffic. A foreign message is not one this model understands,
  whoever routed it. The router makes a foreign result unreachable in
  practice; an app that calls `update` without a router relies on the guard.
  A message that is the model's own is consumed, installed or not.
- **A part's frame report carries the hit path by construction.** Paint
  addresses a report to the scope path the paint walk carries joined with
  the widget's id (`docs/architecture.md`, frame reports). A composite passes
  nothing to its parts for this; a view has no scope parameter.
- **A composite forwards by leaf first.** Before applying the guard to
  itself, a composite forwards a message whose id's leaf (`HitTag.leafOf`)
  names one of its parts to that part, as it forwards pointer traffic.
- **One entry point.** `update` is the only way a result enters a model.
  There is no second method for async results.

## Composite widgets — prefix addressing

A composite widget embeds other widgets and scopes them, so their hit
identity records as paths under its name (`docs/mouse.md`). A pointer over
an embedded part therefore delivers a path (`cb/field-3`), not a bare id.
Prefix addressing resolves that path to a registered component:

- **The longest registered prefix wins.** `HitTag.resolve(path, registered)`
  answers the registered id that owns a path: an exact match wins outright;
  otherwise the search climbs the path one segment at a time toward the
  root. A target `cb/field-3` delivers to the component registered as `cb`,
  or to one registered under a fuller path if present. A bare id has no
  segments to climb, so it matches only exactly.
- **Delivery is as-is.** The message keeps the resolved path, rect, and
  region; the router never rebuilds it against the resolved owner. The owner
  reads the path's leaf (`HitTag.leafOf`) to dispatch to the inner widget,
  whose local math and regions arrive intact.
- **Inner widgets keep their real ids.** No overwritten tags, no derived
  ids, no delegate components. The parts stay addressable by their own ids,
  as paths.
- **A composite is one focus member.** Its parts never join the
  `FocusGroup`; the owner decides which inner widget its key events reach.
  The one path-aware focus move is click-to-focus: a press on any path under
  a member's id focuses that member.

`FocusRouter` resolves prefixes in all its routing, addressed messages
included (`docs/focus-router.md`); a hand-rolled dispatch calls
`HitTag.resolve` itself (`docs/mouse.md`).
