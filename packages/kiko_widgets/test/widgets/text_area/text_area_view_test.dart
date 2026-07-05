import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

const _ctx = plume.LayoutContext(measurer: plume.MonospaceMeasurer());

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
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

  group('text area click routing', () {
    test('a click in the editor resolves to its id', () {
      final model = TextAreaModel(id: 'notes', initial: 'ab\ncd', focused: true);
      final frame = _frame(4, 2)..render(TextArea(model: model, theme: Theme.dark));
      expect(frame.hitId(0, 0), 'notes');
      expect(frame.hitId(1, 1), 'notes');
    });
  });
}
