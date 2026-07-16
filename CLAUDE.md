# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiko is a Dart framework for building terminal user interfaces: double-buffered rendering, a Bubble Tea-style Model-View-Update runtime, and Flutter-style layout via the `plume` package. It began as a port of [Ratatui](https://ratatui.rs/) and has since diverged into its own design.

## Monorepo Structure

Dart workspace with four packages:

- `packages/plume` - Flutter-style, solver-free layout engine for cell grids (geometry only; see `packages/plume/README.md`)
- `packages/kiko_core` - core TUI library (rendering, widgets, MVU runtime); lays out via plume
- `packages/kiko_widgets` - higher-level widgets (text input, list/table/tree, etc.)
- `packages/kiko_log` - logging

## Commands

Run from package directory (e.g., `packages/kiko_core`):

```bash
make test                           # run all tests
make testf FILE=test/foo_test.dart  # single test
make lint                           # static analysis
make format                         # format code
make cover                          # coverage report
```

**Testing tip:** Use `dart test -r failures-only` to avoid ANSI progress output flooding. Shows one-line summary on success, detailed output only on failure.

## Architecture

### Core Rendering Flow

1. `Terminal` manages double-buffered rendering via two `Buffer` instances
2. `Terminal.draw()` accepts callback receiving `Frame`
3. UI is composed from `View`s; `View.build()` inflates a fresh plume `Node` each frame, and `frame.render(view)` lays it out and paints it
4. `Buffer.diff()` computes minimal changes between frames
5. `Backend` (abstract) handles actual terminal I/O

### MVU (Model-View-Update) Pattern

Kiko uses MVU in the **Bubble Tea** style (Go), _not_ Elm: models are mutable components, not immutable values. `update` returns `(model, cmd)`, but you are expected to mutate `model` in place and return the same reference — purity is neither assumed nor rewarded here (the widget models beneath you are mutable too). You therefore do _not_ get Elm-style guarantees: no time-travel, identity memoization, or free snapshots.

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

`run()` completes with the exit code under every backend — the framework never calls
`exit()` itself. Terminating the process is the app's call: `exit(await
Application(...).run(...))`. Two gotchas: Dart ignores `main`'s return value (`run()`'s
result must reach `exit()` or a top-level `exitCode` assignment, or nothing happens), and
if the app prints anything after `run()` completes, `await stdout.flush()` before calling
`exit()` — termlib writes through `dart:io stdout`'s async buffer.

`update`'s third argument is an `UpdateContext`: the read-only environment the runtime
supplies for a turn (the frame's `HitMap` and the viewport `Rect`). Take it as `_` when
you have no use for it.

`copyWith`-style immutable models are still allowed and clean for small value-like models (see `kiko_core/example/counter.dart`); mutability is the default for anything app-sized.

**Key types:**

- `Msg` - events (KeyMsg, PointerMsg, TickMsg, FrameTickMsg, InitMsg, ResizeMsg, custom)
- `Cmd` - side effects (Quit, Tick, AsyncCmd, Batch, Emit)
- `MvuRuntime` - unified message queue, frame/tick timers, async task handling

Widget→app events and effects address their target by **stable `id`** (carried by value),
not by object reference — and async results must thread that id home. See the addressing
sections in `packages/kiko_core/CLAUDE.md` and `packages/kiko_widgets/CLAUDE.md`.

### Event System

Unified stream architecture where all sources push to single FIFO queue:

- **FrameTick** (internal, 60fps default) - drives render loop
- **Tick** (user timer) - for app logic (clocks, polling)
- **Terminal events** - keys, mouse, focus, paste, resize

Processing flow:

1. All events queue in FIFO order
2. Model updates on every message
3. Render only on FrameTickMsg
4. Stale frames dropped (>2 frame intervals old)
5. Mouse moves/drags coalesced (keeps latest)

```dart
Application(
  fps: 60,  // frame rate (default 60)
  // ...
)
```

### Key Components

- `Buffer` - grid of `Cell`s (grapheme + fg/bg/modifiers)
- `Container` (plume) - borders/titles/padding around a child
- `Line`/`Text` - styled text primitives (Views)

### Layout System

Layout is handled by the `plume` package: a Flutter-style box model — constraints
flow down, sizes flow up, parents place children, leaves paint. No constraint
solver. See `packages/plume/README.md` for the model and API.

### Dependencies

`plume` (layout), plus the local termkit monorepo at `../termkit/packages/`:

- `termlib` - terminal control (raw mode, cursor, colors)
- `termparser` - input parsing (keys, mouse, events)
- `termunicode` - Unicode width calculation
- `termansi` - ANSI escape sequences

## Code Style

- Uses `very_good_analysis` lints
- Strict casts/inference/raw-types enabled
- `public_member_api_docs` required

## Coding Rules

- Identify anti-patterns BEFORE writing code, not after
- If a request leads to a workaround, pause and discuss
- Explain what pattern is being violated
- Propose root-cause fixes, not band-aids

<!-- mikos:start -->
## Task tracking — mikos

This project tracks specs, plans, notes, and tasks in **mikos**. Start with
`mikos agent --json` to discover the machine interface, then run
`mikos context --json` to orient and `mikos next --json` for actionable work.

A mikos **task** is a durable, tracked work item (it has a status and lineage) — not
your ephemeral session to-do list. When the user says "the task," they mean a mikos
item. Create durable work with `mikos new` / `mikos capture` and move it with the
status verbs (`ready` / `start` / `done` / `drop` / `block`).

The CLI is your **only** interface to mikos, and the `id` is your only handle. Make no
assumptions about — and never read, probe, or modify — where or how mikos stores things
(paths, file layout, version control); that is the tool's private business. If the CLI
can't do something you need — or you hit a rough edge — report it as a gap to fix in the
CLI rather than reaching for the files.
<!-- mikos:end -->

### Writing mikos items

Every item must be readable cold, by a person with no memory of the session that
wrote it. Do **not** imitate the register of older items — they predate this rule.

1. **Plain sentences.** No invented shorthand or codenames. A term that isn't in
   the codebase or ordinary English gets defined on first use — or doesn't appear.
2. **Self-contained.** The body states the problem and the work in its own words.
   References to other items are "see also" pointers; they must never be required
   reading to understand the item.
3. **Phase labels stay home.** "P1"/"P3a" mean something only inside the plan that
   defines them. Never put them in titles or in other items' bodies — say what the
   phase does instead.
4. **Titles are complete phrases.** Under 80 chars, never truncated mid-thought.
   Write the title last, after the body is clear.
5. **Say what done looks like.** A task ends with one plain sentence: "Done when …".
6. **Density is not a virtue.** Commit hashes, file paths, and ids are welcome as
   parentheticals, but the sentence around them must survive their removal.
