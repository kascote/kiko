import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import '../example/resize.dart' as resize;

// Smoke test for `example/resize.dart`: boots the example's actual model,
// update, and view under a real Application over a TestBackend, and drives a
// real WindowResizeEvent through the same path a terminal would.

/// Flattens every row of [buffer] into one string, so a test can look for a
/// piece of rendered text without hardcoding which row it landed on.
String _renderedText(Buffer buffer) {
  final out = StringBuffer();
  for (var y = 0; y < buffer.area.height; y++) {
    for (var x = 0; x < buffer.area.width; x++) {
      out.write(buffer[(x: x, y: y)].symbol);
    }
    out.writeln();
  }
  return out.toString();
}

void main() {
  test('a resize emitted after the first frame updates the tracked size and the on-screen readout', () async {
    final backend = TestBackend(size: const TermSize(40, 12));
    final model = resize.ResizeModel();
    var resized = false;
    var quitSent = false;

    final rc =
        await Application(
          backend: backend,
          onFrame: (frame) {
            // The first frame commits inside the startup hold, where a
            // WindowResizeEvent is startup noise the runtime drops. A nudge key
            // crosses the hold; the resize goes out once update sees it.
            if (frame.count == 0) backend.emitKey('n');
            // The first frame committed after the resize landed painted against
            // the new size; quitting any earlier would ship the frame before it.
            if (resized && !quitSent) {
              quitSent = true;
              backend.emitKey('q');
            }
          },
        ).run<resize.ResizeModel>(
          init: model,
          update: (m, msg, ctx) {
            switch (msg) {
              case KeyMsg(key: 'n'):
                // The backend's reported size changes in tandem with the event,
                // the way a real terminal resize would. WindowResizeEvent's
                // positional args are (heightChars, widthChars, heightPixels,
                // widthPixels).
                backend
                  ..resizeTo(const TermSize(70, 24))
                  ..emit(const WindowResizeEvent(24, 70, 1400, 560));
                return (m, null);
              case KeyMsg(key: 'q'):
                return (m, const Quit());
              case ResizeMsg():
                resized = true;
            }
            return resize.update(m, msg, ctx);
          },
          view: resize.view,
        );

    expect(rc, 0);
    expect(resized, isTrue, reason: 'the resize should have reached update as a ResizeMsg');
    expect(quitSent, isTrue, reason: 'a frame committed after the resize');

    expect(model.width, 70);
    expect(model.height, 24);
    expect(model.widthPixels, 560);
    expect(model.heightPixels, 1400);
    expect(model.resizeCount, 1);

    expect(backend.screen.area.width, 70);
    expect(backend.screen.area.height, 24);

    final text = _renderedText(backend.screen);
    expect(text, contains('cells   : 70×24'));
    expect(text, contains('pixels  : 560×1400'));
    expect(text, contains('resizes : 1'));
  });
}
