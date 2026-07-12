import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Reads [length] cells from row [y] of [buffer], starting at column [x].
String read(Buffer buffer, int x, int y, int length) {
  final out = StringBuffer();
  for (var i = 0; i < length; i++) {
    out.write(buffer[(x: x + i, y: y)].symbol);
  }
  return out.toString();
}

void main() {
  test('a widget renders through Terminal onto a TestBackend screen', () async {
    final backend = TestBackend(size: const TermSize(4, 1));
    final terminal = await Terminal.create(backend: backend);

    await terminal.draw(
      (frame) => frame.render(
        Button(
          model: ButtonModel(id: 'ok', label: Line('OK')),
          theme: Theme.dark,
        ),
      ),
    );

    expect(read(backend.screen, 0, 0, 4), ' OK ');
    expect(terminal.lastDiffCount, 4, reason: 'the button styles its padding too, so every cell differs');
  });
}
