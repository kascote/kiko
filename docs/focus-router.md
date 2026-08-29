# FocusRouter

`FocusRouter` (`packages/kiko_widgets/lib/src/widgets/focus_router.dart`)
packages the app-side interaction glue behind one `route()` call, made as one
`case` of the app's `update`: focus traversal, click-to-focus, pointer
dispatch, delivery of addressed messages, and the outward offer for declined
pointers. It owns none of the widgets it routes to. The `FocusGroup` and
`extras` are held by reference and re-read on every call, so there is no
registration step.

Simplest wiring: `packages/kiko_widgets/example/text_input.dart`. Everything
at once: `packages/kiko_widgets/example/scrollable_form.dart`. The hand-rolled
primitive underneath: `packages/kiko_core/example/mouse_dispatch.dart`.

## The routing contract

**Route by address, never by message class.** `route()` has four cases, and
only four:

1. A `KeyMsg` resolves against the traversal `bindings` first; an unbound key
   goes to the focused member. The traversal keys are reserved, which is what
   keeps a consume-everything widget escapable.
2. Pointer traffic (`Routed`) goes to its addressed target — members and
   `extras` by id, or by the longest registered prefix of a hit path
   (`docs/components.md`). Chrome scoped to a member shares the member's id:
   a press on the chrome resolves to that id directly, and a press on the
   member inside resolves to it by the same prefix climb. A composite's part
   delivers to its owner as-is, and a press on it click-focuses the owner. A
   background press or an unresolved target declines. Positional traffic is
   never re-aimed at the focused member.
3. An addressed message (`Addressed`, `docs/components.md`) names its owner
   by `id`, and the id resolves the same way — members and `extras`, exact
   or by the longest registered prefix. It is delivered to the owner without
   moving focus. A `LoadResult` is the example: the widget that asked for a
   page receives the page. A `TickMsg` and a `FrameReport` travel the same
   way, to the widget that armed the tick or painted the report. An id
   nothing registers declines; an async result is never re-aimed at the
   focused member either.
4. Everything else goes to the focused member, and its verdict returns as-is:
   paste, a future input class, a message the router has never heard of. The
   router never decides for a widget which messages it can handle. That is
   the widget's verdict, and `Declined` means nothing consumed the message,
   so it is still the app's.

The contract rests on one discipline: a widget consumes only what it
understands and declines everything else. A catch-all `Handled` tail makes a
widget consume messages that were never its business, and the app never sees
them. `packages/kiko_widgets/test/widgets/decline_unknown_test.dart` pins
this for every model — keep new widgets in that suite.

## Calling convention

The order of cases in the app's `update`:

1. Domain messages first: the app's own message classes, and a command the
   app must act on before anything else. Async results are not in this
   group: the router delivers them.
2. App-level pre-route intercepts — a message the app wants before a widget
   sees it. These are rare; prefer switching on the `Handled(cmd)` the router
   returns.
3. The one delegate line: `switch (model.router.route(msg, ctx))`.
4. Fallback keys, on `Declined` only. They run for input every widget
   declined, so a quit key can never fire while someone is typing into a
   focused editor.

## Extending the router

The router has no feature flags; every extension is composition. In
escalation order:

- `bindings:` — extend or replace the traversal keys. `defaultFocusBindings()`
  is Tab/Shift+Tab; add jumps with `..map(['alt+1'], const FocusTo('sidebar'))`.
- `extras:` — components reachable by pointer or by an addressed message but
  never by focus (a wheel-only scroll surface, a status strip, a widget that
  only ever receives async results).
- `onFocusChange` — the single funnel for every focus move, keyboard or click
  alike. Scroll-the-focused-field-into-view lives here, and nowhere else.
- `clickToFocus: false` — presses deliver without moving focus.
- Copy the assembly. The pieces are public — `focusOnPress`, `routeToTarget`,
  `offerOutward` — and the focused path is the one line
  `focus.focused.update(msg)`. `focus_router.dart` is deliberately one
  readable file; it is the reference assembly.

## Chrome and scopes

Chrome belongs to the member it decorates through a scope, not through a
router setting. Wrap the chrome in `Tagged.scope(memberId, chrome)`; the
member inside self-tags the same id, so its path is `memberId/memberId`. A
press anywhere on the chrome resolves to a path under `memberId`, and prefix
resolution (`docs/mouse.md`) delivers it to the member — click-to-focus
included — the same as a press on the member's own cells.

Chrome around a container of members is the one shape a scope cannot
express: a scope there would prefix, and swallow, every member's own path
underneath it. That chrome keeps a plain id instead, and the app forwards
the id's pointer traffic to the container's model by hand, in the
`Declined` branch of its own `update`. `routeToTarget`'s note that several
ids may map to one component covers this case.
`packages/kiko_widgets/example/scrollable_form.dart` is the worked example;
read its header comment for the full story.

`FocusSlot` is a focusable placeholder that declines everything. It gives a
widget-less pane a place in the focus order.
