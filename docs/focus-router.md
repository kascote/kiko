# FocusRouter

`FocusRouter` (`packages/kiko_widgets/lib/src/widgets/focus_router.dart`)
packages the app-side interaction glue behind one `route()` call, made as one
`case` of the app's `update`: focus traversal, click-to-focus, pointer
dispatch, chrome aliases, and the outward offer for declined pointers. It owns
none of the widgets it routes to. The `FocusGroup`, `extras`, and `aliases`
are held by reference and re-read on every call, so there is no registration
step.

Simplest wiring: `packages/kiko_widgets/example/text_input.dart`. Everything
at once: `packages/kiko_widgets/example/scrollable_form.dart`. The hand-rolled
primitive underneath: `packages/kiko_core/example/mouse_dispatch.dart`.

## The routing contract

**Route by address, never by message class.** `route()` has three cases, and
only three:

1. A `KeyMsg` resolves against the traversal `bindings` first; an unbound key
   goes to the focused member. The traversal keys are reserved, which is what
   keeps a consume-everything widget escapable.
2. Pointer traffic (`Routed`) goes to its addressed target — members and
   `extras` by id, chrome via `aliases`. A background press or an unknown id
   declines. Positional traffic is never re-aimed at the focused member.
3. Everything else goes to the focused member, and its verdict returns as-is:
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

1. Domain messages first: widget→app commands and async results the app must
   intercept.
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
- `extras:` — components reachable by pointer but never by focus (a
  wheel-only scroll surface, a status strip).
- `aliases:` — chrome stands in for the member it decorates (next section).
- `onFocusChange` — the single funnel for every focus move, keyboard or click
  alike. Scroll-the-focused-field-into-view lives here, and nowhere else.
- `clickToFocus: false` — presses deliver without moving focus.
- Copy the assembly. The pieces are public — `focusOnPress`, `routeToTarget`,
  `offerOutward` — and the focused path is the one line
  `focus.focused.update(msg)`. `focus_router.dart` is deliberately one
  readable file; it is the reference assembly.

## Chrome aliases

**Chrome aliases re-address, never forward raw.** An alias entry maps a
chrome id (a border, a title row — tagged by the app, never a member itself)
to the member it decorates. A press on chrome click-focuses the member. The
pointer is then rebuilt against the member: `targetId`, `local`, and
`targetRect` all describe the member, and the region is re-resolved against
the member's own marked parts. A border cell above the content yields a
negative `local.y`; that is correct, because `local` anchors to the member's
top-left. A leave or cancel via alias delivers verbatim — it carries no
position to rebuild from.

`FocusSlot` is a focusable placeholder that declines everything. It gives a
widget-less pane a place in the focus order.
