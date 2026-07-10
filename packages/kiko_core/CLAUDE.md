# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiko is a Dart port of [Ratatui](https://ratatui.rs/) - a Rust TUI framework. Builds terminal user interfaces using a double-buffered rendering approach.

## Commands

```bash
make test          # run all tests
make testf FILE=test/foo_test.dart  # single test
make lint          # static analysis
make format        # format code
make cover         # coverage report
```

## Architecture

**Core rendering flow:**

1. `Terminal` manages double-buffered rendering via two `Buffer` instances
2. `Terminal.draw()` accepts callback receiving `Frame`
3. Widgets implement `Widget.render(Rect area, Buffer buffer)`
4. `Buffer.diff()` computes minimal changes between frames
5. `Backend` (abstract) handles actual terminal I/O

**Key components:**

- `Buffer` - grid of `Cell`s (grapheme + fg/bg/modifiers)
- `Block` - base widget for borders/titles/padding
- `Line`/`Text` - styled text primitives (Views)

**Layout** is handled by the `plume` package — a Flutter-style box model (constraints
down, sizes up), no constraint solver. See `packages/plume/README.md`.

**Dependencies:** plume (layout), termlib (terminal control), termparser (input), termunicode (width)

## The Backend Seam

`Backend` (`src/backend/backend.dart`) is the whole surface `Terminal` and `Application`
use to reach a terminal. Two implementations: `TermlibBackend` (real, needs a TTY, not
exported) and `TestBackend` (in-memory, `package:kiko/testing.dart`).

- **One coordinate space above the seam.** A backend delivers events in **0-based buffer
  cells** and accepts draw/cursor calls in 0-based buffer cells. Terminals number from 1;
  that is `TermlibBackend`'s private business, and it translates on the way in and out.
  Never re-introduce a 1-based coordinate above the backend.
- **No foreign types cross it.** `Backend.profile` is kiko's own `ColorProfile`, mapped
  from termlib's `ProfileEnum` at the edge. `TestBackend` imports no termlib.
- **Testing.** `Terminal.create({Backend? backend})` and
  `Application({@visibleForTesting Backend? backend})` both take an injected backend, so the
  render loop and the full MVU drain run under `dart test`. `TestBackend` keeps a `screen`
  buffer that every `draw` applies onto (assert what was *rendered*), a `lastDiff` (assert
  the double buffer redrew only what changed), `emit(event)` to drive the loop, and a
  recorded `exitCode` — `flushThenExit` never exits the test process. It is **not a terminal
  emulator**: it parses no escape sequences, and every call but `draw` is recorded, not
  simulated. See `test/terminal_test.dart` and `test/application_test.dart`.

## MVU Identity & Addressing

- `Component` (`src/mvu/focus.dart`) is the widget-model contract: `Cmd? update(Msg)` **plus
  `String get id`**. The `id` is the model's stable identity; widget→app commands carry it
  as their address. A focus-only model still has an `id` — addressing is just one _use_ of identity.
- `autoId(String prefix)` (`src/mvu/auto_id.dart`) mints human-readable ids (`'tableview-1'`)
  from a single shared monotonic counter, used when a model is constructed without an
  explicit id. It is a **sequential per-isolate counter**: auto ids are **not stable across
  runs and not unique across isolates** — fine, because ids never cross isolates by design.
  Pass an explicit id when matching must survive a restart. `resetAutoIdCounter()` is
  `@visibleForTesting`.

## Code Style

- Uses `very_good_analysis` lints
- Strict casts/inference/raw-types enabled
- `public_member_api_docs` required
