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
`TableActionCmd`, `TableLoadMoreCmd`, `ListActionCmd`, `ListLoadMoreCmd`, `TreeExpandCmd`,
`TreeCollapseCmd`, `TreeActionCmd`, `ButtonPressCmd`. They travel **up** the call stack to
the app's `update`. Every one addresses its owner by a **stable `String id`** carried by value

Non-obvious rules a contributor will otherwise miss:

- **Address by `id`, not by reference or by command type.** The app resolves a command to
  its owner by matching the id (`id == model.table.id`), or via a `Map<String, …>` registry
  for N instances. Never disambiguate by `identical(...)`, and never assume one instance per
  command type.
- **Async effect results must carry the id home.** When the app fires a `Task` in response
  to a `…LoadMoreCmd(id)`, thread that `id` into the _result_ message
  (`onSuccess: (rows) => DataLoadedMsg(id, rows)`) and guard the receipt with
  `msg.id == model.x.id`. This is the **most-forgettable rule** — omit it and the app is
  silently single-instance-only.
- **Derive collection ids from stable domain keys (`user.id`), never the list index.**
  Indexes shift on insert/delete, so an index-derived id routes a result onto the wrong row.
- **Widgets never perform async I/O.** The app drives _every_ fetch via `Task` and routes
  the result home by id; a widget signals "I need data" by _returning a command_
  (e.g. `TreeExpandCmd` is a load _request_). It is tempting to
  `await dataSource.getChildren(...)` inside the widget — don't: that loses the runtime
  cancellation token and races the message loop.
- **An id that resolves to no owner is logged + dropped, never silently ignored** — the
  observable failure that reference-addressing could not give you.

## Current Widgets

- `TextInput` / `TextInputModel` - single-line text input with readline keybindings

## Code Style

Same as root: `very_good_analysis`, strict mode, `public_member_api_docs` required.
