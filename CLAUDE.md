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

Dependencies beyond plume: the local termkit monorepo at `../termkit/packages/` (`termlib` terminal control, `termparser` input parsing, `termunicode` width calculation, `termansi` escape sequences).

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

## Architecture in brief

`Terminal` renders through two `Buffer`s and sends only the diff to the `Backend`. UI is composed from `View`s: `View.build()` inflates a fresh plume `Node` each frame, and `frame.render(view)` lays it out and paints it. Layout is `plume`'s job (constraints flow down, sizes flow up; see `packages/plume/README.md`). The runtime is MVU in the **Bubble Tea** style: models are mutable; `update(model, msg, ctx)` returns `(model, cmd)` and normally mutates the model in place. All event sources share one FIFO queue; rendering happens on `FrameTickMsg`.

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

Full story — rendering flow, MVU contract, event queue, text measurement: `docs/architecture.md`.

## Hard rules

One line each; the linked page explains the rule.

- Bind on `KeyMsg.key`, insert `KeyMsg.text` — never derive one from the other (`docs/keyboard.md`).
- The framework never calls `exit()`; `run()` completes with the exit code and the app calls `exit(await ...run(...))` (`docs/architecture.md`).
- Widget→app commands and async results address their target by stable `id`, carried by value — and async results must thread that id home (`docs/components.md`).

Package-specific rules live in `packages/kiko_core/CLAUDE.md` and `packages/kiko_widgets/CLAUDE.md`.

## Documentation map

Read the page covering what you touch:

| Page                       | Covers                                                                |
| -------------------------- | --------------------------------------------------------------------- |
| `docs/architecture.md`     | rendering flow, MVU runtime, event queue, text measurement            |
| `docs/backend.md`          | the backend seam, TestBackend, resize events                          |
| `docs/keyboard.md`         | key events, bindings, widget keyboard handling                        |
| `docs/mouse.md`            | pointer routing, hit map, hit regions, capture, widget mouse handling |
| `docs/components.md`       | Component contract, ids, widget→app addressing                        |
| `docs/focus-router.md`     | FocusRouter: traversal, dispatch, chrome aliases                      |
| `docs/async-loading.md`    | keyed load slots, paging, demand                                      |
| `docs/scroll-view.md`      | ScrollView: scrolling composed content                                |
| `docs/theming.md`          | the theming model, the recipe, per-widget anatomy                     |
| `docs/building-widgets.md` | widget-authoring tutorial, worked end to end                          |
| `docs/widget-testing.md`   | testing widgets and apps under `dart test`                            |
| `docs/glossary.md`         | canonical vocabulary for docs and discussion                          |

## Code Style

- Uses `very_good_analysis` lints
- Strict casts/inference/raw-types enabled
- `public_member_api_docs` required

## Coding Rules

- Identify anti-patterns BEFORE writing code, not after
- If a request leads to a workaround, pause and discuss
- Explain what pattern is being violated
- Propose root-cause fixes, not band-aids

## Writing Rules

One register for everything written in this repo — docs pages, CLAUDE.md files,
mikos items, code comments. Inspired by ASD-STE100 (Simplified Technical
English), without its restricted dictionary. The goal: text a reader can follow
without having been in the session that wrote it.

1. **Short sentences.** Aim for 25 words or fewer. If a sentence needs three
   dashes and two parentheticals, split it.
2. **One instruction per sentence.** A rule and its exception are two sentences.
3. **Active voice, present tense.** "The router delivers the region", not "the
   region is delivered".
4. **One term, one concept.** Every term of art appears in `docs/glossary.md`
   with one meaning. Do not use two words for one thing, or one word for two
   things.
5. **Define before use.** A term that is not ordinary English, a code
   identifier, or a glossary entry gets defined where it first appears — or
   does not appear.
6. **No invented metaphors.** "The app is the I/O ferry" becomes "the app
   performs all I/O". A metaphor that survives must earn a glossary entry.
7. **State the rule, then the reason.** Lead with what to do; follow with why,
   in its own sentence.
8. **Code identifiers are exempt.** `PointerMsg`, `applyLoad` are names, not
   jargon; use them freely and mark them as code.
9. **Paths over prose pointers.** Link a file (`docs/mouse.md`) instead of
   describing where something lives.
10. **No session shorthand.** Spec numbers, codenames, and phase labels ("P1")
    mean something only inside the plan that defines them. Elsewhere, say what
    the thing is or does.
11. **Density is not a virtue.** Commit hashes, file paths, and ids are welcome
    as parentheticals, but the sentence around them must survive their removal.
12. **Describe the system as it is.** No change history in a page: what a
    thing replaced, which rework introduced it, or which bug it fixed lives in
    commit messages and specs. Keep the reason a rule exists; drop the story
    of how it got there.

Documentation structure: one page per topic, and a topic appears in exactly one
page. CLAUDE.md files hold only hard-rules lists and a map of when to read each
page; a hard rule is one line — the rule, then the page that explains it in
parentheses. Rule lists lead with the rule in bold, then the explanation.

Code comments — all of them, `///` and `//` alike:

- **No spec or design-document citations in comments.** They rot when the
  document moves. `[CrossLink]`s to other Dart symbols are fine and encouraged.
- **State what it is and how to use it, not the argument for it.** Design
  rationale belongs in the spec or the commit message. One short "why" line is
  OK when a reader would otherwise be confused; never the whole argument.
- **Doc comments are layered.** First paragraph: what it is, one sentence.
  Second: how you use it. Third: a technical point, only if genuinely needed —
  then stop. A final short line may point at a related type to reach for.
- **Inline comments explain the non-obvious why.** Skip narration of what the
  code obviously does.

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

The Writing Rules above apply in full. On top of them, an item must be readable
cold, by a person with no memory of the session that wrote it:

- **Self-contained.** The body states the problem and the work in its own
  words. References to other items are "see also" pointers, never required
  reading.
- **Titles are complete phrases.** Under 80 chars, never truncated mid-thought.
  Write the title last, after the body is clear.
- **Say what done looks like.** A task ends with one plain sentence:
  "Done when …".

Do **not** imitate the register of older items — they predate this standard.
