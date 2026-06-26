# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

Higher-level widgets package for Kiko TUI framework. Depends on `kiko_core` for rendering primitives.

See root `/CLAUDE.md` for monorepo commands (`make test`, `make lint`, etc.) and core architecture.

## Widget Pattern

Kiko models are **mutable components** (Bubble Tea style, not Elm) — see root `CLAUDE.md`. Widget models mutate in place.

Two update shapes coexist, asymmetric by design:

- **App update** — `(M, Msg) → (M, Cmd?)`: keeps a model slot so small value-like app models _may_ stay immutable.
- **Widget update** — `Cmd? update(Msg)`: always mutable, so it returns only a `Cmd` (no model).

Widgets follow MVU (Model-View-Update):

```dart
// Model holds state + config
class TextInputModel {
  Cmd? update(Msg msg) { ... }  // handles messages, returns commands
}

// Widget is stateless, renders from model
class TextInput extends Widget {
  final TextInputModel model;
  void render(Rect area, Frame frame) { ... }
}
```

Usage in app's update/view:

```dart
update: (model, msg) {
  final cmd = model.textInput.update(msg);
  return (model, cmd);
}
view: (model, frame) {
  TextInput(model.textInput).render(area, frame);
}
```

## Widget→App Addressing

Some widget commands are **events the app must intercept**, not runtime effects:
`TableActionCmd`, `ListActionCmd`, `TreeExpandCmd`,
`TreeCollapseCmd`, `TreeActionCmd`, `ButtonPressCmd`, plus the shared `LoadRequest`
(List/Table/Tree page and child fetches; see `specs/a7-async-load-lifecycle.md`). They travel **up** the call stack to
the app's `update`. Every one addresses its owner by a **stable `String id`** carried by value

Non-obvious rules a contributor will otherwise miss:

- **Address by `id`, not by reference or by command type.** The app resolves a command to
  its owner by matching the id (`id == model.table.id`), or via a `Map<String, …>` registry
  for N instances. Never disambiguate by `identical(...)`, and never assume one instance per
  command type.
- **Async effect results must carry the id home.** When the app fires a `Task` in response
  to a `LoadRequest(id, key)`, thread both the `id` _and_ the `key` into the _result_
  message (`onSuccess: (data) => LoadResult(id, key: key, data: data)`) and route the
  receipt by `r.id`. This is the **most-forgettable rule** — omit it and the app is
  silently single-instance-only. See **Async Loading** below for the full keyed story.
- **Derive collection ids from stable domain keys (`user.id`), never the list index.**
  Indexes shift on insert/delete, so an index-derived id routes a result onto the wrong row.
- **Widgets never perform async I/O.** The app drives _every_ fetch via `Task` and routes
  the result home by id; a widget signals "I need data" by _returning a `LoadRequest`_, not
  by fetching. It is tempting to `await dataSource.getChildren(...)` inside the widget —
  don't: that loses the runtime cancellation token and races the message loop.
- **An id that resolves to no owner is logged + dropped, never silently ignored** — the
  observable failure that reference-addressing could not give you.

## Async Loading

ListView, TableView, and TreeView load data the **same way**: one keyed load-slot state
machine in `lib/src/load/`, shared by all three (and by future externally-loaded widgets like
a combobox). Full rationale: `specs/a7-async-load-lifecycle.md`. The doctrine extends
Widget→App Addressing above — a load is just an id-addressed request whose result must come
home — so read that section first.

### A load is a keyed request the widget owns

The widget owns the **state machine**; the app owns the **I/O**. Concretely:

- A widget has one or more **load slots**, each named by a **typed sealed key `K`** (never a
  string, never null): `ListLoadKey.self`, `TableLoadKey.{forward,backward}`,
  `TreeLoadKey` = `RootsKey()` / `PathKey(path)`.
- Each slot is `idle → loading → error`; **success clears it back to idle**.
- The widget flips a slot **→ loading the instant it returns the `LoadRequest`** — the
  self-dedup that stops the same data being fetched twice lives _inside_ the widget, not in
  an app-side `!isLoading` guard.
