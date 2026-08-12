# Architecture: rendering, MVU, and the event loop

How a kiko application runs: the rendering flow, the Model-View-Update loop,
the event queue, and text measurement. Layout is the `plume` package's job;
`packages/plume/README.md` documents it.

## Core rendering flow

1. `Terminal` renders through two `Buffer` instances (double buffering).
2. `Terminal.draw()` takes a callback and hands it a `Frame`.
3. The app composes its UI from `View`s.
4. `View.build()` inflates a fresh plume `Node` each frame.
5. `frame.render(view)` lays the node out and paints it.
6. `Buffer.diff()` computes the minimal change set between the two buffers.
7. The `Backend` performs the terminal I/O (`docs/backend.md`).

**Key types:**

- `Buffer` — a grid of `Cell`s. A cell holds a grapheme, foreground and
  background colors, and modifiers.
- `Container` (plume) — a border, a title, and padding around one child.
- `Line` / `Text` — styled text primitives; both are `View`s.

## MVU (Model-View-Update)

Kiko uses MVU in the **Bubble Tea** style, not the Elm style: models are
mutable. `update` returns `(model, cmd)`. Mutate the model in place and
return the same reference; the widget models inside your model are mutable
too. Elm's purity guarantees do not transfer: no model snapshots, no
identity-based memoization, no history replay.

```dart
exit(
  await Application(title: 'App').run(
    init: MyModel(),
    update: (model, msg, ctx) => switch (msg) {
      KeyMsg(key: 'q') => (model, const Quit()),
      TickMsg(:final elapsed) => (model.tick(elapsed), null),
      _ => (model, null),
    },
    view: (model, frame) => frame.render(myWidget(model)),
  ),
);
```

A `KeyMsg` is a keystroke: a press or an auto-repeat. A key release arrives
as its own class, `KeyReleaseMsg`, and a bare modifier tap as
`ModifierKeyMsg`. The case `KeyMsg(key: 'q')` above therefore never fires on
a release or a modifier tap. The full keyboard contract is
`docs/keyboard.md`.

`run()` completes with the exit code under every backend. The framework
never calls `exit()`. Terminating the process is the app's job:
`exit(await Application(...).run(...))`. Two rules follow. Pass `run()`'s
result to `exit()` or to the top-level `exitCode`; Dart ignores `main`'s
return value, so the code is lost any other way. If the app prints after
`run()` completes, `await stdout.flush()` before calling `exit()`; termlib
writes through `dart:io stdout`, which buffers asynchronously.

`update`'s third argument is an `UpdateContext`: the read-only environment
the runtime supplies for one `update` call. It carries the frame's `HitMap`
and the viewport `Rect`. Take it as `_` when you have no use for it.

Immutable `copyWith`-style models remain fine for small value-like models
(`kiko_core/example/counter.dart`). Mutability is the default for anything
app-sized.

**Key types:**

- `Msg` — an event: `KeyMsg`, `KeyReleaseMsg`, `ModifierKeyMsg`,
  `PointerMsg`, `TickMsg`, `FrameTickMsg`, `InitMsg`, `ResizeMsg`, or a
  custom app class.
- `Cmd` — a requested effect: `Quit`, `Tick`, `AsyncCmd`, `Batch`, `Emit`.
- `MvuRuntime` — owns the message queue, the frame and tick timers, and
  async task handling.

Widget models are `Component`s: each has a stable id and its own update
contract (`docs/components.md`).

## The event loop

Every event source pushes to one FIFO queue. The runtime coalesces
high-rate messages and renders only on `FrameTickMsg`.

```
┌─────────────────────────────────────────────────────────────┐
│  Terminal events ──────┐                                    │
│                        │                                    │
│  User Tick timer ──────┼──► Unified Queue ──┐               │
│                        │                    │               │
│  AsyncCmd results ─────┘                    │               │
│                                             ▼               │
│  FrameTick timer ──────────────────────► MAIN LOOP          │
│  (60fps, always on)                        │                │
│                                             ▼               │
│                                    ┌─────────────────┐      │
│                                    │ 1. Coalesce     │      │
│                                    │ 2. Drop stale   │      │
│                                    │ 3. Update model │      │
│                                    │ 4. Render       │      │
│                                    └─────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Event sources

| Source          | Description                   | Coalesceable                   | Droppable      |
| --------------- | ----------------------------- | ------------------------------ | -------------- |
| Terminal events | Keys, pointer, focus, paste   | Pointer moves/drags and resizes | No             |
| FrameTick       | Internal render timer (60fps) | No                             | Yes (if stale) |
| Tick            | User timer for app logic      | No                             | No             |
| AsyncCmd        | Async task completions        | No                             | No             |

### Processing flow

1. **Coalesce** — merge each group of coalesceable messages, keeping only
   the latest per `coalesceKey`.
2. **Get message** — take the next message from the queue, in FIFO order.
3. **Drop stale** — skip a `FrameTickMsg` older than two frame intervals.
4. **Update model** — run the app's `update` with the message.
5. **Render** — paint, on `FrameTickMsg` only.

### Key types

**`Msg` properties:**

- `droppable` — the runtime may skip this message when it is stale
  (`FrameTickMsg` only).
- `coalesceable` — the runtime may merge this message with others that
  share its `coalesceKey`.
- `coalesceKey` — the grouping key for coalescing.

**`FrameTickMsg` fields:**

- `delta` — time since the last frame.
- `frameNumber` — a monotonic frame counter.
- `timestamp` — the basis for the staleness check.

### Configuration

```dart
Application(
  fps: 60,          // frame rate (default 60)
  eventTimeout: 10, // poll timeout in ms
)
```

### Implementation

- `MvuRuntime.coalesceQueue()` — merges coalesceable messages.
- `MvuRuntime.isStale(msg, fps)` — reports whether a droppable message is
  stale.
- `MvuRuntime.subscribeToEvents(stream)` — subscribes the queue to terminal
  events.
- `Terminal.events` — the broadcast stream of parsed events.

## Text measurement

One `TextMeasurer` — a `TermUnicodeMeasurer` by default — serves the whole
application session. `Application(measurer:)` and
`Terminal.create(measurer:)` own it. Every `Buffer` carries it as
`buffer.measurer`. `Frame.render(view)` takes no measurer of its own: it
lays out and paints through `buffer.measurer`. Layout and paint therefore
agree on every glyph's width.

The measurer is fixed for the life of the application and never passed per
call. A terminal's ambiguous-width behavior does not change mid-run, so one
measurer is enough.

Widgets that measure text reach the same measurer at layout time. Inside a
plume `Node`'s `performLayout`, it is `LayoutContext.measurer`. In a widget
model, it is the field the widget's view copies in during layout
(`TextInputModel.measurer`, `TableRenderer.measurer`, and siblings). Never
construct a bare `TermUnicodeMeasurer()`, and never do raw termunicode
width math.
