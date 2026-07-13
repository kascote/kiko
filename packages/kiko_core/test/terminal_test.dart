import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:test/test.dart';

/// Paints [text] on row [y] of the frame, starting at column [x].
void paint(Frame frame, int x, int y, String text) {
  for (var i = 0; i < text.length; i++) {
    frame.buffer[(x: x + i, y: y)] = Cell.empty().setCell(char: text[i]);
  }
}

/// Reads [length] cells from row [y] of [buffer], starting at column [x].
String read(Buffer buffer, int x, int y, int length) {
  final out = StringBuffer();
  for (var i = 0; i < length; i++) {
    out.write(buffer[(x: x + i, y: y)].symbol);
  }
  return out.toString();
}

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend(size: const TermSize(10, 3)));

  Future<Terminal> terminal({ViewPort viewport = const ViewPortFullScreen()}) =>
      Terminal.create(backend: backend, viewport: viewport);

  group('Terminal.create', () {
    test('sizes the viewport to the backend', () async {
      final t = await terminal();

      expect(t.viewportArea, Rect.create(x: 0, y: 0, width: 10, height: 3));
      expect(t.size.width, 10);
      expect(t.frameCount, 0);
      expect(t.lastDiffCount, 0);
    });

    test('honours a fixed viewport', () async {
      final fixed = Rect.create(x: 2, y: 1, width: 4, height: 2);
      final t = await terminal(viewport: ViewPortFixed(fixed));

      expect(t.viewportArea, fixed);
    });
  });

  group('Terminal.draw', () {
    test('writes the painted cells to the backend screen', () async {
      final t = await terminal();

      await t.draw((frame) => paint(frame, 0, 0, 'hi'));

      expect(read(backend.screen, 0, 0, 2), 'hi');
      expect(backend.drawCount, 1);
      expect(backend.flushCount, 1);
    });

    test('reports the viewport area on the completed frame', () async {
      final t = await terminal();

      final completed = await t.draw((_) {});

      expect(completed.area, t.viewportArea);
      expect(completed.area, Rect.create(x: 0, y: 0, width: 10, height: 3));
    });

    test('reports the viewport area for a fixed viewport too', () async {
      final fixed = Rect.create(x: 2, y: 1, width: 4, height: 2);
      final t = await terminal(viewport: ViewPortFixed(fixed));

      final completed = await t.draw((_) {});

      // A fixed viewport never resizes, so the terminal area is never learned.
      expect(completed.area, fixed);
    });

    test('advances the frame count and reports it on the completed frame', () async {
      final t = await terminal();

      final first = await t.draw((frame) => paint(frame, 0, 0, 'a'));
      final second = await t.draw((frame) => paint(frame, 0, 0, 'a'));

      expect(first.count, 0);
      expect(second.count, 1);
      expect(t.frameCount, 2);
    });

    test('redraws only the cells that changed', () async {
      final t = await terminal();

      await t.draw((frame) => paint(frame, 0, 0, 'ab'));
      expect(t.lastDiffCount, 2);

      await t.draw((frame) => paint(frame, 0, 0, 'ac'));

      expect(t.lastDiffCount, 1, reason: 'only the second cell changed');
      expect(backend.lastDiff.single.x, 1);
      expect(backend.lastDiff.single.cell.symbol, 'c');
    });

    test('keeps the screen correct across draws, not just the last diff', () async {
      final t = await terminal();

      await t.draw((frame) => paint(frame, 0, 0, 'ab'));
      await t.draw((frame) => paint(frame, 0, 0, 'ac'));

      // 'a' was written once and never redrawn; the screen still holds it.
      expect(read(backend.screen, 0, 0, 2), 'ac');
    });

    test('an unchanged frame writes nothing', () async {
      final t = await terminal();

      await t.draw((frame) => paint(frame, 0, 0, 'ab'));
      await t.draw((frame) => paint(frame, 0, 0, 'ab'));

      expect(t.lastDiffCount, 0);
      expect(backend.lastDiff, isEmpty);
    });

    test('a frame that paints nothing erases the previous one', () async {
      final t = await terminal();

      await t.draw((frame) => paint(frame, 0, 0, 'ab'));
      await t.draw((_) {});

      expect(t.lastDiffCount, 2);
      expect(read(backend.screen, 0, 0, 2), '  ');
    });

    test('swaps buffers so the completed frame holds what was drawn', () async {
      final t = await terminal();

      final completed = await t.draw((frame) => paint(frame, 0, 0, 'ab'));

      expect(read(completed.buffer, 0, 0, 2), 'ab');
      expect(read(t.currentBuffer, 0, 0, 2), '  ', reason: 'the next frame starts clean');
    });

    test('shows and places the cursor when the frame asks for one', () async {
      final t = await terminal();

      await t.draw((frame) => frame.cursorPosition = const Position(3, 1));

      expect(backend.cursorVisible, isTrue);
      expect(backend.cursor, const Position(3, 1));
    });

    test('leaves the cursor alone when the frame sets none', () async {
      final t = await terminal();
      t.hideCursor();
      await t.draw((frame) => paint(frame, 0, 0, 'a'));

      expect(backend.cursorVisible, isFalse);
    });

    test('hides the cursor it showed once a later frame reports none', () async {
      final t = await terminal();
      await t.draw((frame) => frame.cursorPosition = const Position(3, 1));
      expect(backend.cursorVisible, isTrue, reason: 'the first frame showed a cursor');

      // The focused widget scrolled off / lost focus: this frame reports none,
      // so the runtime hides the cursor it had shown instead of stranding it.
      await t.draw((frame) => paint(frame, 0, 0, 'a'));
      expect(backend.cursorVisible, isFalse);
    });
  });

  group('Terminal.autoResize', () {
    test('resizes the viewport when the backend size changes', () async {
      final t = await terminal();
      await t.draw((_) {});

      backend.resizeTo(const TermSize(4, 2));
      await t.draw((frame) => paint(frame, 0, 0, 'xy'));

      expect(t.viewportArea, Rect.create(x: 0, y: 0, width: 4, height: 2));
      expect(read(backend.screen, 0, 0, 2), 'xy');
    });

    test('does not resize a fixed viewport', () async {
      final fixed = Rect.create(x: 0, y: 0, width: 4, height: 2);
      final t = await terminal(viewport: ViewPortFixed(fixed));
      await t.draw((_) {});

      backend.resizeTo(const TermSize(20, 8));
      await t.draw((_) {});

      expect(t.viewportArea, fixed);
    });

    test(
      'the next drawn frame paints at the new size (stale-frame regression)',
      () async {
        final t = await terminal(viewport: const ViewPortInline(2));
        await t.draw((_) {});

        backend.resizeTo(const TermSize(4, 2));
        final completed = await t.draw((frame) => paint(frame, 0, 0, 'xy'));

        expect(completed.area, Rect.create(x: 0, y: 0, width: 4, height: 2));
        expect(read(backend.screen, 0, 0, 2), 'xy');
      },
    );

    test(
      'resizes at most once per size change, even across further draws '
      '(double-resize regression)',
      () async {
        final t = await terminal(viewport: const ViewPortInline(2));
        await t.draw((_) {});
        backend
          ..insertNewLinesCount = 0
          ..clears.clear()
          ..resizeTo(const TermSize(4, 2));
        // An awaited draw completes its resize (including the cursor round
        // trip) before returning, so the second draw finds the size already
        // reconciled and must not resize again.
        await t.draw((_) {});
        await t.draw((_) {});

        expect(backend.insertNewLinesCount, 1);
        expect(
          backend.clears.where((c) => c == ClearType.afterCursor).length,
          1,
        );
      },
    );
  });

  group('Terminal.clear', () {
    test('clears the whole screen for a full screen viewport', () async {
      final t = await terminal();
      backend.clears.clear();

      t.clear();

      expect(backend.clears, [ClearType.all]);
    });

    test('clears below the cursor for an inline viewport', () async {
      final t = await terminal(viewport: const ViewPortInline(2));
      backend.clears.clear();

      t.clear();

      expect(backend.clears, [ClearType.afterCursor]);
      expect(backend.cursor, t.viewportArea.asPosition);
    });

    test('forces the next draw to repaint every cell', () async {
      final t = await terminal();
      await t.draw((frame) => paint(frame, 0, 0, 'ab'));
      t.clear();
      await t.draw((frame) => paint(frame, 0, 0, 'ab'));

      expect(t.lastDiffCount, 2, reason: 'the back buffer was reset, so nothing matches');
    });
  });

  group('Terminal mode toggles reach the backend', () {
    test('each enable and disable pair flips one flag', () async {
      final t = await terminal();

      t
        ..enableAlternateScreen()
        ..enableRawMode()
        ..enableMouseEvents()
        ..enableKeyboardEnhancement()
        ..enableBracketedPaste()
        ..enableFocusTracking()
        ..setTitle('kiko');

      expect(backend.alternateScreen, isTrue);
      expect(backend.rawMode, isTrue);
      expect(backend.mouseEvents, isTrue);
      expect(backend.keyboardEnhancement, isTrue);
      expect(backend.bracketedPaste, isTrue);
      expect(backend.focusTracking, isTrue);
      expect(backend.title, 'kiko');

      t
        ..disableAlternateScreen()
        ..disableRawMode()
        ..disableMouseEvents()
        ..disableKeyboardEnhancement()
        ..disableBracketedPaste()
        ..disableFocusTracking();

      expect(backend.alternateScreen, isFalse);
      expect(backend.rawMode, isFalse);
      expect(backend.mouseEvents, isFalse);
      expect(backend.keyboardEnhancement, isFalse);
      expect(backend.bracketedPaste, isFalse);
      expect(backend.focusTracking, isFalse);
    });

    test('hideCursor and showCursor track state on both sides', () async {
      final t = await terminal();

      t.hideCursor();
      expect(t.hiddenCursor, isTrue);
      expect(backend.cursorVisible, isFalse);

      t.showCursor();
      expect(t.hiddenCursor, isFalse);
      expect(backend.cursorVisible, isTrue);
    });

    test('dispose reaches the backend', () async {
      final t = await terminal();

      await t.dispose();

      expect(backend.disposed, isTrue);
    });
  });
}
