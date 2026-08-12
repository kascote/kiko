# Async loading: keyed load slots, paging, and demand

The full reference for how ListView, TableView and TreeView load data: the
primitives, the per-widget map, and the worked handler. These rules extend
"Widget→app addressing" in `docs/components.md` — a load is an id-addressed
request whose result must come home — so read that section first.

All three widgets (and future externally-loaded widgets like a combobox) share
one keyed load-slot state machine in `packages/kiko_widgets/lib/src/load/`.

## A load is a keyed request the widget owns

The widget owns the **state machine**; the app owns the **I/O**. Concretely:

- A widget has one or more **load slots**, each named by a **typed key `K`**
  (never a string, never null): `ListLoadKey.self`, `TablePageKey(page)`,
  `TreeLoadKey` = `RootsKey()` / `PathKey(path)`. **A key names the thing
  being loaded** — a page number, a branch path — never a direction or an
  intent.
- Each slot is `idle → loading → error`; **success clears it back to idle**.
- The widget flips a slot **to loading the instant it returns the
  `LoadRequest`**. The deduplication that stops the same data being fetched
  twice therefore lives *inside* the widget, not in an app-side `!isLoading`
  guard.
- The widget flips the slot **to idle or error when the matching `LoadResult`
  lands** in `applyLoad`.
- The app performs the I/O, and only the I/O: it sees the `LoadRequest`,
  fires a `Task`, and threads `(id, key)` into the `LoadResult`. **The widget
  never awaits.**

### Every request resolves its slot — three replies, no fourth

A widget marks a slot loading the instant it emits the request. It will not
ask again while it believes the fetch is on its way. A request the app never
answers therefore leaves those rows painting a placeholder forever: the
widget's own bookkeeping can never produce that permanently-unloadable state,
but an unanswered request produces it from the app side. So the app has
exactly three replies, and `return (model, null)` is a bug:

| Reply | Build it with | What the widget learns |
| ----- | ------------- | ---------------------- |
| **data** | `fetchInto(req, source)`, or a hand-rolled `Task` | installs the rows; a short page records where the data ends |
| **error** | `LoadResult(id, key: key, error: e)`, or `declineLoad(req, error: …)` | the slot fails, paints its error, and retries on the next demand pass |
| **refusal** | `declineLoad(req)` | *nothing* — the slot returns to idle, placeholders stay, no end-of-data is recorded |

A refusal is for policy ("do not fetch orders while a sync is running"):
nothing failed, so nothing should paint an error. A refusal needs its own
reply shape because an empty success means "the data ends here" — exactly
what a refusal must not record. **An app that reports failures from results
must check `cancelled` before `ok`.** `ok` is false for a refusal too, so
`r.ok ? null : 'Failed: ${r.error}'` alone prints "Failed: null" the first
time the app declines anything. An id that matches nothing wired gets the
*error* reply instead, so an unwired widget fails visibly rather than showing
a placeholder no one will fill.

**Recovery after a refusal is the app's move.** A refusal deliberately never
re-triggers demand — a standing refusal would otherwise become a request
every frame. When the app is ready to load again, it either runs the widget's
demand pass itself or marks it dirty (`table.markDemandDirty()`) and lets the
frame-tick demand case run it.

## Shared primitives (`packages/kiko_widgets/lib/src/load/`)

- `LoadTracker<K>` — the keyed state machine:
  `begin`/`complete`/`fail`/`stateFor`/`errorFor`, plus `isLoading([key])`
  (bare = any slot in flight). Each model **embeds one**.
- `LoadRequest(id, {key})` — a `Cmd`: a pure "I need data for (id, key)" with
  no payload. The load half of a tree expand is also a `LoadRequest` (see
  TreeView below).
- `LoadResult<D>(id, {key, data, error})` — a `Msg` carrying the outcome
  home. `D` is the payload type at the construction site (type-safe
  `onSuccess`); the registry routes the erased `LoadResult<Object?>`, so
  `applyLoad` casts `data` **once** internally — inherent to a heterogeneous
  registry, not a smell.
- `Loadable` — `String get id` + `void applyLoad(LoadResult<Object?>)`. The
  app keeps a `Map<String, Loadable>` and routes every result with one
  generic line.
- `PageWindow<T>` — the sparse page cache the windowed widgets hold: pages by
  number, which pages are present, which pages a viewport still needs
  (`missing`), page-aligned eviction, and end-of-data as "the last page that
  exists". The page is the unit of everything, so a window with pages 0 and 4
  says exactly that instead of claiming a range with holes inside it.
  Retention is **relative** — the pages the viewport needs plus `keepPages`
  more on each side — which makes a load→evict→reload cycle unrepresentable.
