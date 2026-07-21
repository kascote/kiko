# Widget Testing

How to test kiko widgets — and whole applications — under `dart test`, with no
terminal attached: no TTY, no escape sequences, no process exit. Every snippet
below is verified against the current API; the suites named at the end are the
living versions of these patterns.

There are three levels, and most tests belong on the cheapest one that answers
the question:

1. **Model tests** call `update` directly and assert on state and the verdict.
   Nothing renders.
2. **Render tests** paint a view into a `Frame` and assert on the cells. Real
   layout, no terminal.
3. **Loop tests** put a `TestBackend` under a `Terminal` or an `Application`
   and exercise the real render loop, or the full MVU drain.

Levels 1 and 2 use only the production API. Level 3 adds one import:

```dart
import 'package:kiko/testing.dart';
```

which provides `TestBackend`, the in-memory backend. It is scaffolding, not
production API, which is why it lives outside `package:kiko/kiko.dart`.

## Testing the model: `update` is just a method

A widget model's `update(Msg)` is an ordinary method on an ordinary object.
Construct the model, hand it a message, and assert on two things: the verdict —
`Handled`, optionally carrying a `Cmd`, or `Declined` — and the state the model
mutated.

Messages are plain values. A keystroke is `const KeyMsg('enter')`:

```dart
test('enter presses a focused button', () {
  final button = ButtonModel(id: 'ok', label: Line('OK'), focused: true);

  final result = button.update(const KeyMsg('enter'));

  expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ButtonPressCmd>()));
});

test('an unfocused button declines the same key', () {
  final button = ButtonModel(id: 'ok', label: Line('OK'));

  expect(button.update(const KeyMsg('enter')), isA<Declined>());
});
```

A keystroke that types text carries it in `text` — widgets bind on `key` and
insert `text`, so a test for insertion must supply both, the way the terminal
would:

```dart
test('typing inserts the keystroke text', () {
  final input = TextInputModel(id: 'name', focused: true)
    ..update(const KeyMsg('h', text: 'h'))
    ..update(const KeyMsg('i', text: 'i'));

  expect(input.value, 'hi');
});
```

### Pointer messages

The framework delivers a mouse event to a widget already resolved: addressed to
the widget's id, with the position translated into the widget's own cells. A
model test does that resolution itself — a small helper builds the resolved
`PointerMsg` for a widget pinned at a known rect:

```dart
/// A pointer over a 6×1 button at the origin, addressed to `'ok'`.
PointerMsg pointerAt(PointerAction action, {int x = 0, int y = 0}) => PointerMsg(
  global: Position(x, y),
  action: action,
  local: Position(x, y),
  targetId: 'ok',
  targetRect: Rect.create(x: 0, y: 0, width: 6, height: 1),
);
```

With that in hand, a press-release interaction is two calls:

```dart
test('down then up inside the button activates it', () {
  final button = ButtonModel(id: 'ok', label: Line('OK'))
    ..update(pointerAt(PointerAction.down, x: 2));
  expect(button.pressed, isTrue);

  final up = button.update(pointerAt(PointerAction.up, x: 2));
  expect(up, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ButtonPressCmd>()));
});
```

The verdict is worth as much as the state. A widget consumes only what it
understands and declines everything else, and tests are where that discipline
is pinned — a wheel notch a button cannot use must come back `Declined` so a
scrollable ancestor can take it:

```dart
test('the wheel is declined so a scrollable ancestor can take it', () {
  final button = ButtonModel(id: 'ok', label: Line('OK'));

  expect(button.update(pointerAt(PointerAction.wheelDown)), isA<Declined>());
});
```

The shared suite `packages/kiko_widgets/test/widgets/decline_unknown_test.dart`
pins the decline contract — unknown messages, key releases, bare modifiers —
for every shipped model at once. A new widget joins that suite rather than
writing its own one-off decline tests.

## Testing the view: render into a Frame

A `Frame` over an in-memory `Buffer` runs real layout and paint with no
terminal anywhere. Two small helpers cover most suites — a frame factory and a
buffer-to-string dump:

```dart
/// A frame over a fresh in-memory buffer, ready to render into.
Frame testFrame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// The buffer as a string: one line per row, trailing blanks trimmed.
String screenText(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}
```

