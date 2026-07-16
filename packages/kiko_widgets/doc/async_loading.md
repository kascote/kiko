# Async loading: the keyed load-slot machine

The full reference for how ListView, TableView and TreeView load data. The
contract summary and the never-rules live in `../CLAUDE.md` (section "Async
Loading"); this file holds the primitives, the per-widget map, and the worked
handler. The doctrine extends `../CLAUDE.md`'s "Widget→App Addressing" — a load
is just an id-addressed request whose result must come home — so read that
section first.

All three widgets (and future externally-loaded widgets like a combobox) share
one keyed load-slot state machine in `lib/src/load/`.

## A load is a keyed request the widget owns

The widget owns the **state machine**; the app owns the **I/O**. Concretely:

- A widget has one or more **load slots**, each named by a **typed sealed key
  `K`** (never a string, never null): `ListLoadKey.self`,
  `TableLoadKey.{forward,backward}`, `TreeLoadKey` = `RootsKey()` /
  `PathKey(path)`.
- Each slot is `idle → loading → error`; **success clears it back to idle**.
- The widget flips a slot **→ loading the instant it returns the
  `LoadRequest`** — the self-dedup that stops the same data being fetched twice
  lives _inside_ the widget, not in an app-side `!isLoading` guard.
- The widget flips it **→ idle/error when the matching `LoadResult` lands** in
  `applyLoad`.
- The app's only job is the I/O ferry: see the `LoadRequest`, fire a `Task`,
  thread `(id, key)` into the `LoadResult`. **The widget never awaits.**

## Shared primitives (`lib/src/load/`)

- `LoadTracker<K>` — the keyed state machine.
  `begin`/`complete`/`fail`/`stateFor`/`errorFor`, plus `isLoading([key])`
  (bare = any slot in flight). Each model **embeds one**.
- `LoadRequest(id, {key})` — a `Cmd`, a pure "I need data for (id, key)" with
  no payload. Replaces the old `ListLoadMoreCmd`/`TableLoadMoreCmd`; the _load
  aspect_ of a tree expand is also a `LoadRequest` (see TreeView below).
- `LoadResult<D>(id, {key, data, error})` — a `Msg` carrying the outcome home.
  `D` is the payload type at the construction site (type-safe `onSuccess`); the
  registry routes the erased `LoadResult<Object?>`, so `applyLoad` casts `data`
  **once** internally — inherent to a heterogeneous registry, not a smell.
- `Loadable` — `String get id` + `void applyLoad(LoadResult<Object?>)`. The app
  keeps a `Map<String, Loadable>` and routes every result with one generic
  line.

Each model exposes **domain-named read-only getters** over its tracker
(`isLoading([key])`, `isPathLoading(path)`, `errorFor(key)`) — there is **no**
public mutable `isLoading` setter anymore (the old leaky state machine), and
**no** `loadError` shorthand: read errors uniformly through `errorFor(key)`.
The id-guard and the **staleness guard** ("is this key still expected?") both
live _inside_ `applyLoad` — a late result for a collapsed branch or a
superseded query is dropped, not applied.

## Data ownership — three roles, three homes

A widget's "data source" decomposes into three roles that live in three places.
Internalizing this is most of understanding the load model:

| Role          | What it is                                   | Lives where                | Shape                                              |
| ------------- | -------------------------------------------- | -------------------------- | -------------------------------------------------- |
| **read-view** | the items the widget renders against         | widget contract (injected) | `DataView<T>` — sync, read-only                    |
| **buffer**    | the in-memory store that grows as data lands | widget-owned               | a `DataBuffer<T>` the model mutates in `applyLoad` |
| **fetcher**   | the origin / async I/O                       | **app**-owned              | a plain closure; **never on a widget model**       |

- `DataView<T>` (`length`/`itemAt`/`hasMore`) is **synchronous by contract.**
  `itemAt` MUST NOT await. "Data not here yet" is `LoadTracker` state + a
  placeholder — **never** an awaited read. The instant a read could await, the
  fetcher has crept back into the widget (the bug the id-addressing rework
  killed). `DataView.fromList(items)` is the static one-liner
  (`hasMore = false`, never loads).
- **Mutation lives only on the concrete `DataBuffer<T>`**
  (`append`/`replace`/`clear` + settable `hasMore`), never on the `DataView`
  read face — so nothing rendering through the read-view can mutate it, and a
  computed/virtual backing (read-only, never loads) isn't forced to implement a
  write it can't honor. `DataView` (read) ↔ `DataBuffer` (mutable impl) is the
  naming pair.
- The **strategy** — append (List, Table-forward) vs replace (combobox) — is
  the widget's `applyLoad` picking the primitive, not buffer config.
- List + Table share `DataView<T>` (Table's `T` is a row `Map`; columns are
  model config). **TreeView is exempt** — its shape is hierarchical, so it
  keeps its node read path and gets no `DataView`. The uniform thing is the
  role decomposition, not one interface type.

## Per-widget map

- **TreeView** — `RootsKey()` + `PathKey(path)`. `loadRoots()` returns the
  roots request; **expand returns
  `Batch([TreeExpandCmd, LoadRequest(key: PathKey(path))])` on a cache-miss**,
  `TreeExpandCmd` alone on a hit. `TreeExpandCmd` is a pure **event on every
  expansion** (the load is the separate `LoadRequest`), so the app flattens the
  `Batch` to count expansions on the event and fetch on the request. Collapsing
  a node cancels its slot, so a late child result drops. A failed child renders
  an **error placeholder** (`errorIndicator` config) instead of spinning
  forever — the bug this whole design fixes.
- **TableView** — `TableLoadKey.forward` / `.backward`. Navigation is **never
  frozen** during a load (the old blanket `if (isLoading) return null` is
  gone); the only gate is per-slot self-dedup, so forward and backward can run
  concurrently. The model **reserves** the page number when it begins a slot
  (`pendingPage(key)`) because a `LoadResult` carries no page number and
  recomputing it at apply-time is unsafe under concurrent fwd+back. A failed
  slot retries on the next near-edge navigation (no collapse affordance like
  Tree).
- **ListView** — `ListLoadKey.self` (single slot, append). Renders through a
  settable `DataView<T> dataView` field; `applyLoad` casts it to `DataBuffer`
  to `append`. `hasMore` is **derived** on append
  (`page.length >= pageSize`, a `pageSize` config, default 20), mirroring
  Table-forward. The search example reassigns the whole backing
  (`dataView = DataView.fromList(filtered)`) — a synchronous filter, not a
  load.

## Total count is exempt — a deliberate one-shot

Total row count gets **no load slot**. The `LoadTracker` exists to recover from
_malignant_ failures (a page/child fetch that spins forever); a missing count
is _benign_ — it just leaves the scrollbar indeterminate. So count stays a
TableView app-fired one-shot
(`Task(fetchCount, onSuccess: (n) => CountLoadedMsg(id, n))`,
`onError → NoneMsg`); it has no loading/error/retry machinery by design. The
scrollbar reads only `int? total` (null ⇒ indeterminate thumb); scroll
**composes with** load, it does not merge — `total` going unknown → 10 → 20 as
pages land is expected, not a glitch.

## The payoff — one generic handler shape

Result routing is **one line, identical for every loadable widget**; the only
per-widget code is the request→fetch mapping the app owns. From
`example/tree_view_async.dart`:

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

The status box just reads getters (`model.tree.isLoading` / `errorFor(...)`).
No flag-flipping, no per-message guards, no per-widget command types. **A
model-held `loader:` closure and an app-side generic `routeLoad` helper were
both considered and parked** — each hides the `Task` site and _reads_ like the
widget holding I/O, even when compliant. Ship the explicit handler; revisit
only if it proves tedious.
