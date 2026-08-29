# Kiko

**Note**: This project is a work in progress and will be updated as time permits.

Kiko is a Dart framework for building TUI (Text User Interface) applications: immediate-mode rendering over a double-buffered terminal, a Bubble Tea-style Model-View-Update runtime, and a Flutter-style layout engine (the `plume` package). It began as a port of the [Ratatui](https://ratatui.rs/) Rust framework and has since diverged into its own design.

## Packages

The repository is a Dart workspace with four packages:

| Package                 | What it is                                                                       |
| ----------------------- | -------------------------------------------------------------------------------- |
| `packages/plume`        | Flutter-style, solver-free layout engine for cell grids (geometry only)           |
| `packages/kiko_core`    | The TUI library: rendering, the MVU runtime, views and basic widgets              |
| `packages/kiko_widgets` | Interactive widgets: text input/area, list, table, tree, buttons, modals, scrolling |
| `packages/kiko_log`     | Logging                                                                           |

## Getting started

A Kiko app is three functions in the Bubble Tea style: a **model** (your state), an
**update** (message in, model + optional command out), and a **view** (model in, UI out).
This is `packages/kiko_core/example/counter.dart`, condensed:

```dart
import 'dart:io';

import 'package:kiko/kiko.dart';

class CounterModel {
  const CounterModel({this.count = 0});

  final int count;

  CounterModel copyWith({int? count}) => CounterModel(count: count ?? this.count);
}

Future<void> main() async {
  exit(
    await Application(title: 'Counter').run(
      init: const CounterModel(),
      update: (model, msg, _) => switch (msg) {
        KeyMsg(key: 'q') => (model, const Quit()),
        KeyMsg(key: 'up') => (model.copyWith(count: model.count + 1), null),
        KeyMsg(key: 'down') => (model.copyWith(count: model.count - 1), null),
        _ => (model, null),
      },
      view: (model, frame) => frame.render(
        Container(
          border: BorderType.plain,
          topTitles: [Line('Counter (↑/↓ to change, q to quit)')],
          child: Center(child: Line('Count: ${model.count}')),
        ),
      ),
    ),
  );
}
```

`run()` completes with the exit code — the framework never calls `exit()` itself, so
terminating the process is your call: `exit(await Application(...).run(...))`.

An immutable `copyWith` model is fine at this size. Kiko does not assume purity:
models are mutable by default (the widget models in `kiko_widgets` all are), and for
an app-sized model you mutate it in place and return the same reference.

## Layout

Layout comes from the `plume` package: a Flutter-style box model — constraints flow
down, sizes flow up, parents place children — with no constraint solver.

Rendering is **immediate mode**: `view` builds a fresh tree from the model every
frame, out of composable pieces (`Row`, `Column`, `Container`, `Center`, `Expanded`,
`SizedBox`, …). No widget tree is retained or reconciled between frames — state
lives in your model — and the double buffer diffs each painted frame so only
changed cells reach the terminal:

```dart
void draw(Frame frame) {
  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line('header'),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: Container(border: BorderType.plain, child: Line('main')),
            ),
            Expanded(
              child: Container(border: BorderType.plain, child: Line('side')),
            ),
          ],
        ),
      ),
    ],
  );

  frame.render(ui);
}
```

`packages/plume/README.md` explains the model; `packages/kiko_core/example/layout.dart`
tours the flex knobs (`MainAxisAlignment`, `CrossAxisAlignment`, `flex` ratios).

## Widgets

`kiko_core` ships the primitives — `Line`, `Text`, `Container`, and the layout views
above. `kiko_widgets` adds the interactive catalog: `TextInput`,
`TextArea`, `Button`/`ButtonGroup`, `ListView`, `TableView`, `TreeView`, `Modal`,
`ScrollView`, plus `FocusRouter` (keyboard/mouse routing across widgets) and
`DataView` (async data loading). Each widget follows MVU: a mutable model holding
state and an `update`, and a stateless view that renders it.

Every widget has a runnable example under `packages/kiko_widgets/example/`; the
`kiko_core` examples cover the runtime itself (mouse, resize, overlays, timers,
colors, unicode). Run any of them with `dart run example/<name>.dart` from the
package directory.

## Events

All input reaches `update` as messages on a single FIFO queue: `KeyMsg`,
`PointerMsg` (already resolved to the widget it hit), `ResizeMsg`, `TickMsg`
(a one-shot timer's message), frame reports, and your own custom messages. A
frame follows every processed message; nothing runs while the queue is idle.
Side effects are returned as commands: `Cmd` is sealed to `Quit`, `Emit`,
`Tick`, `Task`, `Batch`. What a widget hands the app instead — a press, a row
activation — is a `WidgetEvent`, carried in the `Handled` verdict its
`update` returns.

## Documentation

- `packages/plume/README.md` — the layout engine: mental model, node catalog, API
- `docs/building-widgets.md` — writing your own widget: model + view, mouse handling, scrolling, worked end to end
- `docs/theming.md` — the theming model and the styling recipe (states pick tones, parts pick projections)
- `docs/widget-testing.md` — testing widgets and whole apps under `dart test`, no terminal attached
- `docs/architecture.md` — rendering flow, the MVU runtime, the event queue
- `docs/backend.md` — the backend seam, TestBackend, resize events
- `docs/keyboard.md` / `docs/mouse.md` — the input contracts, from terminal event to widget
- `docs/components.md` — the widget contract: identity, update verdicts, addressing
- `docs/focus-router.md` — focus traversal and pointer dispatch in one call
- `docs/async-loading.md` — how the data widgets load (load slots, paging)
- `docs/scroll-view.md` — scrolling composed content
- `docs/glossary.md` — the project vocabulary

## Development

The termkit packages (`termlib`, `termparser`, `termunicode`, `termansi`) are consumed
via path overrides in `pubspec_overrides.yaml`, expected as a sibling checkout at
`../termkit`.

Setup git hooks (runs lint + tests on commit):

```bash
git config core.hooksPath .githooks
```