`frame.render(view)` lays the view out tight to the frame's area and paints it
into the buffer. After it returns, everything a frame knows is open for
assertion: the cells, the cursor the frame requested, and the tagged geometry
in `frame.hits`:

```dart
test('renders the text and places the cursor at its end', () {
  final model = TextInputModel(id: 'name', initial: 'hi', focused: true);
  final frame = testFrame(6, 1)..render(TextInput(model: model, theme: Theme.dark));

  expect(screenText(frame.buffer), 'hi\n');
  expect(frame.cursorPosition, const Position(2, 0));
  expect(frame.hits.rectOf('name'), Rect.create(x: 0, y: 0, width: 6, height: 1));
});
```

For styling, index the buffer and assert on the cell — `symbol`, `fg`, `bg`,
`modifier`. Coordinates are 0-based buffer cells everywhere:

```dart
test('focus tints the glyph, not the background', () {
  final model = TextInputModel(id: 'name', initial: 'hi', focused: true);
  final frame = testFrame(6, 1)..render(TextInput(model: model, theme: Theme.dark));

  final cell = frame.buffer[(x: 0, y: 0)];
  expect(cell.symbol, 'h');
  expect(cell.fg, Theme.dark.focus.color);
  expect(cell.bg, isNot(Theme.dark.focus.color));
});
```

`Buffer.empty` measures text with the default `TermUnicodeMeasurer`; pass a
different measurer only when the test is about width behavior (see the last
section).

## Testing through a Terminal

`TestBackend` renders to memory instead of a terminal. Hand one to
`Terminal.create` and the whole render pipeline runs — double buffering,
diffing, flushing — with the results landing in fields a test can read:

- `screen` is a `Buffer` the size of the terminal onto which every draw applies
  its cells. It answers what was *rendered* across all draws so far, not merely
  what the last one wrote.
- `lastDiff` is the list of cells the last draw was handed — assert against it
  to check the double buffer redrew only what changed.
- Everything else — mode toggles, cursor moves, title, cleared regions — is
  recorded in plain fields (`rawMode`, `cursor`, `title`, `clears`, …).

It is **not a terminal emulator**: it parses no escape sequences, and every
call but `draw` is recorded rather than simulated.

```dart
test('a widget renders through the terminal onto the backend screen', () async {
  final backend = TestBackend(size: const TermSize(4, 1));
  final terminal = await Terminal.create(backend: backend);

  await terminal.draw(
    (frame) => frame.render(
      Button(model: ButtonModel(id: 'ok', label: Line('OK')), theme: Theme.dark),
    ),
  );

  expect(screenText(backend.screen), ' OK\n');
});
```

The diff side is what makes this level worth its weight — a `Frame` test
cannot see double buffering, but a `Terminal` test can pin that an unchanged
cell is never rewritten:

```dart
test('the second draw repaints only the cell that changed', () async {
  final backend = TestBackend(size: const TermSize(10, 1));
  final terminal = await Terminal.create(backend: backend);

  await terminal.draw((frame) => frame.render(Line('ab')));
  await terminal.draw((frame) => frame.render(Line('ac')));

  expect(terminal.lastDiffCount, 1);
  expect(backend.lastDiff.single.cell.symbol, 'c');
  expect(screenText(backend.screen), 'ac\n');
});
```

`resizeTo` drives a resize: it swaps the backend's size and clears `screen`,
and the terminal notices on its next draw:

```dart
test('a resize is picked up on the next draw', () async {
  final backend = TestBackend(size: const TermSize(10, 3));
  final terminal = await Terminal.create(backend: backend);
  await terminal.draw((frame) => frame.render(Line('hello')));

  backend.resizeTo(const TermSize(4, 2));
  await terminal.draw((frame) => frame.render(Line('hi')));

  expect(terminal.viewportArea, Rect.create(x: 0, y: 0, width: 4, height: 2));
  expect(screenText(backend.screen), 'hi\n\n');
});
```

## Testing a whole application

`Application(backend: testBackend)` runs the full MVU loop under `dart test`:
`run()` drains messages, renders frames, restores the terminal, and completes
with the exit code — the framework never calls `exit()`.

