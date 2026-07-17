# Building Widgets with Kiko

How to write a stateful widget the way the shipped ones are written. We build a
small option picker — `PaletteModel` / `Palette` — end to end: keyboard first,
then the mouse, then wheel scrolling. The finished program is
`packages/kiko_widgets/example/custom_widget.dart`; it compiles under the
package's analyzer and runs on a real terminal, and every snippet below is a
slice of it. Keep the doc and the example in sync.

Prerequisites: the layout model (`packages/plume/README.md`) and the MVU shape
(root `README.md`). Styling has its own recipe (`docs/theming-widgets.md`);
this doc only uses it.

## A widget is two halves

A kiko widget is a **model** and a **view**:

- The **model** is mutable state plus an `update(Msg)` that consumes messages.
  It implements `Component`: a stable `String id`, an
  `UpdateResult update(Msg)`, and a `focused` setter (via `Focusable`). Models
  mutate in place — Bubble Tea style, not Elm — so `update` returns no new
  model, only a verdict: `Handled` (consumed, optionally carrying a `Cmd`
  effect) or `Declined` (not mine).
- The **view** is a stateless class implementing `View` that reads the model
  and builds UI. It is constructed fresh in the app's `view` function every
  frame, and its `build()` inflates a fresh plume `Node` every frame — nothing
  is retained or reconciled between frames.

The verdict is the contract everything else rests on: a parent routes a message
to a child and switches on the result. `Handled` ends the message; `Declined`
leaves it in flight for the next candidate — another widget, or the app's own
fallback keys.

## Views: what the render half is made of

Everything that renders implements one interface:

```dart
abstract interface class View {
  Node build();
}
```

`Line` and `Text` are views. `Container`, `Row`, `Column`, `Center`, `Padding`
are views that compose other views. A widget's view class is just one more of
these: it lays its content out by *composing* existing views and lets plume do
the geometry. Only data-scale widgets (a list windowing 100k rows) drop down to
a custom `Node` with their own `performLayout`/`paintSelf` — see ListView's
source when you need that; the palette here never does.

## The command

A widget talks to the app by returning commands from `update`, and a command
addresses its owner by **id, carried by value** — never by object reference.
The app matches the id to route the event home, which is what lets it hold
three palettes without ambiguity.

```dart
/// Emitted when an option is chosen — by Enter or by a click alike. It
/// addresses its owner by [id], so an app holding several palettes can route
/// it home.
class PaletteChooseCmd extends Cmd {
  /// Creates the command carrying the owner's [id] and the chosen [value].
  const PaletteChooseCmd(this.id, this.value);

  /// The id of the palette that emitted this.
  final String id;

  /// The option that was chosen.
  final String value;
}
```

## The model: state and the keyboard

The state is ordinary mutable fields. The only ceremony is the `Component`
surface: the `id`, the `focused` setter, and `update`.

```dart
class PaletteModel with ScrollableModel implements Component {
  /// Creates a palette over [options], showing [viewportRows] rows at a time.
  PaletteModel({required this.id, required this.options, this.viewportRows = 5});

  @override
  final String id;

  /// The options to pick from.
  final List<String> options;

  /// How many rows the viewport shows. Fixed here to keep the example small;
  /// a production widget measures its viewport while it paints and pushes the
  /// count into the model (see ListView's source).
  final int viewportRows;

  /// The keyboard-current option.
  int cursor = 0;

  /// The row under the mouse, or null when the pointer is elsewhere.
  int? hoverRow;

  bool _focused = false;

  /// Whether the palette owns keyboard input.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;
```

(`with ScrollableModel` is for the scrolling section below; ignore it for now.)

The keyboard lives at the bottom of `update`, behind the focus gate — a widget
only reads keys while it owns the keyboard:

