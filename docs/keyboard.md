# Keyboard: the contract and widget handling

The first half is the framework's contract — what a key event is and how it
reaches `update`. The second half is the consuming side — how a widget model
resolves keys. Both halves share one rule: **bind on `key`, insert `text`,
never derive one from the other.**

## The contract

A `KeyMsg` **is** a keystroke: a press, or an auto-repeat (`repeat: true`)
from a key held down. Treat a repeat exactly like a press. A plain terminal
that cannot report repeats redelivers a held key as ordinary presses with
`repeat: false`, so nothing may depend on that flag being accurate.

A key-up is a different class, `KeyReleaseMsg`. A bare modifier tap — Shift
alone, no other key involved; reported only under the kitty protocol — is
`ModifierKeyMsg`. Neither is a `KeyMsg`, so a `case KeyMsg(key: ...)` pattern
can never fire on them, and no widget or app code needs a transition check.

The rule for everything downstream: **bind on `key`, insert `text`, never
derive one from the other.** `key` is the canonical spec string bindings
match against: `'q'`, `'ctrl+a'`, `'shift+tab'`. Shift folds into the string
wherever it changes what was typed — Shift+A arrives as `'A'`, Shift+1 as
`'!'` — while a named key keeps the modifier spelled out (`'shift+tab'`).
`text` is the literal text the keystroke types, null for named keys and for
ctrl/alt chords.

`KeyBinding.map` canonicalizes every spec it registers, so `'shift+a'` and
`'A'` are the same binding no matter which form a caller writes.
`KeyBinding.resolve` accepts both press and repeat: a held arrow or backspace
keeps resolving to its action for as long as it repeats. When `key` matches
no binding, `resolve` falls back to `baseKey` — the same keystroke projected
onto a standard US layout. A shortcut bound to `'ctrl+z'` therefore still
fires from Ctrl+Я on a Cyrillic layout.

`Application(keyboardEnhancement: bool?)` controls the kitty keyboard
protocol request. The default `null` is automatic: the runtime requests the
full protocol when the startup capability probe confirms the terminal
supports it, and a terminal that fails the probe gets plain behavior.
`false` always keeps the request off; `true` sends it regardless of what the
probe found. Most apps should leave it unset.

Wherever the enhancement is active, it only **adds** fidelity to the contract
above: exact typed text instead of a guess, `repeat` marked accurately
instead of resent as plain presses, releases and bare modifiers reported
instead of invisible. It never changes how a correctly written handler
behaves.

## Widget keyboard handling

A widget resolves its own keyboard behind the focus gate:
`if (!focused) return const Declined();`. The tutorial
(`docs/building-widgets.md`) works this shape end to end. The rules:

- **Resolve bindings first.** Route `key` (and its repeats) through a
  `KeyBinding<Action>` table (`ButtonAction`, `TextInputAction`, …) so an
  app can rebind without touching the model. A raw `switch` on `key` is fine
  for a widget small enough that a table adds nothing.
- **Editors insert `msg.text`, never `msg.key`.** Once nothing binds, an
  editable model falls through to inserting `text` — the literal text the
  keystroke types, already shift- and layout-resolved by the terminal. `text`
  is null for named keys and ctrl/alt chords, so the fallthrough does nothing
  for `tab` or `ctrl+s`.
- **Decline `KeyReleaseMsg` and `ModifierKeyMsg`.** Neither carries a binding
  or insertable text. A widget that adds no special case for them declines
  them by falling through the same tail every unbound key does. The shared
  suite `packages/kiko_widgets/test/widgets/decline_unknown_test.dart` covers
  both for every shipped model — add a new widget to that suite rather than
  writing a one-off release/modifier test.
- **Never check a press/repeat/release transition.** `KeyMsg.repeat` is
  informational only — do not gate behavior on it, since a terminal without
  the kitty enhancement never sets it. The three message classes already make
  a release or a bare modifier edge unreachable from a `KeyMsg` pattern, so
  there is nothing to track between messages.
