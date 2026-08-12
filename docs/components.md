# Components: identity, the update contract, and addressing

A widget model is a `Component`: it has a stable id, and its `update` reports
whether it consumed a message. Every command a widget sends up to the app
carries that id as its address. Every async result the app sends back down
carries it too. This page is the contract; the authoring tutorial is
`docs/building-widgets.md`.

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
`TableActionCmd`, `ListActionCmd`, `TreeExpandCmd`, `TreeCollapseCmd`,
`TreeActionCmd`, `ButtonPressCmd`, and the shared `LoadRequest` for data
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
  (`onSuccess: (data) => LoadResult(id, key: key, data: data)`), and route
  the receipt by `r.id`. This is the easiest rule to forget. Omit the id and
  the app silently supports only one instance.
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