```dart
    // Keyboard only below this line.
    if (!focused) return const Declined();

    switch (msg) {
      case KeyMsg(key: 'up'):
        if (cursor > 0) cursor--;
        _snapToCursor();
        return const Handled();
      case KeyMsg(key: 'down'):
        if (cursor < options.length - 1) cursor++;
        _snapToCursor();
        return const Handled();
      case KeyMsg(key: 'enter'):
        return Handled(PaletteChooseCmd(id, options[cursor]));
    }

    // Everything else was never ours — decline it, never swallow it.
    return const Declined();
```

Two rules are load-bearing here:

- **The gate declines; it does not swallow.** An unfocused widget answers
  `Declined`, so the message is still the app's.
- **The tail declines too.** A key the widget doesn't bind, a paste, a message
  class it has never heard of — all `Declined`. A catch-all `Handled` tail
  turns the widget into a black hole (more under "Decline everything you don't
  understand").

The example matches raw key names to stay small. Shipped widgets route keys
through a `KeyBinding<Action>` table instead (`ButtonAction`,
`defaultButtonBindings`, …) so apps can rebind them — see
`example/custom_keybindings.dart` for that pattern.

## The view: rows, states, and the tag

The view is stateless and rebuilt every frame. It composes existing views — a
`Container` pinning the viewport height, a stretched `Column` of rows — and
stamps the built subtree with the model's id:

```dart
final class Palette implements View {
  /// Creates a palette view over [model], styled by [theme].
  const Palette({required this.model, required this.theme});

  /// The model whose options, cursor, and hover this view renders.
  final PaletteModel model;

  /// The theme that resolves row styles.
  final Theme theme;

  @override
  Node build() {
    final resolver = StyleResolver(theme);
    final m = model;
    final end = (m.scrollOffset + m.visibleCount).clamp(0, m.options.length);

    return Container(
      height: m.viewportRows,
      child: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [for (var i = m.scrollOffset; i < end; i++) _row(m, resolver, i)],
      ),
    ).build()..tag = m.id;
  }
```

That `..tag = m.id` line is the whole mouse wiring on the view side. **Widgets
self-tag**: the tag names this subtree in the frame's hit map, so a pointer
event resolves to the model's id and arrives at `update` already addressed.
Where you put the tag decides what a pointer's `local` position means — it is
counted from the tagged node's top-left cell. We tag the row area itself, so
`local.y` is a row offset even when the app later wraps the palette in a
border. (`Tagged(id, child)` exists for regions the *app* composes that no
model owns — never wrap a self-tagging widget in one.)

Rows layer their paint the way every shipped widget does:

```dart
  View _row(PaletteModel m, StyleResolver resolver, int i) {
    // Row paint layers the way the shipped widgets do it: the hover wash first
    // (weakest, background-only, so the row's own foreground survives), then
    // the cursor fill over it. `focused` is never a row state — it means "the
    // widget owns input" and belongs to the chrome around the widget, not to
    // every row inside it.
    var style = const Style();
    if (i == m.hoverRow) {
      style = style.patch(resolver.resolve(null, const {WidgetState.hover}, cls: PaintClass.wash));
    }
    if (i == m.cursor) {
      style = style.patch(resolver.resolve(null, const {WidgetState.cursor}));
    }
    return Container(
      background: style,
      child: Line(' ${m.options[i]}', style: style),
    );
  }
}
```

The mistakes this shape avoids: putting `WidgetState.focused` in every row's
state set floods the whole widget with the focus fill (focus belongs on the
chrome — a border, a title — not on rows); and resolving hover as a fill
instead of a wash stomps a row's own foreground. The full reasoning is
`docs/theming-widgets.md`.

## Wiring it into an app

The app owns the model, routes messages to it, and intercepts its commands.
`FocusRouter` packages the routing — focus traversal, click-to-focus, pointer
dispatch by id — behind one call:

```dart
class AppModel {
  final palette = PaletteModel(
    id: 'palette',
    options: ['red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'violet', 'magenta'],
  );

  late final router = FocusRouter(FocusGroup<Component>([palette]));

  String? chosen;
}

(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  // Widget→app commands first: intercept the palette's choice by id.
  switch (model.router.route(msg, ctx)) {
    case Handled(cmd: PaletteChooseCmd(:final value)):
      model.chosen = value;
      return (model, null);
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // nothing consumed it — fall through to the app's own keys
  }

  if (msg case KeyMsg(key: 'q')) return (model, const Quit());
  return (model, null);
}
```

The fallback keys run only on `Declined`, so `q` can never quit while some
future text field is focused and typing. In `view`, chrome shows the focus
(rows never do), and the border around the palette does not disturb its row
math because the tag rides the palette's own subtree:

```dart
        child: Container(
          border: BorderType.plain,
          // Focus lives on the chrome: the border lights up when the palette
          // owns the keyboard; the rows inside only ever show cursor + hover.
          borderStyle: resolver.border({if (model.palette.focused) WidgetState.focused}),
          topTitles: [Line(' pick a color ', style: _theme.muted.ink)],
          child: Palette(model: model.palette, theme: _theme),
        ),
```

Turn the mouse on with `Application(mouseEvents: true, ...)` — with the tag in
place, that is the only switch.

## Making it mouse-aware

A pointer event arrives at `update` already resolved: it knows whose it is, and
`local` is the position in the widget's own cells. The framework half — router,
hit map, capture — is `packages/kiko_core/doc/mouse_routing.md`; the widget
half is this one branch at the **top** of `update`:

```dart
  @override
  UpdateResult update(Msg msg) {
    // The pointer branch sits ABOVE the focus gate: a wheel scrolls, a click
    // chooses, and a hover highlights whether or not the palette is focused.
    if (msg case final PointerMsg pointer) {
      if (pointer.wheelDeltaY != 0) {
        final moved = scrollBy(wheelScrollLines * pointer.wheelDeltaY);
        // A notch that moved nothing (already at that edge) is declined so a
        // scrollable ancestor can take it; any notch that moved is consumed.
        return moved == 0 ? const Declined() : const Handled();
      }
      if (pointer.isWheel) return const Declined(); // a horizontal wheel is not ours

      final row = localToRow(pointer.local);
      if (pointer.isDown) {
        // A press below the last option is not ours; the app may bubble it.
        if (row == null) return const Declined();
        hoverRow = row;
        // A click is the keyboard's cursor-move + confirm collapsed into one
        // event: move to the row, then emit the same command Enter emits.
        cursor = row;
        return Handled(PaletteChooseCmd(id, options[row]));
      }
      // A move, drag, or the release half of a click only refreshes the hover.
      hoverRow = row;
      return const Handled();
    }
    if (msg is PointerLeaveMsg) {
      hoverRow = null;
      return const Handled();
    }
    // The palette holds no gesture state (nothing armed on a press), so a
    // torn-off gesture is not its business.
    if (msg is PointerCancelMsg) return const Declined();
```

Walk it rule by rule:

- **The pointer branch sits above the focus gate.** The gate protects the
  keyboard only. A wheel must scroll, a click must choose, a hover must
  highlight on an *unfocused* widget — that is how mice behave everywhere else
  on your desktop.
- **A click emits the keyboard's command.** The press moves the cursor and
  returns the *same* id-addressed `PaletteChooseCmd` that Enter returns. The
  app cannot tell which device fired it, so it never grows a second, mouse-only
  path. A widget never emits a focus command from a click either — moving focus
  is the app's decision, and `FocusRouter` already does it on the press
  (`clickToFocus`).
- **Hover is a plain field.** `int? hoverRow`, set from `local`, folded into
  the row styling in `build`, cleared by `PointerLeaveMsg`. There is no hover
  interface and no enter message — the first `PointerMsg` addressed to the
  widget *is* the enter.
- **Decline what you don't consume.** A press past the last row is `Declined`
  so the app can offer it elsewhere (via the hit path); the horizontal wheel is
  declined because the palette has no use for it. `PointerCancelMsg` is
  declined here because the palette arms nothing on a press — contrast
  `ButtonModel`, which sets `pressed` on the down and therefore must consume
  the cancel to disarm it.

## Scrolling: the `ScrollableModel` surface

Scrolling is not a framework feature; it is model arithmetic behind a small
uniform surface. Mixing in `ScrollableModel` declares it:

```dart
  int _scrollOffset = 0;

  @override
  int get scrollOffset => _scrollOffset;

  @override
  int get visibleCount => viewportRows;

  @override
  int scrollBy(int rows) {
    final maxOffset = (options.length - visibleCount).clamp(0, options.length);
    final before = _scrollOffset;
    _scrollOffset = (_scrollOffset + rows).clamp(0, maxOffset);
    return _scrollOffset - before;
  }

  @override
  int? localToRow(Position local) {
    if (local.y < 0 || local.y >= visibleCount) return null;
    final row = _scrollOffset + local.y;
    return row < options.length ? row : null;
  }

  /// Snaps the viewport so the cursor is visible — keyboard navigation always
  /// brings its row into view, even after the wheel scrolled elsewhere.
  void _snapToCursor() {
    if (cursor < _scrollOffset) _scrollOffset = cursor;
    if (cursor >= _scrollOffset + visibleCount) _scrollOffset = cursor - visibleCount + 1;
  }
```

The behaviors this buys, all of which the pointer branch above already uses:

- **The wheel moves the viewport, never the cursor.** They travel
  independently; the next keypress snaps the viewport back to the cursor
  (`_snapToCursor`) — the Vim behavior. One notch is `wheelScrollLines` rows
  (3 by default; override the getter to change it).
- **`scrollBy` clamps and reports.** It stops at the content edges and returns
  the rows actually moved. That return value is what powers the wheel doctrine:
  a notch that returns 0 is declined *per direction* — wheel-up declines at the
  top while wheel-down still scrolls — so a scrollable ancestor gets the
  notch and nested scrolling works. Consuming at the edge would make nesting
  permanently dead.
- **`localToRow` owns the geometry.** Every pointer-to-row mapping goes through
  it, so a widget with a sticky header or taller rows adjusts one function and
  the whole mouse story follows.

`visibleCount` is a fixed constructor value here; a real widget measures its
viewport while painting and pushes the count into the model — ListView's
`setVisibleCount` shows the shape, including why the value lags a frame behind
a resize and why that is fine for clamping.

## Decline everything you don't understand

The routing contract rests on one discipline: **a widget consumes only what it
understands and declines everything else.** `FocusRouter` sends non-pointer,
non-traversal messages to the focused widget and returns its verdict as-is —
it never decides for a widget which messages it can handle. A widget with a
catch-all `Handled` tail therefore becomes a black hole: pastes, app-level
keys, and any future message class silently die in it.

The shared test `packages/kiko_widgets/test/widgets/decline_unknown_test.dart`
pins this for every shipped model — a widget contributed to `kiko_widgets`
belongs in that suite.

## Where to go next

- Run the finished example: `dart run example/custom_widget.dart` from
  `packages/kiko_widgets` (add mouse, wheel, and keys to taste — it is the
  playground this doc is cut from).
- Styling in depth — tones, projections, anatomy classes:
  `docs/theming-widgets.md`.
- The mouse framework half — hit map, capture, leave/cancel, dispatch:
  `packages/kiko_core/doc/mouse_routing.md`.
- Multiple widgets, chrome aliases, scroll-into-view, modal layering:
  `example/mouse_widgets.dart` and `example/scrollable_form.dart` in
  `kiko_widgets`.
- Widgets that load data asynchronously (the id-addressed `LoadRequest` /
  `LoadResult` round trip): `packages/kiko_widgets/doc/async_loading.md`.
- Testing what a widget renders: `docs/widget-testing.md`.