- The widget flips it **→ idle/error when the matching `LoadResult` lands** in `applyLoad`.
- The app's only job is the I/O ferry: see the `LoadRequest`, fire a `Task`, thread
  `(id, key)` into the `LoadResult`. **The widget never awaits.**

### Shared primitives (`lib/src/load/`)

- `LoadTracker<K>` — the keyed state machine. `begin`/`complete`/`fail`/`stateFor`/`errorFor`,
  plus `isLoading([key])` (bare = any slot in flight). Each model **embeds one**.
- `LoadRequest(id, {key})` — a `Cmd`, a pure "I need data for (id, key)" with no payload.
  Replaces the deleted `ListLoadMoreCmd`/`TableLoadMoreCmd`; the _load aspect_ of a tree
  expand is also a `LoadRequest` (see TreeView below).
- `LoadResult<D>(id, {key, data, error})` — a `Msg` carrying the outcome home. `D` is the
  payload type at the construction site (type-safe `onSuccess`); the registry routes the
  erased `LoadResult<Object?>`, so `applyLoad` casts `data` **once** internally — inherent to
  a heterogeneous registry, not a smell.
- `Loadable` — `String get id` + `void applyLoad(LoadResult<Object?>)`. The app keeps a
  `Map<String, Loadable>` and routes every result with one generic line.

