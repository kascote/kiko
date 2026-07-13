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
    var ticks = 0;
    var resizedAtTick = -1;

    final rc = await Application(backend: backend).run<resize.ResizeModel>(
      init: model,
      update: (m, msg, ctx) {
        final result = resize.update(m, msg, ctx);
        if (msg is ResizeMsg && resizedAtTick < 0) resizedAtTick = ticks;

        if (msg is FrameTickMsg) {
          ticks++;
          // Emitted only once the first frame has committed — any earlier
          // and it is startup noise the runtime correctly drops. The
          // backend's reported size changes in tandem with the event, the
          // way a real terminal resize would.
          if (ticks == 1) {
            // WindowResizeEvent's positional args are (heightChars,
            // widthChars, heightPixels, widthPixels).
            backend
              ..resizeTo(const TermSize(70, 24))
              ..emit(const WindowResizeEvent(24, 70, 1400, 560));
          }
          // Quit a couple of frames after the resize landed, so the frame
          // that repainted against the new size has had time to commit —
          // quitting the instant it lands would ship the frame before it.
          if (resizedAtTick >= 0 && ticks >= resizedAtTick + 2) {
            return (result.$1, const Quit());
          }
        }
        return result;
      },
      view: resize.view,
    );

    expect(rc, 0);
    expect(resizedAtTick, greaterThanOrEqualTo(0), reason: 'the resize should have reached update as a ResizeMsg');

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
