# The backend seam

`Backend` (`packages/kiko_core/lib/src/backend/backend.dart`) is the whole
surface `Terminal` and `Application` use to reach a terminal. It has two
implementations. `TermlibBackend` is the real one: it needs a TTY and is not
exported. `TestBackend` is in-memory and ships in `package:kiko/testing.dart`.

## One coordinate space

Above the seam there is one coordinate space: 0-based buffer cells. A backend
delivers events in buffer cells and accepts draw and cursor calls in buffer
cells. Terminals number their cells from 1; that is `TermlibBackend`'s
private business, and it translates on the way in and on the way out. Never
reintroduce a 1-based coordinate above the backend.

## Kiko types, and intake

The seam speaks kiko's own types. `Backend.profile` is kiko's `ColorProfile`,
mapped from termlib's `ProfileEnum` inside `TermlibBackend`; `Backend.size()`
returns kiko's `TermSize`. `TestBackend` imports no termlib.

The one exception is the event stream: `Backend.events` carries termparser
event types. They stop at intake — `eventToMsg` and `pointerFieldsFrom` turn
each terminal event into a kiko message, and no terminal type travels past
that point.

## Testing

`Terminal.create({Backend? backend})` and
`Application({@visibleForTesting Backend? backend})` both take an injected
backend, so the render loop and the full MVU drain run under `dart test`.

`TestBackend` keeps a `screen` buffer that every `draw` applies onto; assert
against it to check what was rendered. `lastDiff` records the cells the last
draw changed; assert against it to check the double buffer redrew only what
changed. `emit(event)` feeds the event loop a raw termparser event, and the
`emitKey`/`emitClick`/`emitWheel` helpers build the common ones.

`TestBackend` is not a terminal emulator. It parses no escape sequences, and
every call but `draw` is recorded, not simulated. How to test widgets and
apps with it: `docs/widget-testing.md`. The render loop and the full drain
under test: `packages/kiko_core/test/terminal_test.dart` and
`packages/kiko_core/test/application_test.dart`.

## `dispose()` flushes, and never exits

The framework never calls `exit()`. `Application.run` completes with the exit
code on every path, and terminating the process is the caller's line:
`exit(await Application(...).run(...))`.

`Backend.dispose()` flushes pending output; it closes nothing and exits
nothing. `TermlibBackend.dispose` flushes termlib's sink before disposing the
terminal. The reason: termlib writes through `dart:io` `stdout`'s async
buffer, and an app-side `exit()` right after `run()` could otherwise truncate
the terminal-restore bytes the backend just wrote.

## Resize events

A window resize reaches `update` as a `ResizeMsg`: `width` and `height` in
cells, plus `widthPixels` and `heightPixels` (0 when the terminal does not
report pixel sizes; most do not). Queued resizes coalesce, so `update` sees
only the latest.

`Application` enables resize reporting at startup, unconditionally — there is
no constructor flag. An unsupported terminal silently ignores the request.
The backend chooses between in-band reporting and a signal fallback, seeded
by the one-time probe in `Backend.init()`; callers never see which mechanism
fired.

Enabling in-band reporting makes the terminal echo its current size back
immediately. That report is startup noise, not a real resize:
`MvuRuntime.flushStartupEvents` drops any resize held before the first frame
commits. A resize after that reaches `update` normally.

Rendering never depends on resize events. `Terminal.draw` runs `autoResize`
before building each frame, which reads the backend's size and resizes the
buffers when it changed — so rendering stays correct on a terminal that
reports no resize events at all. `ResizeMsg` is informational: the app uses
it to react (recompute a scroll clamp, reflow content), never to make
resizing work. Worked example: `packages/kiko_core/example/resize.dart`.
