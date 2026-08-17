# CLAUDE.md

Guidance for Claude Code in `kiko_widgets` — higher-level widgets over
`kiko_core`. Commands, monorepo layout, and cross-package rules: root
`/CLAUDE.md`.

## Shipped widgets

- `TextInput` / `TextInputModel` — single-line text input, readline keybindings
- `TextArea` / `TextAreaModel` — multi-line editor (wrap-aware caret, selection)
- `ListView`, `TableView`, `TreeView` — windowed data widgets (lazy; see `docs/async-loading.md`)
- `Button` / `ButtonModel` — emits `ButtonPressCmd`
- `ScrollView` / `ScrollViewModel` — scrolls composed content (`docs/scroll-view.md`)
- `ModalModel` + `modalDialog(...)` — `modalDialog` frames any content as a bordered, tagged dialog; `ModalModel` exists only for the static confirm/cancel shape. The app owns whether a modal is open.
- `FocusRouter`, `FocusSlot`, `focusOnPress`, `routeToTarget`, `offerOutward` — focus and pointer-dispatch glue (`docs/focus-router.md`)

## Hard rules

One line each; the linked page (paths from the repo root) explains the rule.

- Widget models are mutable `Component`s: `update(msg)` returns `Handled` (with optional `Cmd`) or `Declined` — consume only what you understand, decline everything else, and keep every model in `test/widgets/decline_unknown_test.dart` (`docs/components.md`).
- Widgets self-tag (`..tag = IdTag(model.id)` in `build`); never wrap a self-tagging widget in `Tagged` (`docs/mouse.md`).
- The pointer cases sit above the focus gate; the keyboard sits behind it (`docs/mouse.md`, `docs/keyboard.md`).
- A click emits the same id-addressed command Enter does; a widget never emits a focus command (`docs/mouse.md`).
- A widget places its caret only from a press that carries a rect (`docs/mouse.md`).
- Editors insert `msg.text`, never `msg.key`; decline `KeyReleaseMsg` and `ModifierKeyMsg` (`docs/keyboard.md`).
- Address by stable `id` carried by value; thread both `id` and `key` into every async result (`docs/components.md`).
- Widgets never perform async I/O; every `LoadRequest` resolves its slot — with data, an error, or `declineLoad` (`docs/async-loading.md`).
- A windowed widget needs the frame-tick demand case: `FrameTickMsg() => (model, model.table.demandIfDirty())` (`docs/async-loading.md`).
- Wheel: decline a notch that would move nothing in its direction; consume any notch that moves at all (`docs/mouse.md`, `docs/scroll-view.md`).
- Never paint a `Tone` directly — project it with `.ink`/`.fill`/`.wash`; route every style through `StyleResolver`; never handle NO_COLOR or ANSI-16 yourself (`docs/theming.md`).
- The keyboard-current item is `WidgetState.cursor` — never borrow `focused` or `hover` for it (`docs/theming.md`).

## Documentation map

Read the page covering what you touch (paths from the repo root):

| Page                       | Covers                                                       |
| -------------------------- | ------------------------------------------------------------ |
| `docs/components.md`       | Component contract, ids, widget→app addressing               |
| `docs/keyboard.md`         | key events, bindings, widget keyboard handling               |
| `docs/mouse.md`            | pointer routing, hit regions, scopes, capture, widget mouse handling |
| `docs/focus-router.md`     | FocusRouter: traversal, dispatch, chrome scopes              |
| `docs/async-loading.md`    | keyed load slots, paging, demand                             |
| `docs/scroll-view.md`      | ScrollView: scrolling composed content                       |
| `docs/theming.md`          | the theming model, the recipe, per-widget anatomy            |
| `docs/building-widgets.md` | widget-authoring tutorial, worked end to end                 |
| `docs/widget-testing.md`   | testing widgets and apps under `dart test`                   |

## Code Style

Same as root: `very_good_analysis`, strict mode, `public_member_api_docs` required.
