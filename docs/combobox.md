# Combobox: a text field paired with a filterable popup list

The reference for `Combobox`/`ComboboxModel`
(`packages/kiko_widgets/lib/src/widgets/combobox/`). Worked end to end in
`packages/kiko_widgets/example/combobox.dart`.

A combobox is a text field with a popup list under it. Typing filters the
list; committing an option writes its label into the field. Options come
either from an in-memory list or from the app, one query at a time.

## The parts and the scope

`ComboboxModel<T>` embeds a `TextInputModel` field, public as `field`, and a
private `ListViewModel<T, T>` for the popup. `Combobox.build()` wraps both in
`Tagged.scope(model.id, ...)`: the field and its one-cell toggle self-tag as
`fieldId` and `toggleId`, so a press on either resolves to a path under the
combobox's own `id` (`docs/mouse.md`, "Scopes"). The popup, painted as a
layer after the base tree, uses the same scope, so a press on a match row
resolves there too.

`anchorPath` and `togglePath` are the field's and the toggle's full hit
paths — `HitTag.join(id, fieldId)` and `HitTag.join(id, toggleId)` — and
the view uses them to anchor and size the popup. Nothing else needs them:
build a `ComboboxModel<T>` and route to it by `id`, the same as any other
`Component`.

## Keys

While the popup is closed, a text-editing key or Down opens it; Enter and
Escape decline, so the app's own bindings for them still fire. Opening
without editing places the popup cursor on the current value's row, matched
with `==`. A remote combobox applies the same rule when that open's answer
installs; a typed query's answer keeps the cursor on the first match. The
first edit over a pristine committed label clears the field before applying
itself, rather than appending to the shown label.

While the popup is open, Up, Down, Page Up and Page Down move its cursor.
Enter commits the cursor's option. Escape closes the popup and restores the
field to the last committed label, discarding whatever was typed. Every
other key edits the field.

## Strict-only commit

Typed text filters the popup; it never commits on its own. A value is set
only two ways: Enter with a matched option under the cursor, or a click on a
popup row. Closing the popup any other way — Escape, or losing focus —
restores the field to the last committed label and discards the edit. A
combobox therefore never holds a value the popup never offered.

## The two option paths

Pass `options:` to the constructor for an in-memory list. The popup filters
it with `matches` (defaulting to a case-insensitive contains on `label`) on
every keystroke, entirely client-side.

Omit `options:` and the combobox becomes remote: it asks the app for options
through the same `LoadRequest`/`LoadResult` contract every loading widget
uses, and the router delivers each answer to its `update`
(`docs/async-loading.md`). Every text
change, and opening the popup without typing, asks with a `QueryKey` naming
the query's text — and every ask clears the popup, so it only ever shows
the current query's state. Only the newest query's answer installs; an
older query's answer is dropped once its own slot resolves. `declineLoad`
resolves a query without installing — a policy refusal, not a failure; the
popup shows its stalled row until the next query.

## The query slot

`queryStatus` names where the newest query stands, in the shared
`SliceStatus` vocabulary: `filling` while it is in flight, `failed` after
its answer failed, `stalled` after it was refused, and `ready` once an
answer installed. `queryError` holds the failure's cause. Both read only
the newest query's state, so an older query still finishing in the
background never overwrites what the popup shows.

The view paints one status row from `queryStatus`, alone on the cleared
popup: `loadingLabel` while filling, `errorLabel` after a failure,
`stalledLabel` after a refusal. Each is a `Line`. A null label shows its
built-in text — 'Loading…', 'Failed to load', 'Not loaded' — and a given
line's own styling wins over the themed base
(`ComboboxStyle.loadingRow`/`errorRow`/`stalledRow`). A ready answer with
no options shows `emptyPlaceholder` instead: 'No matches' unless
overridden, `Line('')` for a blank body. The same placeholder shows when
no in-memory option matches. An in-memory combobox never shows a status
row: `queryStatus` stays `ready` and `queryError` null.

## The popup and placement

