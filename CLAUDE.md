# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiko is a Dart port of [Ratatui](https://ratatui.rs/) - a Rust TUI framework. Builds terminal user interfaces using double-buffered rendering and Model-View-Update architecture.

## Monorepo Structure

Dart workspace with two packages:

- `packages/kiko_core` - core TUI library (rendering, layout, widgets, MVU runtime)
- `packages/kiko_widgets` - higher-level widgets (text input, etc.)

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
3. Widgets implement `Widget.render(Rect area, Buffer buffer)`
4. `Buffer.diff()` computes minimal changes between frames
5. `Backend` (abstract) handles actual terminal I/O

### MVU (Model-View-Update) Pattern

Kiko uses MVU in the **Bubble Tea** style (Go), _not_ Elm: models are mutable components, not immutable values. `update` returns `(model, cmd)`, but you are expected to mutate `model` in place and return the same reference — purity is neither assumed nor rewarded here (the widget models beneath you are mutable too). You therefore do _not_ get Elm-style guarantees: no time-travel, identity memoization, or free snapshots.

```dart
await Application(title: 'App').run(
  init: MyModel(),
  update: (model, msg) => switch (msg) {
    KeyMsg(key: KeyEvent(code: KeyCode(char: 'q'))) => (model, Quit()),
    TickMsg(:final elapsed) => (model.tick(elapsed), null),
    _ => (model, null),
  },
  view: (model, frame, theme) => frame.renderWidget(myWidget(model, theme), frame.area),
);
```

`copyWith`-style immutable models are still allowed and clean for small value-like models (see `kiko_core/example/counter.dart`); mutability is the default for anything app-sized.

**Key types:**

- `Msg` - events (KeyMsg, MouseMsg, TickMsg, FrameTickMsg, InitMsg, custom)
- `Cmd` - side effects (Quit, Tick, AsyncCmd, Batch, Emit)
- `MvuRuntime` - unified message queue, frame/tick timers, async task handling

Widget→app events and effects address their target by **stable `id`** (carried by value),
not by object reference — and async results must thread that id home. See
`specs/a2.1-id-addressing.md`.

### Event System

Unified stream architecture where all sources push to single FIFO queue:

- **FrameTick** (internal, 60fps default) - drives render loop
- **Tick** (user timer) - for app logic (clocks, polling)
- **Terminal events** - keys, mouse, focus, paste

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
- `Layout` - cassowary-based constraint solver for splitting areas (`Rect`)
- `Block` - base widget for borders/titles/padding
- `Span`/`Line`/`Text` - styled text primitives

### Layout System

Cassowary solver with constraints:

- `Constraint.length(n)` - exact size
- `Constraint.min(n)` / `Constraint.max(n)` - bounds
- `Constraint.percentage(n)` / `Constraint.ratio(a,b)` - proportional
- `Constraint.fill(n)` - expand to fill

Declarative layout widgets: `Row`, `Column`, `Grid`, `LayoutBuilder`, `Padding`
Constraint wrappers: `Fixed`, `MinSize`, `Percent`, `Expanded`

### Dependencies

Local termkit monorepo at `../termkit/packages/`:

- `termlib` - terminal control (raw mode, cursor, colors)
- `termparser` - input parsing (keys, mouse, events)
- `termunicode` - Unicode width calculation
- `termansi` - ANSI escape sequences

External: cassowary (layout solver)

## Code Style

- Uses `very_good_analysis` lints
- Strict casts/inference/raw-types enabled
- `public_member_api_docs` required

## Coding Rules

- Identify anti-patterns BEFORE writing code, not after
- If a request leads to a workaround, pause and discuss
- Explain what pattern is being violated
- Propose root-cause fixes, not band-aids
