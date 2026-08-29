# Widget Testing

How to test kiko widgets — and whole applications — under `dart test`, with no
terminal attached: no TTY, no escape sequences, no process exit. The suites
named at the end run these same patterns for real.

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

which provides `TestBackend`, the in-memory backend. `TestBackend` is test
scaffolding, not production API, so it lives outside `package:kiko/kiko.dart`.

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

  expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ButtonPressEvent>()));
});

test('an unfocused button declines the same key', () {
  final button = ButtonModel(id: 'ok', label: Line('OK'));

  expect(button.update(const KeyMsg('enter')), isA<Declined>());
});
```

A keystroke that types text carries it in `text`. Widgets bind on `key` and
insert `text`, so a test for insertion supplies both, the way the terminal
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
  expect(up, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ButtonPressEvent>()));
});
```

The verdict is worth as much as the state. A widget consumes only what it
understands and declines everything else, and tests pin that discipline — a
wheel notch a button cannot use must come back `Declined` so a scrollable
ancestor can take it:

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
different measurer only when the test is about width behavior (see "One
measurer everywhere" below).

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

The diff is the reason to test at this level. A `Frame` test cannot see double
buffering; a `Terminal` test can pin that an unchanged cell is never
rewritten:

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

Input is driven with `TestBackend`'s emit helpers: `emitKey`, `emitClick`,
`emitMove`, `emitDrag`, `emitWheel`, `emitPaste`, `emitFocus`. The helpers
take kiko's own types. `emitKey` takes the same spec strings
`KeyMsg.key` and `KeyBinding` use (`'q'`, `'ctrl+a'`, `'shift+tab'`); the
pointer helpers take 0-based buffer cells and the same `PointerButton` and
modifier booleans `PointerMsg` carries. None of this needs a `termparser`
import — the helpers build the matching raw event internally and hand it to
the backend. A convenient place to emit is the `InitMsg` case in `update`,
which guarantees the loop is listening:

```dart
test('a key event reaches update and quits the app', () async {
  final backend = TestBackend(size: const TermSize(20, 2));

  final code = await Application(backend: backend).run<int>(
    init: 0,
    update: (model, msg, _) {
      if (msg is InitMsg) backend.emitKey('q');
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

One scheduling fact shapes these tests: a frame follows every processed
message, and **a `Quit` returns before the frame its message would have
caused**. A test that quits the moment its last keystroke is handled exits
before any frame paints the result. To assert on the painted screen, quit
from `Application.onFrame`, which fires with every committed frame: the keys
emitted during `InitMsg` are held until the first frame commits, land as one
burst, and the frame that paints them is the second.

```dart
test('a widget model wired into the loop sees the keystrokes and paints them', () async {
  final backend = TestBackend(size: const TermSize(20, 1));
  final input = TextInputModel(id: 'name', focused: true);

  await Application(
    backend: backend,
    onFrame: (frame) {
      // Frame 0 is the init draw; frame 1 is the one the keys caused.
      if (frame.count == 1) backend.emitKey('ctrl+q');
    },
  ).run<TextInputModel>(
    init: input,
    update: (model, msg, _) {
      switch (msg) {
        case InitMsg():
          backend
            ..emitKey('h')
            ..emitKey('i');
          return (model, null);
        case KeyMsg(key: 'ctrl+q'):
          return (model, const Quit());
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

`FrameScript`, from `package:kiko/testing.dart`, drives a scripted
end-to-end test: several events, each aimed at what the previous one painted.
It sends one step per committed frame. A step goes out from the first frame
committed after the previous step landed, so the hit map a step reads shows
the previous step's effect. A step has landed when the message its event
became reaches `update`. A report, a tick, or a message the app emits itself
never releases the next step. `script.onFrame` wires into
`Application.onFrame`. `script.wrap(update)` answers the script's quit key
with `Quit` before the app's update sees it. With a `readyId`, the steps are
built from the first frame in which that hit path is live:

```dart
test('a click places the caret where the field is painted, and a key inserts there', () async {
  final backend = TestBackend(size: const TermSize(20, 1));
  final input = TextInputModel(id: 'name', initial: 'hi', focused: true);
  final script = FrameScript(
    backend,
    readyId: 'name',
    steps: (hits) {
      final field = hits.rectOf('name')!;
      return [
        (b) => b.emitClick(field.x + 1, field.y),
        (b) => b.emitKey('x'),
      ];
    },
  );

  await Application(backend: backend, onFrame: script.onFrame).run<TextInputModel>(
    init: input,
    update: script.wrap(
      (model, msg, _) => switch (model.update(msg)) {
        Handled(:final cmd) => (model, cmd),
        Declined() => (model, null),
      },
    ),
    view: (model, frame) => frame.render(TextInput(model: model, theme: Theme.dark)),
  );

  expect(script.completed, isTrue);
  expect(input.value, 'hxi');
  expect(screenText(backend.screen), 'hxi\n');
});
```

After `run` returns, `script.completed` says every step went out and the
quit key followed, and `script.lastFrame` is the frame that shows the last
step's effect. The suites under `packages/kiko_widgets/test/widgets/`
(`combobox/combobox_e2e_test.dart`, `example_mouse_test.dart`) drive whole
examples this way.

The runtime turns whatever a helper emits into the same `KeyMsg`, `PointerMsg`,
`PasteMsg` and `FocusMsg` a real session delivers. A model test constructs
those messages directly; this level derives them from the event a terminal
would have sent.

### Raw `emit`

The helpers cover a click (a paired press and release), a drag, a wheel notch,
a paste, a focus change, and a plain key press. Some events no helper builds:
a key repeat, a key release, a press and release split across separate ticks.
Those go through `emit(event)`, which takes a raw `termparser` event
(`KeyEvent`, `MouseEvent`, `PasteEvent`, `FocusEvent`, `WindowResizeEvent`)
and feeds it to the backend untranslated. `emit` is the only path that needs a
`termparser` import, so reach for it only when the raw event matters — a suite
that stays on the helpers (all of `kiko_widgets`' suites do) carries no
`termparser` dependency at all:

```dart
import 'package:termparser/termparser_events.dart';

test('a key release reaches update — no helper builds one', () async {
  final backend = TestBackend(size: const TermSize(10, 1));

  final code = await Application(backend: backend).run<int>(
    init: 0,
    update: (model, msg, _) {
      if (msg is InitMsg) {
        backend.emit(const KeyEvent(KeyCode.char('a'), eventType: KeyEventType.keyRelease));
      }
      if (msg is KeyReleaseMsg) return (model, const Quit(1));
      return (model, null);
    },
    view: (model, frame) => frame.render(Line('release test')),
  );

  expect(code, 1);
});
```

This level also answers questions the lower ones cannot: mode setup and
restore (`backend.rawMode`, `alternateScreen`, …) at startup and at exit,
exit codes on the error path, and hit-testing through the `UpdateContext` the
runtime hands `update`.

## One measurer everywhere

A session measures every glyph with one `TextMeasurer`, and width tests must
respect that. The backend's `screen` applies wide-cell bookkeeping with its
own measurer, so pass the **same** measurer to the backend and to the
`Terminal` or `Application` it serves. With the default measurer this is
automatic; it matters the moment a test opts into another one:

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
