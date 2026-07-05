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
- `Layout` - cassowary-based constraint solver for splitting areas (`Rect`)
- `Block` - base widget for borders/titles/padding
- `Line`/`Text` - styled text primitives (Views)

**Layout system uses cassowary solver with constraints:**

- `Constraint.length(n)` - exact size
- `Constraint.min(n)` / `Constraint.max(n)` - bounds
- `Constraint.percentage(n)` / `Constraint.ratio(a,b)` - proportional
- `Constraint.fill(n)` - expand to fill

**Dependencies:** termlib (terminal control), termparser (input), termunicode (width), cassowary (layout)

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