- `PageSource<T>` + `PageResult<T>` — the app-side source interface: index
  addressed, owning the page size, `Future<PageResult<T>> read(int page)`.
  `PageSource.offset(...)` wraps an offset/limit query. `PageSource.cursor(...)`
  wraps a token chain: it caches the token at each page boundary, serializes
  its own walk, and re-chunks whatever row counts the server returns.
- `fetchInto(req, source)` / `declineLoad(req, {error})` — the per-request
  helpers. `fetchInto` threads `(id, key)` into the result **structurally**,
  so the rule most often forgotten cannot be forgotten. It also converts a
  `read` that throws into a failed load rather than an unhandled asynchronous
  error.
- `statusFor(keys, loads, isPresent)` → `SliceStatus.{ready, filling,
  stalled, failed}` — what a view is about to paint. `stalled` (missing,
  nothing coming) is the point: it names every permanent failure, so a test
  can assert on it instead of a person looking at a blank table. It is never
  a debug assert — an app refusing a load on policy produces the same state
  legitimately.

Each model exposes **domain-named read-only getters** over its tracker
(`isLoading([key])`, `isPathLoading(path)`, `errorFor(key)`). A model has
**no** public mutable `isLoading` setter and **no** `loadError` shorthand:
read errors uniformly through `errorFor(key)`.
The id guard and the **staleness guard** ("is this key still expected?") both
live *inside* `applyLoad` — a late result for a collapsed branch or a
superseded query is dropped, not applied.

## Data ownership — three roles, three homes

A widget's "data source" decomposes into three roles that live in three places.
Internalizing this is most of understanding the load model:

| Role          | What it is                                   | Lives where                | Shape                                              |
| ------------- | -------------------------------------------- | -------------------------- | -------------------------------------------------- |
| **read-view** | the items the widget renders against         | widget contract (injected) | `DataView<T>` — sync, read-only                    |
| **buffer**    | the in-memory store that grows as data lands | widget-owned               | a `DataBuffer<T>` the model mutates in `applyLoad` |
| **fetcher**   | the origin / async I/O                       | **app**-owned              | a closure or a `PageSource<T>`; **never on a widget model** |

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
  roots request. **Expand returns
  `Batch([TreeExpandCmd, LoadRequest(key: PathKey(path))])` on a cache miss**,
  and `TreeExpandCmd` alone on a hit. `TreeExpandCmd` is a pure **event on
  every expansion** (the load is the separate `LoadRequest`), so the app
  flattens the `Batch` to count expansions on the event and fetch on the
  request. Collapsing a node cancels its slot, so a late child result drops.
  A failed child renders an **error placeholder** (`errorIndicator` config);
  it never spins forever.
- **TableView** — `TablePageKey(page)`, one slot per page, so any number of
  pages can be in flight and a result places itself: the page travels in the
  key (`(req.key as TablePageKey).page`), and nothing has to remember what
  was reserved. Navigation is **never frozen** during a load. Loading is
  **demand-driven**: every message that moves the viewport runs `demand()`,
  which asks for the pages the viewport covers (widened by `loadThreshold`)
  and does not have, capped by `maxConcurrentLoads`. A long jump therefore
  fetches its destination first, and a hole in the middle of the window is
  re-requested like any other absence. One pass can return several requests
  as a `Batch`; **the app flattens it**. Eviction drops whole pages by
  distance from the viewport, keeping `keepPages` beyond what it needs. A
  failed page retries on the next demand pass.

  Two app-side obligations, both one line:

  ```dart
  // 1. Run demand on the frame tick. A resize reveals rows through the paint
  //    path, where a widget cannot return a command; a page landing frees a
  //    slot the in-flight cap truncated. This case covers both, and the model
  //    logs a warning if it notices the case missing.
  if (msg is FrameTickMsg) return (model, fetchAll(model, model.table.demandIfDirty()));

  // 2. Answer every request (above) — with rows, an error, or declineLoad.
  ```
- **ListView** — `ListLoadKey.self` (single slot, append). Renders through a
  settable `DataView<T> dataView` field; `applyLoad` casts it to `DataBuffer`
  to `append`. `hasMore` is **derived** on append
  (`page.length >= pageSize`, a `pageSize` config, default 20) — the same
  short-page rule the table's page window applies. The search example reassigns the whole backing
  (`dataView = DataView.fromList(filtered)`) — a synchronous filter, not a
  load.

## Total count is exempt — a deliberate one-shot

