# CLAUDE.md

Guidance for Claude Code in `kiko_widgets` — higher-level widgets over
`kiko_core`. Commands, monorepo layout, and cross-package rules: root
`/CLAUDE.md`.

## Shipped widgets

- `TextInput` / `TextInputModel` — single-line text input, readline keybindings
- `TextArea` / `TextAreaModel` — multi-line editor (wrap-aware caret, selection)
- `ListView`, `TableView`, `TreeView` — windowed data widgets (lazy; see `docs/async-loading.md`)
- `Button` / `ButtonModel` — emits `ButtonPressEvent`
- `Checkbox` / `CheckboxModel` — emits `CheckboxChangeEvent`; glyph presets on `CheckGlyphs`
- `ScrollView` / `ScrollViewModel` — scrolls composed content (`docs/scroll-view.md`)
- `Combobox` / `ComboboxModel` — text field with a filterable popup list, in-memory or remote (`docs/combobox.md`)
- `ModalModel` + `modalDialog(...)` — `modalDialog` frames any content as a bordered, tagged dialog; `ModalModel` exists only for the static confirm/cancel shape. The app owns whether a modal is open; the modal itself owns the outside press and unknown keys while it stays open.
- `FocusRouter`, `FocusSlot`, `focusOnPress`, `routeToTarget`, `offerOutward` — focus and pointer-dispatch glue (`docs/focus-router.md`)

## Hard rules

One line each; the linked page (paths from the repo root) explains the rule.

- Widget models are mutable `Component`s: `update(msg)` returns `Handled` (events and an optional `Cmd`) or `Declined` — consume only what you understand, decline everything else, and keep every model in `test/widgets/decline_unknown_test.dart` (`docs/components.md`).
- Widgets self-tag (`..tag = IdTag(model.id)` in `build`); never wrap a self-tagging widget in `Tagged` (`docs/mouse.md`).
- The pointer cases sit above the focus gate; the keyboard sits behind it (`docs/mouse.md`, `docs/keyboard.md`).
- A click emits the same id-addressed event Enter does; a widget never moves focus itself (`docs/mouse.md`).
- A release activates only after the widget's own press; keep every press-activated widget in `test/widgets/press_before_release_test.dart` (`docs/mouse.md`).
- A widget places its caret only from a press that carries a rect (`docs/mouse.md`).
- Editors insert `msg.text`, never `msg.key`; decline `KeyReleaseMsg` and `ModifierKeyMsg` (`docs/keyboard.md`).
- Address by stable `id` carried by value; thread both `id` and `key` into every async result (`docs/components.md`).
- A model owns a message whose id's leaf is its own id and declines every other; a composite forwards to the part named by the segment after its own id, before its own guard (`docs/components.md`).
- A composite scopes its part's outgoing ticks; a part arms with its bare id (`docs/components.md`).
- A `LoadResult` is handled in the model's `update`, never in the app: the router delivers it by id (`docs/async-loading.md`).
- Widgets never perform async I/O; every `LoadRequest` resolves its slot — with data, an error, or `declineLoad` (`docs/async-loading.md`).
- Paint reports a layout fact through `surface.report(...)`; it never writes into a model (`docs/architecture.md`, `docs/async-loading.md`).
- Compare a measured fact with the one the model holds before reporting it; a fact the model holds is not reported, or the frame the report causes never settles (`docs/architecture.md`).
- Wheel: decline a notch that would move nothing in its direction; consume any notch that moves at all (`docs/mouse.md`, `docs/scroll-view.md`).
- Never paint a `Tone` directly — project it with `.ink`/`.fill`/`.wash`; route every style through `StyleResolver`; never handle NO_COLOR or ANSI-16 yourself (`docs/theming.md`).
- The keyboard-current item is `WidgetState.cursor` — never borrow `focused` or `hover` for it (`docs/theming.md`).
- A model never holds a resolved `Style`: anatomy is a view parameter, and a column's style is a function of the resolver (`docs/theming.md`).
- Content patches over the widget's base: hand a slot or state style to `paintLine` as `base` or through `Line.over`; never `patchStyle` it onto content (`docs/theming.md`).
- `disabled` and `error` are model facts on every value widget; where a state lands is the view's contract, listed per widget (`docs/theming.md`).

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
| `docs/combobox.md`         | Combobox: field, popup, placement, remote options             |
| `docs/theming.md`          | the theming model, the recipe, per-widget anatomy            |
| `docs/building-widgets.md` | widget-authoring tutorial, worked end to end                 |
| `docs/widget-testing.md`   | testing widgets and apps under `dart test`                   |

## Code Style

Same as root: `very_good_analysis`, strict mode, `public_member_api_docs` required.

<!-- dmetrics:start -->
## Code metrics — dmetrics

This project measures code with **dmetrics** (cyclomatic and cognitive
complexity per function, import coupling per library) against thresholds in
`analysis_options.yaml`. Run it once per task, after your edits, not after
every edit:

    dmetrics analyze [<file>|<dir> ...]

Pass the package's source roots: `lib`, plus `bin` when it has one. With no
targets it measures the current directory, tests and fixtures included, which
is usually more than you want.

Exit 0 is clean, 1 means violations, 2 means the analysis did not complete
(fix that first). Before interpreting a report, run `dmetrics agent`: it
explains the report line, what each metric measures and what to do about a
warning.
Warnings are evidence to weigh, not orders to obey. Never lower a threshold
or add an override to make a run pass; propose the change instead.
When the tool gets in your way, say so instead of working around it: a
report that misleads, a construct a metric misreads, a flag or an output you
needed and did not find. Report it as a gap in dmetrics, with the case that
showed it, so the tool improves rather than the workaround spreading.
<!-- dmetrics:end -->