Each model exposes **domain-named read-only getters** over its tracker (`isLoading([key])`,
`isPathLoading(path)`, `errorFor(key)`) — there is **no** public mutable `isLoading` setter
anymore (the old leaky state machine), and **no** `loadError` shorthand: read errors uniformly
through `errorFor(key)`. The id-guard and the **staleness guard** ("is this key still
expected?") both live _inside_ `applyLoad` — a late result for a collapsed branch or a
superseded query is dropped, not applied.

### Data ownership — three roles, three homes

A widget's "data source" decomposes into three roles that live in three places. Internalizing
this is most of understanding the load model:

| Role          | What it is                              | Lives where    | Shape                                           |
| ------------- | --------------------------------------- | -------------- | ----------------------------------------------- |
| **read-view** | the items the widget renders against    | widget contract (injected) | `DataView<T>` — sync, read-only     |
| **buffer**    | the in-memory store that grows as data lands | widget-owned | a `DataBuffer<T>` the model mutates in `applyLoad` |
| **fetcher**   | the origin / async I/O                   | **app**-owned  | a plain closure; **never on a widget model**    |

- `DataView<T>` (`length`/`itemAt`/`hasMore`) is **synchronous by contract.** `itemAt` MUST
  NOT await. "Data not here yet" is `LoadTracker` state + a placeholder — **never** an awaited
  read. The instant a read could await, the fetcher has crept back into the widget (the §A3
  bug a2.1 killed). `DataView.fromList(items)` is the static one-liner (`hasMore = false`,
  never loads).
- **Mutation lives only on the concrete `DataBuffer<T>`** (`append`/`replace`/`clear` +
  settable `hasMore`), never on the `DataView` read face — so nothing rendering through the
  read-view can mutate it, and a computed/virtual backing (read-only, never loads) isn't forced
  to implement a write it can't honor. `DataView` (read) ↔ `DataBuffer` (mutable impl) is the
  naming pair.
- The **strategy** — append (List, Table-forward) vs replace (combobox) — is the widget's
  `applyLoad` picking the primitive, not buffer config.
- List + Table share `DataView<T>` (Table's `T` is a row `Map`; columns are model config).
  **TreeView is exempt** — its shape is hierarchical, so it keeps its node read path and gets
  no `DataView`. The uniform thing is the role decomposition, not one interface type.

### Per-widget map

- **TreeView** — `RootsKey()` + `PathKey(path)`. `loadRoots()` returns the roots request;
  **expand returns `Batch([TreeExpandCmd, LoadRequest(key: PathKey(path))])` on a cache-miss**,
  `TreeExpandCmd` alone on a hit. `TreeExpandCmd` is now a pure **event on every expansion**
  (the load is the separate `LoadRequest`), so the app flattens the `Batch` to count expansions
  on the event and fetch on the request. Collapsing a node cancels its slot, so a late child
  result drops. A failed child renders an **error placeholder** (`errorIndicator` config)
  instead of spinning forever — the bug this whole change fixes.
- **TableView** — `TableLoadKey.forward` / `.backward`. Navigation is **never frozen** during a
  load (the old blanket `if (isLoading) return null` is gone); the only gate is per-slot
  self-dedup, so forward and backward can run concurrently. The model **reserves** the page
  number when it begins a slot (`pendingPage(key)`) because a `LoadResult` carries no page
  number and recomputing it at apply-time is unsafe under concurrent fwd+back. A failed slot
  retries on the next near-edge navigation (no collapse affordance like Tree).
- **ListView** — `ListLoadKey.self` (single slot, append). Renders through a settable
  `DataView<T> dataView` field; `applyLoad` casts it to `DataBuffer` to `append`. `hasMore` is
  **derived** on append (`page.length >= pageSize`, a new `pageSize` config, default 20),
  mirroring Table-forward. The search example reassigns the whole backing
  (`dataView = DataView.fromList(filtered)`) — a synchronous filter, not a load.

### Total count is exempt — a deliberate one-shot

Total row count gets **no load slot**. The `LoadTracker` exists to recover from _malignant_
failures (a page/child fetch that spins forever); a missing count is _benign_ — it just leaves
the scrollbar indeterminate. So count stays a TableView app-fired one-shot
(`Task(fetchCount, onSuccess: (n) => CountLoadedMsg(id, n))`, `onError → NoneMsg`); it has no
loading/error/retry machinery by design. The scrollbar reads only `int? total` (null ⇒
indeterminate thumb); scroll **composes with** load, it does not merge — `total` going unknown
→ 10 → 20 as pages land is expected, not a glitch.

### The payoff — one generic handler shape

Result routing is **one line, identical for every loadable widget**; the only per-widget code
is the request→fetch mapping the app owns. From `tree_view_async.dart`:

```dart
// 1. Result routing — generic; installs the data and clears/fails the slot:
if (msg case final LoadResult<Object?> r) {
  if (r.id == model.tree.id) model.tree.applyLoad(r);
  return (model, null);
}

// 2. Request → Task — the ONE domain-specific bit: pick the fetch by (id, key):
Cmd fetchFor(AppModel model, LoadRequest req) => Task(
  () => switch (req.key) {
    RootsKey()           => model.treeData.getRoots(),
    PathKey(:final path) => model.treeData.getChildren(path),
    _                    => Future.value(<TreeNode<Category>>[]),
  },
  onSuccess: (data) => LoadResult(req.id, key: req.key, data: data),
  onError:  (e)    => LoadResult(req.id, key: req.key, error: e));
// kick off on init: fetchFor(model, model.tree.loadRoots());
// honor a request:  if (cmd case LoadRequest r when r.id == model.tree.id) fetchFor(model, r);
```

The status box just reads getters (`model.tree.isLoading` / `errorFor(...)`). No flag-flipping,
no per-message guards, no per-widget command types. **A model-held `loader:` closure (Layer 3)
and an app-side generic `routeLoad` helper were both considered and parked** — each hides the
`Task` site and _reads_ like the widget holding I/O, even when compliant. Ship the explicit
handler; revisit only if it proves tedious.

See also `a2-cmd-roles.md` (the three `Cmd` roles — `LoadRequest`/`LoadResult` are a
widget→app event + its result) and `a2.1-id-addressing.md` (id routing; widgets never do I/O).

## Current Widgets

- `TextInput` / `TextInputModel` - single-line text input with readline keybindings

## Code Style

Same as root: `very_good_analysis`, strict mode, `public_member_api_docs` required.