Total row count gets **no load slot**. The `LoadTracker` exists to recover
from failures that leave rows stuck — a page or child fetch that would
otherwise spin forever. A missing count leaves nothing stuck; it only leaves
the scrollbar indeterminate. So count stays a TableView app-fired one-shot
(`Task(fetchCount, onSuccess: (n) => CountLoadedMsg(id, n))`,
`onError → NoneMsg`), or the source reports it as `PageResult.totalCount`
when it knows it. Count has no loading, error, or retry machinery by design.
A table that has the count knows which pages exist and can jump straight to
the end; one without it learns where the data stops from the first short
page. The scrollbar reads only `int? total` (null ⇒ indeterminate thumb);
scroll **composes with** load, it does not merge — `total` going unknown → 10
→ 20 as pages land is expected, not a glitch.

## The payoff — one generic handler shape

Result routing is **one line, identical for every loadable widget**; the only
per-widget code is the request→fetch mapping the app owns. From
`packages/kiko_widgets/example/tree_view_async.dart`:

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

For a windowed widget over a `PageSource`, the same shape gets shorter,
because `fetchInto` writes the `Task` and `declineLoad` writes the refusal.
From `packages/kiko_widgets/example/table_view_paginated.dart`:

```dart
// One request → one fetch. Explicit cases, read top to bottom.
Cmd fetchFor(AppModel m, LoadRequest r) {
  if (r.id == m.products.id) return fetchInto(r, m.productsSource);
  if (r.id == m.orders.id) {
    if (m.syncing) return declineLoad(r);   // policy, where you would look for it
    return fetchInto(r, m.ordersSource);
  }
  return declineLoad(r, error: 'no source wired for ${r.id}');
}

// A demand pass can ask for several pages at once, so flatten what comes back.
Cmd? fetchAll(AppModel m, Cmd? cmd) {
  final requests = switch (cmd) {
    final LoadRequest r => [r],
    Batch(:final cmds) => cmds.whereType<LoadRequest>().toList(),
    _ => const <LoadRequest>[],
  };
  if (requests.isEmpty) return cmd;
  return Batch([for (final r in requests) fetchFor(m, r)]);
}
```

The status box just reads getters (`model.tree.isLoading` / `errorFor(...)`,
`table.viewportStatus`, `table.isLoadingAbove`). No flag-flipping, no
per-message guards, no per-widget command types.

## The boundary rule: per-request helpers, never per-app loops

**Kiko ships helpers that handle one request; it never ships the loop over an
app's sources.** `fetchInto` and `declineLoad` each take a single
`LoadRequest`, so an app that needs different treatment for one widget writes
a different case and simply does not call them there.

A `routeLoad(cmd, sources)` helper would own the iteration instead, and every
exception to it would then work against the helper: the app hoists the
exception above the loop, or hides it inside a wrapped source — where it runs
*inside* the fetch, after the request was already accepted and off the update
path. The same argument rejects a model-held `loader:` closure, which moves
fetch authorship toward the widget. Both stay out of kiko for that reason,
not for taste, and the signatures keep the rule checkable.

An app-built `Map<String, PageSource>` from id to source is ordinary app
code — not forbidden, not shipped, and not what these docs teach. A page
holds three or four loading widgets, where the map is more code rather than
less, and the first per-widget policy that arrives has to come back out of
it.

## Cookbook: retrying, app-side

Kiko ships no retry, backoff or error classification, and it will not.
Whether a failure is worth retrying is the only interesting part, and only
the app can write it. Kiko depends on no HTTP, database or RPC package, so it
cannot name the exception types, and a blind three-attempt retry is wrong
against an authorization failure or a missing row.

What kiko owes instead is that wrapping stays possible: `PageSource<T>` is a
plain interface an app can implement and decorate, and `fetchInto` converts a
thrown `read` into a failed load, so a wrapper that gives up and rethrows
resolves the page instead of leaving it loading forever.

```dart
/// Retries [inner] while the failure looks transient.
class RetryingSource<T> implements PageSource<T> {
  RetryingSource(this.inner, {this.attempts = 3});
  final PageSource<T> inner;
  final int attempts;

  @override
  int get pageSize => inner.pageSize;

  @override
  Future<PageResult<T>> read(int page) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await inner.read(page);
      } on Object catch (e) {
        // Only the app can write this line: it knows which failures deserve
        // another attempt. A 503 or a socket drop, yes; a 403 or a malformed
        // row, never.
        if (attempt >= attempts || !isTransient(e)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
  }
}
```

Wire it where the source is built (`RetryingSource(PageSource.offset(...))`);
nothing else in the app or the widget changes.
