# ScrollView: scrolling composed content

The reference for `ScrollView`/`ScrollViewModel`
(`packages/kiko_widgets/lib/src/widgets/scroll_view/`). Worked end to end in
`packages/kiko_widgets/example/scrollable_form.dart`.

ScrollView scrolls composed content — a form, a settings panel, a sidebar —
built from ordinary Views. It wraps a plume `Viewport` node; `kiko_core`'s
`Viewport` View is the bridge. Plume owns the geometry. `ScrollViewModel` owns
the scroll policy: offset, wheel, keys, `ensureVisible`.

## Composed UI, not data

ScrollView lays out its entire child every frame and clips the paint. The cost
grows with the content, not the viewport. That is right for a form or a panel
and wrong at data scale: a 100k-row list belongs on a windowed widget (List,
Table, Tree), never inside a ScrollView. For the same reason `ScrollViewModel`
is not `Loadable` — it scrolls composed UI that is already in memory.

## The content-area tag, and chrome

ScrollView tags only its own content area. It ships no border, scrollbar, or
help text; the app composes those around it. The tag covers the whole content
area, gaps included, so a wheel between composed children already resolves to
the ScrollView.

Chrome drawn around one composed widget sits outside that widget's own tag,
so it belongs to the widget through a scope: wrap the chrome in
`Tagged.scope(widgetId, chrome)`, and a press anywhere on it resolves to the
widget by prefix (`docs/mouse.md`).

The frame around the whole ScrollView is different — it wraps the scrolled
content, not one member, so a scope there would prefix, and swallow, every
composed child's own path underneath it. That frame keeps a plain id instead
(`Tagged(frameId, ...)`), and the app forwards the id's pointer traffic to
the `ScrollViewModel` by hand, in its own `Declined` branch. A wheel on the
border then scrolls the view exactly like one over the content. The bordered
frame in `packages/kiko_widgets/example/scrollable_form.dart` is this recipe;
read its header comment for the full story.

## The wheel rule

ScrollView follows the wheel rule every scrollable shares: decline a notch
that would move nothing in its direction; consume any notch that moves at
all. Declining at an edge lets the app offer the notch to the next scrollable
ancestor out, which is what makes nesting work (`docs/mouse.md`).

## `offerOutward`

`offerOutward(msg, ctx, targets)`
(`packages/kiko_widgets/lib/src/widgets/offer_outward.dart`) is the ready-made
offer. It walks `ctx.hits.hitPath` from the declining widget outward and
resolves each enclosing entry to a component in `targets` — directly, or via
its longest registered prefix (`docs/components.md`). No component is asked
twice: the decliner is skipped, and two entries resolving to one component
get one offer. The first `Handled` wins; when nobody answers, it declines.
`FocusRouter` already runs this walk when a routed pointer comes back
declined, so an app on the router never calls it directly.

Two limits. It resolves by position, so never call it for a `PointerLeaveMsg`
or `PointerCancelMsg` — neither carries a position to walk from. And an
enclosing area the app handles directly, with no `Component` behind it, is not
reachable through `targets`; walk `ctx.hits` inline for that case.

## `ensureVisible(id)`

`ensureVisible(id)` scrolls the minimum amount that brings a tagged descendant
fully into view. `id` shares the hit map's own path namespace
(`docs/mouse.md`). A bare member id names a scope wrapping chrome around the
member, and brings the whole frame into view. `id/id` names the bare content
leaf inside it, and brings only that leaf into view. A scope path that
repeats across several nodes ranges over every occurrence's union: min top to
max bottom.

Never read the descendant's rect from `ctx.hits.rectOf(id)`. A Viewport
removes a scrolled-off descendant from the hit map entirely, so `rectOf`
answers `null` in exactly the case that matters (`docs/mouse.md`, "Viewports
and the hit map"). The model keeps its own map of ranges keyed by hit path,
refreshed each paint; `ensureVisible` reads only that map.

## Keyboard

`ScrollViewAction` names the actions: `lineUp`, `lineDown`, `pageUp`,
`pageDown`, `top`, `bottom`. `defaultScrollViewBindings` maps the default
keys. The `keyBinding` constructor parameter takes a replacement and defaults
to a copy; rebind or extend with `map`, `remove`, `unbind`, and `addAll`
(`docs/keyboard.md`).

Keys sit behind the focus gate: a ScrollView reads them only while focused.
The wheel does not — it scrolls whether or not the view owns focus, like
every other scrollable (`docs/mouse.md`).

## `getScrollState()`

`getScrollState()` returns a `ScrollViewScrollState`: `offset`,
`viewportRows`, `contentRows`, plus `progress` and `thumbSize` getters. Every
scrollable widget exposes a `getScrollState()`. Kiko ships no scrollbar
widget; an app-drawn scrollbar reads this state.
