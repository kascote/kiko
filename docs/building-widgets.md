# Building Widgets with Kiko

How to write a stateful widget the way the shipped ones are written. This page
builds a small option picker — `PaletteModel` / `Palette` — end to end:
keyboard first, then the mouse, then wheel scrolling. The finished program is
`packages/kiko_widgets/example/custom_widget.dart`. It compiles under the
package's analyzer and runs on a real terminal. Every snippet below is a slice
of it; keep the doc and the example in sync.

Prerequisites: the layout model (`packages/plume/README.md`) and the MVU shape
(root `README.md`). Styling has its own recipe (`docs/theming.md`); this page
only uses it.

## A widget is two halves

A kiko widget is a **model** and a **view**.

The **model** is mutable state plus an `update(Msg)` that consumes messages.
It implements `Component`: a stable `String id`, an `UpdateResult update(Msg)`,
and a `focused` setter (via `Focusable`). Models mutate in place — Bubble Tea
style, not Elm. `update` returns no new model, only a verdict: `Handled`
(consumed, optionally carrying a `Cmd`) or `Declined` (not consumed).

The **view** is a stateless class implementing `View`. It reads the model and
builds UI. The app's `view` function constructs it fresh every frame, and its
`build()` inflates a fresh plume `Node` every frame. Nothing is retained or
reconciled between frames.

The verdict is the contract everything else rests on. A parent routes a
message to a child and switches on the result. `Handled` ends the message;
`Declined` leaves it in flight for the next candidate — another widget, or the
app's own fallback keys.

## Views: what the render half is made of

Everything that renders implements one interface:

```dart
abstract interface class View {
  Node build();
}
```

`Line` and `Text` are views. `Container`, `Row`, `Column`, `Center`, `Padding`
are views that compose other views. Most widget view classes are one more of
these: they compose existing views and let plume do the geometry.

A widget that marks hit regions cannot stay at that level. A region is marked
at the moment its part is painted, so the widget needs a custom `Node` with
its own `performLayout`/`paintSelf`. The palette below marks each of its rows,
so it takes this shape. The windowed widgets use the same shape to build only
the rows in view (`packages/kiko_widgets/lib/src/widgets/list_view/`).

## The command

A widget talks to the app by returning commands from `update`. A command
addresses its owner by **id, carried by value** — never by object reference.
The app matches the id to find the owner, so one app can hold several palettes
without ambiguity.

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

The state is ordinary mutable fields. The `Component` surface is the only
requirement: the `id`, the `focused` setter, and `update`.

```dart
class PaletteModel with ScrollableModel implements Component {
  /// Creates a palette over [options], showing [viewportRows] rows at a time.
  PaletteModel({required this.id, required this.options, this.viewportRows = 5});

  @override
  final String id;

  /// The options to pick from.
  final List<String> options;

  /// How many rows the viewport shows. Fixed here to keep the example small;
  /// a production widget measures its viewport while it paints and reports
  /// the count as a `ViewportChanged` message (see ListView's source).
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

(`with ScrollableModel` is for the scrolling section below; ignore it for
now.)

The keyboard lives at the bottom of `update`, behind the focus gate. A widget
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

Two rules here carry the routing contract:

- **The gate declines; it does not swallow.** An unfocused widget answers
  `Declined`, so the message is still the app's.
- **The tail declines too.** A key the widget doesn't bind, a paste, a message
  class it has never heard of — all `Declined`. A catch-all `Handled` tail
  silently consumes messages the app needs (more under "Decline everything
  you don't understand").

The example matches raw `key` strings to stay small. Shipped widgets route
keys through a `KeyBinding<Action>` table instead (`ButtonAction`,
`defaultButtonBindings`, …) so apps can rebind them;
`packages/kiko_widgets/example/custom_keybindings.dart` shows the pattern.
The key contract itself — `key` vs `text`, releases, repeats, layouts — is
`docs/keyboard.md`. The one rule to carry from that page: **bind on `key`,
insert `text`, never derive one from the other.**

## The view: painting rows and marking them

The view is stateless and rebuilt every frame. A widget with discrete parts —
rows, here — paints them itself, so it can mark each part as a *hit region* in
the same loop that draws it. `Palette.build` returns that self-painting node,
stamped with the model's id:

```dart
final class Palette implements View {
  /// Creates a palette view over [model], styled by [theme].
  const Palette({required this.model, required this.theme});

  /// The model whose options, cursor, and hover this view renders.
  final PaletteModel model;

  /// The theme that resolves row styles.
  final Theme theme;

