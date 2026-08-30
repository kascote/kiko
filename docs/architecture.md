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

An overlay — a popup, a modal — renders through `frame.renderLayer(view,
rect)` after the base render. The view paints into its own rect-sized
buffer, a clean slate, and composites opaquely onto the frame over the
rect. Cells the view never paints come out empty, so the base never shows
through an overlay (`docs/theming.md`, "Grounding an area").

A view that learns a layout fact during paint — how many rows a windowed
widget showed — hands it back as a frame report. It does not write into its
model. Paint code calls `BufferSurface.report(FrameReport)`; the frame keeps
the last report per widget id and report type; `CompletedFrame.reports`
carries them out of the draw. `Application` queues each report as a message
right after the frame commits, behind the frame's hit map. A report implements
`Addressed`, so a focus router delivers it to its owner by id
(`docs/components.md`); an app without a router matches on it in `update`.
The owner therefore reads the fact one message after the frame that produced
it, with `ctx.hits` describing that same frame.

A node reports under the path the paint walk gives it. The walk carries the
node's enclosing scope path on the surface (`BufferSurface.scopePath`), and
the node addresses its report to `HitTag.join(surface.scopePath, id)`. That
is the hit path the frame's hit map records for the same node, so a part
embedded under a composite's scope reports `combo/list` and the router
delivers it to the composite (`docs/mouse.md`, "Scopes"). A layer painted
through `renderLayer` starts from an empty scope path, as the hit map walks
each root from an empty prefix.

Paint reports a fact only when it differs from the fact the model already
holds. The view has both — the value it just measured and the model it
paints from — so that compare lives in paint. The runtime queues every
report a frame carries and keeps no memory between frames. A frame caused by
a report therefore settles: once the report lands, the model holds the fact,
and the next paint reports nothing ("The event loop").

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
      TickMsg(:final elapsed) => (model.tick(elapsed), const Tick(step, id: 'clock')),
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
  `PointerMsg`, `TickMsg`, `InitMsg`, `ResizeMsg`, a `FrameReport`, or a
  custom app class.
- `Cmd` — a requested effect the runtime performs, sealed to five cases (see
  "Commands the runtime executes" below).
- `MvuRuntime` — owns the message queue, the pending one-shot ticks, and
  async task handling.

Widget models are `Component`s: each has a stable id and its own update
contract (`docs/components.md`).

## The event loop

Every event source pushes to one FIFO queue. Nothing polls: the loop waits
on the queue and runs only when a message arrives. A frame follows every
processed message.

```
┌─────────────────────────────────────────────────────────────┐
│  Terminal events ──────┐                                    │
│                        │                                    │
│  One-shot Tick timers ─┼──► Unified Queue ──► MAIN LOOP     │
│                        │                       │            │
│  Task results ─────────┤                       ▼            │
│                        │             ┌──────────────────┐   │
│  Frame reports ────────┘             │ 1. Coalesce      │   │
│                                      │ 2. Update model  │   │
│                                      │ 3. Draw or defer │   │
│                                      └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Event sources

| Source          | Description                              | Coalesceable                    |
| --------------- | ---------------------------------------- | ------------------------------- |
| Terminal events | Keys, pointer, focus, paste, resize      | Pointer moves/drags and resizes |
| Tick            | A one-shot timer an `update` armed       | No                              |
| Task            | Async task completions                   | No                              |
| Frame reports   | Layout facts paint handed back           | No                              |

### Processing flow

1. **Coalesce** — merge each group of coalesceable messages, keeping only
   the latest per `coalesceKey`.
2. **Wait** — take the next message, in FIFO order. An empty queue waits
   until a message is queued or shutdown closes the queue.
3. **Update model** — run the app's `update` with the message. Every
   processed message marks the frame dirty.
4. **Draw or defer** — draw when one frame interval (`1 / fps`) has passed
   since the last draw. Otherwise keep draining while messages wait, so a
   burst paints once. Once the queue is empty, arm one timer for the rest of
   the interval; that timer's own message is a draw point.

`fps` is a ceiling on the draw rate. It never causes a frame. A message that
arrives after an idle stretch draws at once. A static application draws its
first frame and then none.

### The draw

Each draw builds the view, lays it out, paints, and commits. After the
commit the loop hands the frame's hit map to the runtime, queues the frame's
reports, and calls `Application.onFrame` with the `CompletedFrame`. A
terminal event emitted from `onFrame` resolves against that frame.

Paint reports a fact only when the model does not hold it yet ("Core
rendering flow"). A frame caused by a report paints from a model that now
holds the fact, reports nothing, and the loop idles.

### Ticks

`Tick(interval, id:, key:)` arms one timer and delivers one
`TickMsg(id, key:, elapsed:)` after `interval`. `elapsed` counts from
arming: the animation delta. An animation re-arms by returning `Tick` again
from its `TickMsg` case. When it stops re-arming, no more ticks arrive and
no more frames are drawn. Several ticks may be pending at once; `Quit`
cancels them.

`TickMsg` implements `Addressed`, so a focus router delivers it to the
widget registered under `id`, never to the focused widget
(`docs/focus-router.md`). An app-level animation picks an id no widget
claims; the router declines it and the app's own `update` handles it. A
composite scopes the ticks its parts arm, so the router resolves them to
the composite by prefix (`docs/components.md`).

`key` is the owner's generation. Bump it when the animation starts or
restarts. Drop a `TickMsg` whose key is stale instead of re-arming it, so a
restart never runs two chains at once.

```dart
KeyMsg(key: 'space') => (model..running = true..chain += 1, Tick(step, id: 'clock', key: model.chain)),
TickMsg(id: 'clock', :final key, :final elapsed) when model.running && key == model.chain =>
  (model..advance(elapsed), Tick(step, id: 'clock', key: model.chain)),
TickMsg() => (model, null), // stopped, or a stale generation: not re-armed
```

Worked examples: `packages/kiko_core/example/engine_hud.dart` (a sprite
animated from a re-armed tick) and `packages/kiko_core/example/timer.dart`
(a one-second chain with a generation key).
`packages/kiko_widgets/example/animation.dart` scopes ticks across a
composite's parts.

### Shutdown

`MvuRuntime.close` closes the queue. A loop waiting on the queue wakes and
returns. `Application.dispose(code)` and a signal both go through it, so a
shutdown that starts outside the loop never races a draw.

### Key types

**`Msg` properties:**

- `coalesceable` — the runtime may merge this message with others that
  share its `coalesceKey`.
- `coalesceKey` — the grouping key for coalescing.

**`TickMsg` fields:**

- `id` — the owner the tick is addressed to.
- `key` — the generation the owner armed it with.
- `elapsed` — time since the `Tick` was armed.

**Commands the runtime executes:** `Cmd` is sealed to five cases — `Quit`,
`Emit`, `Tick`, `Task`, `Batch`. A `Task` outcome with no handler queues
nothing.

### Configuration

```dart
Application(
  fps: 60, // the ceiling on the draw rate (default 60)
)
```

### Implementation

- `MvuRuntime.coalesceQueue()` — merges coalesceable messages.
- `MvuRuntime.nextMsg()` — waits for the next message; answers null once
  the queue is closed.
- `MvuRuntime.close()` — closes the queue and wakes a waiting `nextMsg`.
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
