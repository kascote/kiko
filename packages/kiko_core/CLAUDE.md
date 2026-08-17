# CLAUDE.md

Guidance for Claude Code in `kiko_core` — the core TUI library: terminal
rendering, the MVU runtime, the backend seam, input routing, and the theming
types. Commands, monorepo layout, and cross-package rules: root `/CLAUDE.md`.

## Hard rules

One line each; the linked page (paths from the repo root) explains the rule.

- 0-based buffer cells everywhere above the backend seam; translating the terminal's 1-based numbers is `TermlibBackend`'s private business (`docs/backend.md`).
- No termlib/termparser type crosses the backend seam or rides any `Msg`; map to kiko types once, at intake (`docs/backend.md`, `docs/mouse.md`).
- The framework never calls `exit()`; `run()` completes with the exit code on every path, and `Backend.dispose()` flushes (`docs/backend.md`).
- One `TextMeasurer` rules the session (`buffer.measurer`); never construct a bare measurer or do raw termunicode width math (`docs/architecture.md`).
- Bind on `KeyMsg.key`, insert `KeyMsg.text`, never derive one from the other; `KeyMsg.repeat` is informational only (`docs/keyboard.md`).
- `HitMap` is the only hit-testing type: `frame.hits` in `view`, `ctx.hits` in `update` (`docs/mouse.md`).
- Hit tags are the sealed `HitTag` vocabulary — stamp `IdTag`/`ScopeTag`, never a bare string, and never spell the `/` separator; use the `HitTag` helpers (`docs/mouse.md`).
- A scope's rect is its press claim: a scope node — an overlay scope above all — must hug its content (`docs/mouse.md`).
- Captor liveness asks `HitMap.isLive`, never `rectOf` — a scope has no single rect (`docs/mouse.md`).
- Deliver a hit path as-is to the longest registered prefix (`HitTag.resolve`); never retarget it (`docs/components.md`).
- Never scroll something into view by reading `ctx.hits.rectOf(id)` — a viewport clips hit presence, so a scrolled-off id answers null exactly when it matters (`docs/mouse.md`).
- Rendering never depends on `ResizeMsg`; `Terminal.draw` polls the backend size before every frame (`docs/backend.md`).
- `Theme`, `Tone`, `StyleResolver`, `WidgetState` and `KeyBinding` live here, but the styling doctrine lives in `docs/theming.md`; touch `style_resolver.dart`, `theme.dart` or `tone.dart` only with it open.

## Documentation map

Read the page covering what you touch (paths from the repo root):

| Page | Covers |
| --- | --- |
| `docs/architecture.md` | rendering flow, MVU runtime, event queue, text measurement |
| `docs/backend.md` | the backend seam, TestBackend, resize events |
| `docs/keyboard.md` | key events, bindings, widget keyboard handling |
| `docs/mouse.md` | pointer routing, hit map, hit regions, scopes, capture |
| `docs/components.md` | Component contract, ids, widget→app addressing |
| `docs/theming.md` | the theming model, the recipe, per-widget anatomy |
| `docs/widget-testing.md` | testing with TestBackend under `dart test` |

## Code Style

Same as root: `very_good_analysis`, strict mode, `public_member_api_docs` required.