  @override
  Node build() => _PaletteViewport(model: model, theme: theme)..tag = IdTag(model.id);
}
```

That `..tag = IdTag(model.id)` is the whole mouse wiring on the view side. The tag is
the only requirement for pointer routing: **a tagged widget receives pointer
traffic; an untagged one receives none.** Widgets self-tag. The tag names this
subtree in the frame's hit map, so a pointer resolves to the model's id and
arrives at `update` already addressed. (`Tagged(id, child)` exists for areas
the *app* composes that no model owns — never wrap a self-tagging widget in
one.)

The node windows the visible options and paints each row. Right where it
paints one, it marks that row as a `RowRegion`:

```dart
  @override
  void paintSelf(Surface surface) {
    final m = model;
    final area = Rect.create(x: rect.x, y: rect.y, width: rect.width, height: rect.height);
    final end = (m.scrollOffset + m.visibleCount).clamp(0, m.options.length);

    var y = area.y;
    for (var i = m.scrollOffset; i < end; i++) {
      final rowRect = Rect.create(x: area.x, y: y, width: area.width, height: 1);

      // Mark the row where it is painted. Update switches on this region instead
      // of computing a row from the pointer's coordinates. `toPlume()` bridges
      // kiko's cell rect to plume's geometry rect that markRegion wants.
      markRegion(RowRegion(i), rowRect.toPlume());

      // Row paint layers the way the shipped widgets do: the hover wash first
      // (weakest, background-only, so the row's own foreground survives), then
      // the cursor fill over it. `focused` is never a row state — it means "the
      // widget owns input" and belongs to the chrome around the widget.
      var style = const Style();
      if (i == m.hoverRow) {
        style = style.patch(_resolver.resolve(null, const {WidgetState.hover}, cls: PaintClass.wash));
      }
      if (i == m.cursor) {
        style = style.patch(_resolver.resolve(null, const {WidgetState.cursor}));
      }

      fillRow(surface, x: rowRect.x, y: rowRect.y, width: rowRect.width, style: style);
      paintLine(
        surface,
        Line(' ${m.options[i]}', style: style),
        x: rowRect.x,
        y: rowRect.y,
        width: rowRect.width,
        measurer: _measurer,
      );
      y++;
    }
  }
```

`markRegion(RowRegion(i), rowRect)` records that row `i` was painted at
`rowRect`. The same loop paints the row and writes the mark, so the geometry a
click resolves against cannot drift from what was drawn. That is why the model
below re-derives nothing.

A `RowRegion` is a plain value class kiko_widgets shares across ListView,
TableView and TreeView. A widget with parts of its own defines its own region
types the same way: a value class implementing `Region`.

This shape avoids two mistakes. Putting `WidgetState.focused` in every row's
state set paints the focus fill across the whole widget — focus belongs on the
chrome (a border, a title), never on rows. Resolving hover as a fill instead
of a wash overwrites the row's own foreground. The full reasoning is
`docs/theming.md`.

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

The fallback keys run only on `Declined`. A future text field that consumes
`q` as typed text therefore keeps it from ever reaching the quit line.

In `view`, the chrome shows the focus; rows never do. The tag is on the
palette's own subtree, so the app's border does not shift the palette's
`local` coordinates:

```dart
        child: Container(
          border: BorderType.plain,
          // Focus lives on the chrome: the border lights up when the palette
          // owns the keyboard; the rows inside only ever show cursor + hover.
          borderStyle: resolver.border({if (model.palette.focused) WidgetState.focused}),
          topTitles: [Line(' pick a color ', style: resolver.ink(resolver.tones.muted))],
          child: Palette(model: model.palette, theme: _theme),
        ),
```

Turn the mouse on with `Application(mouseEvents: true, ...)`. With the tag in
place, that is the only switch.

## Making it mouse-aware

A pointer event arrives at `update` already resolved: it knows whose it is,
and it carries the *region* under it — the part the view marked while
painting. The framework half — router, hit map, region resolution, capture —
is `docs/mouse.md`. The widget half is this one branch at the **top** of
`update`:

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

      // The framework resolves the row under the pointer and carries it on the
      // message as a hit region — the view marks each option's row while it
      // paints, so update never turns a coordinate into a row. `handleRowPointer`
      // (from ScrollableModel) is the row handler every scrollable shares: on a
      // press it moves the cursor there, snaps the scroll, and returns the same
      // command Enter emits; on any other pointer it refreshes the hover.
      if (pointer.region case final RowScoped row) {
        return handleRowPointer(
          pointer,
          row.index,
          setHover: (r) => hoverRow = r,
          moveCursorTo: (r) {
            cursor = r;
            _snapToCursor();
          },
          activate: () => PaletteChooseCmd(id, options[row.index]),
        );
      }
      // No option under the pointer — the blank tail below the last row. A press
      // is not ours (the app may bubble it); a move clears the hover.
      if (pointer.isDown) return const Declined();
      hoverRow = null;
      return const Handled();
    }
    if (msg is PointerLeaveMsg) {
      hoverRow = null;
      return const Handled();
    }
    // The palette sets no state on a press, so a cancelled gesture leaves it
    // nothing to clean up.
    if (msg is PointerCancelMsg) return const Declined();
```

Walk it rule by rule:

- **The pointer branch sits above the focus gate.** The gate protects the
  keyboard only. A wheel must scroll, a click must choose, and a hover must
  highlight on an *unfocused* widget — that is how a mouse behaves in every
  other application.
