import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

const _ctx = plume.LayoutContext(measurer: plume.MonospaceMeasurer());

Frame _frame(int width, int height, {TextMeasurer measurer = const TermUnicodeMeasurer()}) {
  final buffer = Buffer.empty(
    Rect.create(x: 0, y: 0, width: width, height: height),
    measurer: measurer,
  );
  return Frame(buffer.area, buffer, 0);
}

String _dump(Buffer buffer) {
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

void main() {
  group('text area render', () {
    test('draws the buffer lines', () {
      final model = TextAreaModel(id: 'ta', initial: 'ab\ncd', focused: true);
      final frame = _frame(4, 2)..render(TextArea(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), 'ab\ncd\n');
    });

    test('carries the cursor to the frame when focused', () {
      final focused = TextAreaModel(id: 'ta', initial: 'ab', focused: true);
      final frame = _frame(4, 2)..render(TextArea(model: focused, theme: Theme.dark));
      expect(frame.cursorPosition, isNotNull);
      expect(frame.cursorPosition!.y, inInclusiveRange(0, 1));

      final blurred = TextAreaModel(id: 'ta', initial: 'ab');
      final frame2 = _frame(4, 2)..render(TextArea(model: blurred, theme: Theme.dark));
      expect(frame2.cursorPosition, isNull);
    });

    test('paints real content through a RecordingSurface, not a hole', () {
      // The body used to gate on `surface is BufferSurface`, so a golden
      // taken through plume's own RecordingSurface saw a border and nothing
      // else. Content now paints through the plume Surface protocol
      // directly; only cursor reporting stays BufferSurface-only (plume has
      // no cursor concept of its own), so a RecordingSurface simply gets none.
      final model = TextAreaModel(id: 'ta', initial: 'ab', focused: true);
      final node = TextArea(model: model, theme: Theme.dark).build()
        ..layout(plume.BoxConstraints.tight(const plume.Size(4, 1)), _ctx)
        ..place(plume.Offset.zero);
      final surface = plume.RecordingSurface<PaintToken>();
      node.paint(surface);

      final intents = surface.intents.map((i) => '$i').toList();
      expect(intents, isNotEmpty);
      expect(intents.any((i) => i.startsWith('drawText(0, 0, "ab')), isTrue);
    });
  });

  group('text area under a partial clip (viewport)', () {
    test('anchors content at the placement rect, not the clip sub-rect', () {
      // Simulates a Viewport ancestor showing only rows 2-4 of a 5-line editor
      // placed at (0, 0) with height 5: content must be computed against the
      // full placement (line 2 lands at screen row 2, matching where layout
      // put it), not re-anchored at the clip's origin — that would pin line0
      // to the top of the visible window instead of scrolling it off.
      final model = TextAreaModel(id: 'ta', initial: 'line0\nline1\nline2\nline3\nline4');
      final node = TextArea(model: model, theme: Theme.dark).build()
        ..layout(plume.BoxConstraints.tight(const plume.Size(6, 5)), _ctx)
        ..place(plume.Offset.zero);

      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 5));
      final surface = BufferSurface(buffer)..pushNode(const plume.Rect(0, 2, 6, 3));
      node.paint(surface);
      surface.popNode();

      // Rows scrolled above the clip are absent, not shown squeezed at the top.
      expect(_dump(buffer), '\n\nline2\nline3\nline4\n');
    });
  });

  group('text area click routing', () {
    test('a click in the editor resolves to its id', () {
      final model = TextAreaModel(id: 'notes', initial: 'ab\ncd', focused: true);
      final frame = _frame(4, 2)..render(TextArea(model: model, theme: Theme.dark));
      expect(frame.hits.hitId(0, 0), 'notes');
      expect(frame.hits.hitId(1, 1), 'notes');
    });
  });

  group('text area view / cjk measurer', () {
    // ° is ambiguous width: one cell by default, two under a cjk locale. The
    // view hands its layout measurer to the model every frame, so word wrap,
    // cursor movement and selection — all computed during update, where no
    // layout context reaches the model — stay keyed to the same ruler that
    // painted the last frame.
    test('word-wrap break points shift with the measurer, and re-layout invalidates the stale wrap', () {
      final model = TextAreaModel(id: 'ta', initial: 'ab°cd');

      final defaultFrame = _frame(4, 3)..render(TextArea(model: model, theme: Theme.dark));
      expect(_dump(defaultFrame.buffer), 'ab°c\nd\n\n', reason: 'a=1, b=1, °=1, c=1: "ab°c" fills the first row');

      // Re-render the SAME model under a session with a different measurer,
      // as a resize into a cjk-configured frame would. The wrap cache built
      // above must not survive this.
      final cjkFrame = _frame(4, 3, measurer: const TermUnicodeMeasurer(cjk: true))
        ..render(TextArea(model: model, theme: Theme.dark));
      expect(_dump(cjkFrame.buffer), 'ab°\ncd\n\n', reason: '° now costs two cells, so it no longer fits on row 0');
    });

    test('wrap-aware cursor movement (down/up) agrees with the wrap the same measurer paints', () {
      TextAreaModel primed(TextMeasurer measurer) {
        final model = TextAreaModel(id: 'ta', initial: 'ab°cd', focused: true)
          ..textArea.row = 0
          ..textArea.column = 0;
        _frame(4, 3, measurer: measurer).render(TextArea(model: model, theme: Theme.dark));
        return model;
      }

      final defaultModel = primed(const TermUnicodeMeasurer())..update(const KeyMsg('down'));
      expect(defaultModel.cursorCol, 4, reason: 'row 0 wraps to "ab°c" (width 4), so row 1 starts at column 4');
      final defaultFrame = _frame(4, 3)..render(TextArea(model: defaultModel, theme: Theme.dark));
      expect(defaultFrame.cursorPosition, const Position(0, 1));

      defaultModel.update(const KeyMsg('up'));
      expect(defaultModel.cursorCol, 0, reason: 'moving back up returns to the start of row 0');

      const cjkMeasurer = TermUnicodeMeasurer(cjk: true);
      final cjkModel = primed(cjkMeasurer)..update(const KeyMsg('down'));
      expect(
        cjkModel.cursorCol,
        3,
        reason: 'row 0 wraps to "ab°" (width 3 chars, 4 cells), so row 1 starts at column 3',
      );
      final cjkFrame = _frame(4, 3, measurer: cjkMeasurer)..render(TextArea(model: cjkModel, theme: Theme.dark));
      expect(cjkFrame.cursorPosition, const Position(0, 1));

      cjkModel.update(const KeyMsg('up'));
      expect(cjkModel.cursorCol, 0, reason: 'moving back up returns to the start of row 0');
    });

    test('selection highlight extent shifts with the measurer', () {
      // A 3-grapheme selection ("ab°") paints a different number of columns
      // depending on the ruler, so the plain-text run right after it starts
      // one column later under cjk.
      TextAreaModel selectFirstThree(TextMeasurer measurer) {
        final model = TextAreaModel(id: 'ta', initial: 'ab°cd', focused: true)
          ..textArea.row = 0
          ..textArea.column = 0;
        _frame(10, 1, measurer: measurer).render(TextArea(model: model, theme: Theme.dark));
        for (var i = 0; i < 3; i++) {
          model.update(const KeyMsg('shift+right'));
        }
        return model;
      }

      Iterable<String> paintIntents(TextAreaModel model, TextMeasurer measurer) {
        final node = TextArea(model: model, theme: Theme.dark).build()
          ..layout(plume.BoxConstraints.tight(const plume.Size(10, 1)), plume.LayoutContext(measurer: measurer))
          ..place(plume.Offset.zero);
        final surface = plume.RecordingSurface<PaintToken>();
        node.paint(surface);
        return surface.intents.map((i) => '$i');
      }

      const defaultMeasurer = TermUnicodeMeasurer();
      final defaultModel = selectFirstThree(defaultMeasurer);
      expect(
        paintIntents(defaultModel, defaultMeasurer).any((i) => i.startsWith('drawText(3, 0, "cd ')),
        isTrue,
        reason: '"ab°" paints 3 cells wide, so the plain run starts at column 3',
      );

      const cjkMeasurer = TermUnicodeMeasurer(cjk: true);
      final cjkModel = selectFirstThree(cjkMeasurer);
      expect(
        paintIntents(cjkModel, cjkMeasurer).any((i) => i.startsWith('drawText(4, 0, "cd ')),
        isTrue,
        reason: '° now costs two cells, so "ab°" paints 4 cells wide and the plain run starts one column later',
      );
    });
  });
}