Input is driven with `emit(event)`, which feeds the backend's event stream the
raw `termparser` events a terminal would produce — `KeyEvent`, `MouseEvent`,
`WindowResizeEvent`. The runtime turns them into the same `KeyMsg`,
`PointerMsg` and `ResizeMsg` a real session delivers. This is the only level
where `termparser` appears in a downstream package, because here the test is
standing in for the terminal — model-level tests build `PointerMsg` from kiko
values alone. A convenient place to emit is the `InitMsg` turn, which
guarantees the loop is listening:

```dart
import 'package:termparser/termparser_events.dart';

test('a key event reaches update and quits the app', () async {
  final backend = TestBackend(size: const TermSize(20, 2));

  final code = await Application(backend: backend).run<int>(
    init: 0,
    update: (model, msg, _) {
      if (msg is InitMsg) backend.emit(const KeyEvent(KeyCode.char('q')));
      if (msg case KeyMsg(key: 'q')) return (model, const Quit(3));
      return (model, null);
    },
    view: (model, frame) => frame.render(Line('press q to quit')),
  );

  expect(code, 3);
  expect(screenText(backend.screen), 'press q to quit\n\n');
  expect(backend.disposed, isTrue);
});
```

One scheduling fact shapes these tests: the model updates on every message,
but **rendering happens only on frame ticks**. A test that quits the moment
its last keystroke is handled exits before any frame paints the result. To
assert on the painted screen, let one tick render and quit on the next:

```dart
test('a widget model wired into the loop sees the keystrokes and paints them', () async {
  final backend = TestBackend(size: const TermSize(20, 1));
  final input = TextInputModel(id: 'name', focused: true);
  var ticks = 0;

  await Application(backend: backend).run<TextInputModel>(
    init: input,
    update: (model, msg, _) {
      switch (msg) {
        case InitMsg():
          backend
            ..emit(const KeyEvent(KeyCode.char('h')))
            ..emit(const KeyEvent(KeyCode.char('i')));
          return (model, null);
        case FrameTickMsg():
          // The keys are processed before the first tick, so that tick's
          // render paints them; the second tick quits.
          ticks++;
          return (model, ticks == 2 ? const Quit() : null);
        default:
          return switch (model.update(msg)) {
            Handled(:final cmd) => (model, cmd),
            Declined() => (model, null),
          };
      }
    },
    view: (model, frame) => frame.render(TextInput(model: model, theme: Theme.dark)),
  );

  expect(input.value, 'hi');
  expect(screenText(backend.screen), 'hi\n');
});
```

This level also answers questions the lower ones cannot: mode setup and
restore (`backend.rawMode`, `alternateScreen`, and friends, on the way in and
the way out), exit codes on the error path, and hit-testing through the
`UpdateContext` the runtime hands `update`.

## One measurer everywhere

A session measures every glyph with one `TextMeasurer`, and tests about width
behavior must respect that: the backend's `screen` applies wide-cell
bookkeeping with its own measurer, so pass the **same** measurer to the
backend and to the `Terminal` or `Application` it serves. With the default
measurer this is automatic; it matters the moment a test opts into another
one:

```dart
test('a cjk session widens the ambiguous glyph in layout and paint alike', () async {
  const measurer = TermUnicodeMeasurer(cjk: true);
  final backend = TestBackend(size: const TermSize(4, 1), measurer: measurer);
  final terminal = await Terminal.create(backend: backend, measurer: measurer);

  await terminal.draw((frame) => frame.render(const Row(children: [Text('°'), Text('X')])));

  expect(backend.screen[(x: 0, y: 0)].symbol, '°');
  expect(backend.screen[(x: 2, y: 0)].symbol, 'X');
});
```

A wide glyph occupies its cell plus trailing cells marked `skip`; the
`screenText` helper above already handles them.

## Where the real suites live

- `packages/kiko_core/test/terminal_test.dart` — the render pipeline through a
  `TestBackend`: draws, diffs, resizes, cursor, mode toggles.
- `packages/kiko_core/test/application_test.dart` — the full loop: event
  drain, exit paths, mode restore, the update context, session measurers.
- `packages/kiko_widgets/test/widgets/` — model and view suites for every
  shipped widget; `button/button_model_test.dart` and
  `text_input_view_test.dart` are good templates.
- `packages/kiko_widgets/test/widgets/decline_unknown_test.dart` — the shared
  decline contract; add new widgets here.

For how to *build* the widget these tests exercise, see
`docs/building-widgets.md`.