`Combobox.renderPopup(frame)` paints the popup as a layer: it renders into
its own clean slate and composites opaquely onto the frame
(`docs/glossary.md`). Call it after the base tree carrying the combobox has
painted, the same shape `renderModalOverlay` uses for a dialog. It is a
no-op while `ComboboxModel.isOpen` is false.

Placement comes from `renderAnchoredPopup`
(`packages/kiko_widgets/lib/src/widgets/popup/`), a helper any anchored
popup can reuse. It places the popup below the field when the requested
height fits there, above when below does not fit but above does, and
otherwise on whichever side has more room, with the height shrunk to fit.
The decision is made once per open session. The first paint of the session
reports it as a `PopupPlaced` message addressed to the combobox;
`ComboboxModel.update` stores it on `placement`, and the next paint passes
it back as the standing decision and reports nothing. It is re-decided only when the viewport area changes, so the popup
does not flip sides as the user scrolls its matches. `close()` clears the
held decision.

`popupBorder` frames the popup with a border. The popup box grows by the
border's two rows, so the visible match rows stay
`ComboboxModel.maxVisibleRows`. `popupBorderStyle` sets the border's ink; a
null one derives from the theme. The field carries no such option — an app
frames the field row itself, with a bordered `Container` around the
combobox, as any other field is framed. The popup needs the option because
the widget builds it privately, out of the app's reach.

## The base render and the popup layer

`build()` returns the field-and-toggle row; render it wherever the combobox
belongs in the layout, then call `renderPopup(frame)` once the base tree has
painted:

```dart
void appView(AppModel model, Frame frame) {
  final combo = Combobox(model: model.combo, theme: theme);
  frame.render(Column(children: [combo]));
  combo.renderPopup(frame); // no-op while closed
}
```

An app with several comboboxes calls `renderPopup` on each after the base
tree; only the open one paints.

## Outside-press dismissal

Nothing about clicking outside a combobox is built into the widget. A
combobox only ever sees pointer traffic addressed to its own scope. An app
that wants a click elsewhere to close an open popup checks it before
routing, and lets the message keep going afterward — the check only closes
the popup, it never swallows the press:

```dart
bool _outsideEveryCombo(String? targetId, Set<String> comboIds) =>
    targetId == null || HitTag.resolve(targetId, comboIds) == null;

if (msg case final PointerMsg pointer when pointer.isDown) {
  if (_outsideEveryCombo(pointer.targetId, comboIds)) {
    for (final combo in combos) {
      combo.close();
    }
  }
}
switch (router.route(msg, ctx)) { ... }
```

`packages/kiko_widgets/example/combobox.dart` runs this check for two
comboboxes at once.

## `clear()`

`clear()` empties the field and unsets the value. No key binds to it — a
combobox never decides on its own when the user wants to start over. An app
wires its own key or button to call it, the way
`packages/kiko_widgets/example/combobox.dart` binds Ctrl+R.

While the popup is open, `clear()` also reseeds it, so the rows match the
now-empty field. An in-memory combobox shows the unfiltered options again.
A remote one asks the empty query, clearing the popup to that query's
state; `clear()` returns the query's `LoadRequest`, and the app forwards
it the way it forwards one from `update`.

## Theming: `ComboboxStyle`

| slot              | derived default                  | matrix source    |
| ----------------- | --------------------------------- | ----------------- |
| `toggle`          | inherit, focused × ink            | focused × ink     |
| `popupGround`     | `resolver.ground(surface)`       | anatomy-specific  |
| `loadingRow`      | `resolver.ink(muted)`            | anatomy-specific  |
| `errorRow`        | `resolver.ink(muted)`            | anatomy-specific  |
| `stalledRow`      | `resolver.ink(muted)`            | anatomy-specific  |

A `null` slot derives from the theme by the rule above; a non-null slot is
the caller's exact style and wins verbatim (`docs/theming.md`). The field's
own look stays `TextInputModel`'s business — a combobox styles only the
parts it owns on top of the embedded field. The popup's match rows are
styled by the embedded list's own anatomy (`ListViewStyle`), not by
`ComboboxStyle`.