- **Switch on the region, never on coordinates.** The view marked each row as
  a `RowRegion` while painting; the framework resolves the one under the
  pointer and hands it back on `pointer.region`. `handleRowPointer` (from
  `ScrollableModel`) is the row handler every scrollable's rows share. On a
  press it moves the cursor to the row, snaps the scroll, and returns the
  widget's activate command; on any other pointer it refreshes the hover. A
  `null` region means the pointer is on nothing marked (the blank tail): a
  press bubbles, a move clears the hover.
- **A click emits the keyboard's command.** The row handler returns the *same*
  id-addressed `PaletteChooseCmd` that Enter returns. The app cannot tell
  which device fired it, so it never grows a second, mouse-only path. A widget
  never emits a focus command from a click either — moving focus is the app's
  decision, and `FocusRouter` already does it on the press (`clickToFocus`).
- **Hover is a plain field.** `int? hoverRow`, set by the row handler, folded
  into the row styling in `build`, cleared by `PointerLeaveMsg`. There is no
  hover interface and no enter message — the first `PointerMsg` addressed to
  the widget *is* the enter.
- **Decline what you don't consume.** A press on no marked part is `Declined`
  so the app can offer it elsewhere (via the hit path). The horizontal wheel
  is declined because the palette has no use for it. `PointerCancelMsg` is
  declined because the palette sets no state on a press — contrast
  `ButtonModel`, which sets `pressed` on the down and must consume the cancel
  to clear it.

**Regions and `local` are two reading modes, both permanent.** The tag is the
only requirement for routing; past it, a widget chooses how to read the
pointer. A widget with discrete parts — rows, a header, an expand indicator —
marks regions and switches on `pointer.region`, as the palette does, and never
touches coordinates. A widget over a continuous surface — a text editor
mapping a click to a wrap-aware caret — marks no regions and reads
`pointer.local` instead: the position in its own cells, counted from the
tagged node's top-left. `local` stays on every pointer message in both modes.
Regions are the default for discrete parts because they cannot drift from the
paint; `local` is the tool when the thing under the pointer is not a discrete
part at all.

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

  /// Snaps the viewport so the cursor is visible — keyboard navigation always
  /// brings its row into view, even after the wheel scrolled elsewhere.
  void _snapToCursor() {
    if (cursor < _scrollOffset) _scrollOffset = cursor;
    if (cursor >= _scrollOffset + visibleCount) _scrollOffset = cursor - visibleCount + 1;
  }
```

The behaviors this provides — the pointer branch above already uses all of
them:

- **The wheel moves the viewport, never the cursor.** They travel
  independently; the next keypress snaps the viewport back to the cursor
  (`_snapToCursor`, the Vim behavior). One notch is `wheelScrollLines` rows —
  3 by default; override the getter to change it.
- **`scrollBy` clamps and reports.** It stops at the content edges and returns
  the rows actually moved. That return value powers the wheel rule: a notch
  that returns 0 is declined *per direction* — wheel-up declines at the top
  while wheel-down still scrolls — so a scrollable ancestor gets the notch
  and nested scrolling works. Consuming at the edge would make nesting
  permanently dead.
- **`handleRowPointer` is the shared row handler.** The mixin also carries the
  handler the pointer branch above calls — set the hover, move the cursor,
  activate — so all three shipped scrollables (and this palette) resolve a
  row click identically. It is a helper each widget calls from its own switch,
  not an interception: the verdict, and any deviation from the shared
  behavior, stay in the widget's code.

`visibleCount` is a fixed constructor value here. A real widget measures its
viewport while painting and, when the count differs from the one the model
holds, reports it as a `ViewportChanged` message (`docs/architecture.md`,
frame reports); the model stores the count in its `update`. The report is
addressed to `HitTag.join(surface.scopePath, model.id)`: the widget's hit
path under whatever scope it is painted in, with no parameter on the view.
ListView's paint and its `ViewportChanged` case show the shape, including why
the value lands one message after the frame that painted it and why that is
fine for clamping.

## Decline everything you don't understand

The routing contract rests on one discipline: **a widget consumes only what it
understands and declines everything else.** `FocusRouter` sends non-pointer,
non-traversal messages to the focused widget and returns its verdict as-is. It
never decides for a widget which messages it can handle. A widget with a
catch-all `Handled` tail therefore silently consumes pastes, app-level keys,
and every future message class.

The shared test `packages/kiko_widgets/test/widgets/decline_unknown_test.dart`
pins this for every shipped model. A widget contributed to `kiko_widgets`
belongs in that suite.

## Where to go next

- Run the finished example: `dart run example/custom_widget.dart` from
  `packages/kiko_widgets` — the example this page is cut from.
- Styling in depth — tones, projections, anatomy: `docs/theming.md`.
- The key contract — `key` vs `text`, bindings, releases: `docs/keyboard.md`.
- The mouse framework half — hit map, capture, leave/cancel, dispatch:
  `docs/mouse.md`.
- Multiple widgets, chrome scopes, scroll-into-view, modal layering:
  `packages/kiko_widgets/example/mouse_widgets.dart` and
  `packages/kiko_widgets/example/scrollable_form.dart`.
- Widgets that load data asynchronously (the id-addressed `LoadRequest` /
  `LoadResult` round trip): `docs/async-loading.md`.
- Testing what a widget renders: `docs/widget-testing.md`.
