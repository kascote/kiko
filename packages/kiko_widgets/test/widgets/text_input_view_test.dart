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
  group('text input view', () {
    test('renders the text and places the cursor at its end', () {
      final model = TextInputModel(id: 'in', initial: 'hi', focused: true);
      final frame = _frame(5, 1)..renderNode(textInput(model, Theme.dark));

      expect(_dump(frame.buffer), 'hi\n');
      expect(frame.rectOf('in'), Rect.create(x: 0, y: 0, width: 5, height: 1));
      expect(frame.cursorPosition, const Position(2, 0));
    });

    test('shows the placeholder when empty', () {
      final model = TextInputModel(id: 'in', placeholder: 'name', focused: true);
      final frame = _frame(6, 1)..renderNode(textInput(model, Theme.dark));

      expect(_dump(frame.buffer), 'name\n');
      expect(frame.cursorPosition, Position.origin);
    });

    test('obscures the text and tracks the cursor over the dots', () {
      final model = TextInputModel(id: 'in', initial: 'abc', obscureText: true, focused: true);
      final frame = _frame(6, 1)..renderNode(textInput(model, Theme.dark));

      expect(_dump(frame.buffer), '•••\n');
      expect(frame.cursorPosition, const Position(3, 0));
    });

    test('has no cursor when unfocused', () {
      final model = TextInputModel(id: 'in', initial: 'hi');
      final frame = _frame(5, 1)..renderNode(textInput(model, Theme.dark));
      expect(frame.cursorPosition, isNull);
    });

    test('scrolls to keep the cursor in view when the value overflows the field', () {
      final model = TextInputModel(id: 'in', initial: 'hello world', focused: true);
      final frame = _frame(5, 1)..renderNode(textInput(model, Theme.dark));

      // Cursor sits at the end (index 11 of 11); a 5-wide field scrolls right
      // by 7 columns to keep it in view, showing the tail "orld".
      expect(_dump(frame.buffer), 'orld\n');
      expect(frame.cursorPosition, const Position(4, 0));
    });

    test('fills remaining width with fillChar', () {
      final model = TextInputModel(id: 'in', initial: 'ab', fillChar: '_');
      final frame = _frame(5, 1)..renderNode(textInput(model, Theme.dark));
      expect(_dump(frame.buffer), 'ab___\n');
    });

    test('paints real content through a RecordingSurface, not a hole', () {
      // Before this became a self-painting viewport, this node was a plain
      // box(child: lineNode(line)) composition — it never gated on
      // BufferSurface, so this was never actually broken for it, but the
      // scroll/fillChar paint path is new; confirm it too paints through a
      // bare Surface with no BufferSurface underneath.
      final model = TextInputModel(id: 'in', initial: 'ab', fillChar: '_');
      final node = textInput(model, Theme.dark)
        ..layout(plume.BoxConstraints.tight(const plume.Size(5, 1)), _ctx)
        ..place(plume.Offset.zero);
      final surface = plume.RecordingSurface<PaintToken>();
      node.paint(surface);

      final intents = surface.intents.map((i) => '$i').toList();
      expect(intents, isNotEmpty);
      expect(intents.any((i) => i.startsWith('drawText(0, 0, "ab"')), isTrue);
      expect(intents.any((i) => i.startsWith('drawText(2, 0, "___"')), isTrue);
    });
  });

  group('text input view / TextInput parity', () {
    // The old buffer-bridge widget (TextInput.render, still using
    // Line.renderWithOffset) and the new self-painting plume view must land
    // identical cells and cursor for the same model — this is the seam 0097
    // has to keep faithful before the old widget is deleted in 0088.
    void expectParity(TextInputModel model, {required int width}) {
      final legacyBuffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: 1));
      final legacyFrame = Frame(legacyBuffer.area, legacyBuffer, 0);
      TextInput(model, theme: Theme.dark).render(legacyBuffer.area, legacyFrame);

      final plumeFrame = _frame(width, 1)..renderNode(textInput(model, Theme.dark));

      expect(_dump(plumeFrame.buffer), _dump(legacyBuffer));
      expect(plumeFrame.cursorPosition, legacyFrame.cursorPosition);
    }

    test('a short value, no scroll needed', () {
      expectParity(TextInputModel(initial: 'hi', focused: true), width: 5);
    });

    test('a value scrolled to keep the end-of-text cursor in view', () {
      expectParity(TextInputModel(initial: 'abcdefgh', focused: true), width: 5);
    });

    test('a wide grapheme (emoji) scrolled into view', () {
      expectParity(TextInputModel(initial: 'ab👋c', focused: true), width: 4);
    });

    test('fillChar padding after the value', () {
      expectParity(TextInputModel(initial: 'ab', fillChar: '_'), width: 5);
    });
  });

  group('text input click routing', () {
    test('a click on the field resolves to its id', () {
      final model = TextInputModel(id: 'in', initial: 'hi', focused: true);
      final frame = _frame(5, 1)..renderNode(textInput(model, Theme.dark));

      expect(frame.hitId(0, 0), 'in');
      expect(frame.hitId(4, 0), 'in');
      expect(frame.hitId(5, 0), isNull);
    });
  });
}
