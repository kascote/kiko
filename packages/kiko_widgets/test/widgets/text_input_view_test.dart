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
  group('text input view', () {
    test('renders the text and places the cursor at its end', () {
      final model = TextInputModel(id: 'in', initial: 'hi', focused: true);
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(_dump(frame.buffer), 'hi\n');
      expect(frame.hits.rectOf('in'), Rect.create(x: 0, y: 0, width: 5, height: 1));
      expect(frame.cursorPosition, const Position(2, 0));
    });

    test('shows the placeholder when empty', () {
      final model = TextInputModel(id: 'in', placeholder: 'name', focused: true);
      final frame = _frame(6, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(_dump(frame.buffer), 'name\n');
      expect(frame.cursorPosition, Position.origin);
    });

    test('obscures the text and tracks the cursor over the dots', () {
      final model = TextInputModel(id: 'in', initial: 'abc', obscureText: true, focused: true);
      final frame = _frame(6, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(_dump(frame.buffer), '•••\n');
      expect(frame.cursorPosition, const Position(3, 0));
    });

    test('has no cursor when unfocused', () {
      final model = TextInputModel(id: 'in', initial: 'hi');
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));
      expect(frame.cursorPosition, isNull);
    });

    test('a focused field keeps its cursor when an unfocused field renders after it', () {
      // Two fields in one frame — the first focused, the second not, as in any
      // form. The unfocused field reports no cursor; it must not write that null
      // over the focused field's cursor earlier in the same frame.
      final focused = TextInputModel(id: 'a', initial: 'hi', focused: true);
      final blurred = TextInputModel(id: 'b', initial: 'yo');
      final frame = _frame(10, 2)
        ..render(
          Column(
            children: [
              for (final m in [focused, blurred])
                ConstrainedBox(
                  additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
                  child: TextInput(model: m, theme: Theme.dark),
                ),
            ],
          ),
        );

      // The focused field's caret (end of 'hi' on row 0) survives.
      expect(frame.cursorPosition, const Position(2, 0));
    });

    test('focused text tints the foreground, never floods a background fill', () {
      final model = TextInputModel(initial: 'hi', focused: true);
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));
      final cell = frame.buffer[(x: 0, y: 0)];

      expect(cell.symbol, 'h');
      // Focus tints the glyph foreground (ink)...
      expect(cell.fg, equals(Theme.dark.focus.color));
      // ...and does not paint a focus-colored background over the text, which
      // would hide the characters and the terminal cursor.
      expect(cell.bg, isNot(equals(Theme.dark.focus.color)));
    });

    test('places the cursor mid-text when the model starts scrolled to the middle', () {
      final model = TextInputModel(initial: 'hello', focused: true)..cursor = 3;
      final frame = _frame(20, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('h'));
      expect(frame.buffer[(x: 4, y: 0)].symbol, equals('o'));
      expect(frame.cursorPosition, equals(const Position(3, 0)));
    });

    test('keeps the cursor within the visible area as it moves left inside the scrolled field', () {
      // Same model instance across renders to preserve scroll state.
      final model = TextInputModel(initial: 'abcdefgh', focused: true);

      // First render at cursor 8 (end) - scrolls to show "efgh".
      _frame(5, 1).render(TextInput(model: model, theme: Theme.dark));

      // Move cursor left within the scrolled window.
      model.cursor = 7;
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('e'));
      expect(frame.cursorPosition, equals(const Position(3, 0)));
    });

    test('scrolls back to the start when the cursor moves to the beginning', () {
      final model = TextInputModel(initial: 'abcdefgh', focused: true);

      // First scroll right by rendering with the cursor at the end.
      _frame(5, 1).render(TextInput(model: model, theme: Theme.dark));

      // Then jump to the beginning - should scroll back.
      model.cursor = 0;
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(frame.cursorPosition, equals(Position.origin));
    });

    test('handles a wide grapheme (emoji) scrolled into view', () {
      // "ab👋c" - 'ab' = 2 cols, '👋' = 2 cols, 'c' = 1 col, total 5 cols.
      // cursor at end (pos 4), cursorDisplayPos = 5.
      // scrollOffset = 5 - 4 + 1 = 2. Shows: "👋c" with cursor at col 4 (after 'c').
      final model = TextInputModel(initial: 'ab👋c', focused: true);
      final frame = _frame(4, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('👋'));
      expect(frame.buffer[(x: 2, y: 0)].symbol, equals('c'));
      expect(frame.cursorPosition, equals(const Position(3, 0)));
    });

    test('scrolls to keep the cursor in view when the value overflows the field', () {
      final model = TextInputModel(id: 'in', initial: 'hello world', focused: true);
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));

      // Cursor sits at the end (index 11 of 11); a 5-wide field scrolls right
      // by 7 columns to keep it in view, showing the tail "orld".
      expect(_dump(frame.buffer), 'orld\n');
      expect(frame.cursorPosition, const Position(4, 0));
    });

    test('fills remaining width with fillChar', () {
      final model = TextInputModel(id: 'in', initial: 'ab', fillChar: '_');
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), 'ab___\n');
    });

    test('paints real content through a RecordingSurface, not a hole', () {
      // Before this became a self-painting viewport, this node was a plain
      // box(child: lineNode(line)) composition — it never gated on
      // BufferSurface, so this was never actually broken for it, but the
      // scroll/fillChar paint path is new; confirm it too paints through a
      // bare Surface with no BufferSurface underneath.
      final model = TextInputModel(id: 'in', initial: 'ab', fillChar: '_');
      final node = TextInput(model: model, theme: Theme.dark).build()
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

  group('text input view under a partial clip (viewport)', () {
    test('anchors content at the placement rect, not the clip sub-rect', () {
      // A field only ever paints one row, so the meaningful partial clip is
      // horizontal — the same bug a Viewport's vertical clip causes elsewhere.
      // Content must be computed against the full 10-wide placement (so column
      // 3 shows the placeholder's 4th character, matching where layout put the
      // field), not re-anchored at the clip's 4-wide origin — that would show
      // the placeholder's FIRST four characters shifted into view instead.
      final model = TextInputModel(id: 'in', placeholder: '0123456789');
      final node = TextInput(model: model, theme: Theme.dark).build()
        ..layout(plume.BoxConstraints.tight(const plume.Size(10, 1)), _ctx)
        ..place(plume.Offset.zero);

      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 1));
      final surface = BufferSurface(buffer)..pushClip(const plume.Rect(3, 0, 4, 1));
      node.paint(surface);
      surface.popClip();

      // Columns left of the clip are absent; columns 3-6 show the placeholder's
      // OWN characters '3456', not '0123' shifted over from the field's start.
      expect(_dump(buffer), '   3456\n');
    });
  });

  group('text input view / fill and style overrides', () {
    test('fills remaining space after the placeholder', () {
      final model = TextInputModel(placeholder: 'Hi', fillChar: '.');
      final frame = _frame(10, 1)..render(TextInput(model: model, theme: Theme.dark));

      // 'Hi' takes 2 chars, fill 8 dots.
      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('H'));
      expect(frame.buffer[(x: 1, y: 0)].symbol, equals('i'));
      expect(frame.buffer[(x: 2, y: 0)].symbol, equals('.'));
      expect(frame.buffer[(x: 9, y: 0)].symbol, equals('.'));
    });

    test('fills to maxLength, not the full field width, when maxLength is set', () {
      final model = TextInputModel(initial: 'abc', maxLength: 10, fillChar: '_');
      final frame = _frame(20, 1)..render(TextInput(model: model, theme: Theme.dark));

      // 'abc' takes 3 chars, fill to maxLength (10), so 7 underscores.
      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(frame.buffer[(x: 2, y: 0)].symbol, equals('c'));
      expect(frame.buffer[(x: 3, y: 0)].symbol, equals('_'));
      expect(frame.buffer[(x: 9, y: 0)].symbol, equals('_'));
      // Position 10+ should be empty (space).
      expect(frame.buffer[(x: 10, y: 0)].symbol, equals(' '));
    });

    test('applies style.fill to fill characters', () {
      final model = TextInputModel(
        initial: 'ab',
        fillChar: '_',
        style: const TextInputStyle(
          fill: Style(fg: Color.red, bg: Color.blue),
        ),
      );
      final frame = _frame(10, 1)..render(TextInput(model: model, theme: Theme.dark));

      // Text cells should have default style.
      expect(frame.buffer[(x: 0, y: 0)].fg, isNot(equals(Color.red)));

      // Fill cells should have the style.fill.
      expect(frame.buffer[(x: 2, y: 0)].symbol, equals('_'));
      expect(frame.buffer[(x: 2, y: 0)].fg, equals(Color.red));
      expect(frame.buffer[(x: 2, y: 0)].bg, equals(Color.blue));
    });

    test('applies theme fg to input text', () {
      final model = TextInputModel(initial: 'hello');
      final frame = _frame(10, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('h'));
      // Text gets theme.background.on.
      expect(frame.buffer[(x: 0, y: 0)].fg, equals(Theme.dark.background.on));
      expect(frame.buffer[(x: 4, y: 0)].symbol, equals('o'));
    });

    test('applies style.placeholder to placeholder text', () {
      final model = TextInputModel(
        placeholder: 'Type here',
        style: const TextInputStyle(placeholder: Style(fg: Color.gray)),
      );
      final frame = _frame(10, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('T'));
      expect(frame.buffer[(x: 0, y: 0)].fg, equals(Color.gray));
    });

    test('applies style.obscured to obscured text', () {
      final model = TextInputModel(
        initial: 'secret',
        obscureText: true,
        style: const TextInputStyle(obscured: Style(fg: Color.yellow)),
      );
      final frame = _frame(10, 1)..render(TextInput(model: model, theme: Theme.dark));

      // Uses the obscured style, not the plain text style.
      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('•'));
      expect(frame.buffer[(x: 0, y: 0)].fg, equals(Color.yellow));
    });

    test('no fill when the text already fills the entire maxLength', () {
      final model = TextInputModel(initial: 'abcde', maxLength: 5, fillChar: '_');
      final frame = _frame(10, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.buffer[(x: 4, y: 0)].symbol, equals('e'));
      expect(frame.buffer[(x: 5, y: 0)].symbol, equals(' ')); // no fill
    });

    test('handles wide fill characters', () {
      // Using a wide char like '＿' (fullwidth low line, 2 cols).
      final model = TextInputModel(initial: 'ab', fillChar: '＿');
      final frame = _frame(10, 1)..render(TextInput(model: model, theme: Theme.dark));

      // 'ab' = 2 cols, remaining 8 cols, wide char = 2 cols each, so 4 chars.
      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(frame.buffer[(x: 1, y: 0)].symbol, equals('b'));
      expect(frame.buffer[(x: 2, y: 0)].symbol, equals('＿'));
    });

    test('maxLength is clamped to the visible width', () {
      // maxLength 20 but only 5 visible.
      final model = TextInputModel(initial: 'ab', maxLength: 20, fillChar: '_');
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));

      // Should only fill up to the visible width (5), not maxLength (20).
      expect(frame.buffer[(x: 0, y: 0)].symbol, equals('a'));
      expect(frame.buffer[(x: 1, y: 0)].symbol, equals('b'));
      expect(frame.buffer[(x: 2, y: 0)].symbol, equals('_'));
      expect(frame.buffer[(x: 4, y: 0)].symbol, equals('_'));
    });
  });

  group('text input click routing', () {
    test('a click on the field resolves to its id', () {
      final model = TextInputModel(id: 'in', initial: 'hi', focused: true);
      final frame = _frame(5, 1)..render(TextInput(model: model, theme: Theme.dark));

      expect(frame.hits.hitId(0, 0), 'in');
      expect(frame.hits.hitId(4, 0), 'in');
      expect(frame.hits.hitId(5, 0), isNull);
    });
  });

  group('text input view / cjk measurer', () {
    // ° is ambiguous width: one cell by default, two under a cjk locale. The
    // view hands its layout measurer to the model every frame, so the
    // model's own cursor/scroll math (run during update, where no layout
    // context reaches it) stays keyed to the same ruler that painted the
    // field.
    test('the caret lands one column later per ambiguous character to its left', () {
      final defaultModel = TextInputModel(id: 'in', initial: 'a°bc', focused: true)..cursor = 3;
      final defaultFrame = _frame(10, 1)..render(TextInput(model: defaultModel, theme: Theme.dark));
      expect(defaultFrame.cursorPosition, const Position(3, 0), reason: 'a=1, °=1: caret after "a°b"');

      final cjkModel = TextInputModel(id: 'in', initial: 'a°bc', focused: true)..cursor = 3;
      final cjkFrame = _frame(10, 1, measurer: const TermUnicodeMeasurer(cjk: true))
        ..render(TextInput(model: cjkModel, theme: Theme.dark));
      expect(cjkFrame.cursorPosition, const Position(4, 0), reason: 'a=1, °=2: caret shifts one column later');
    });

    test("scrolls to the window the frame's own measurer implies", () {
      // Same model, same two renders (first scrolls all the way right, then
      // the caret moves left to just before °), run once per measurer.
      const content = 'abcdef°h';

      final defaultModel = TextInputModel(id: 'in', initial: content, focused: true)..cursor = content.length;
      _frame(5, 1).render(TextInput(model: defaultModel, theme: Theme.dark));
      defaultModel.cursor = 6;
      final defaultFrame = _frame(5, 1)..render(TextInput(model: defaultModel, theme: Theme.dark));
      expect(_dump(defaultFrame.buffer), 'ef°h\n');
      expect(defaultFrame.cursorPosition, const Position(2, 0));

      const cjkMeasurer = TermUnicodeMeasurer(cjk: true);
      final cjkModel = TextInputModel(id: 'in', initial: content, focused: true)..cursor = content.length;
      _frame(5, 1, measurer: cjkMeasurer).render(TextInput(model: cjkModel, theme: Theme.dark));
      cjkModel.cursor = 6;
      final cjkFrame = _frame(5, 1, measurer: cjkMeasurer)..render(TextInput(model: cjkModel, theme: Theme.dark));
      // ° now costs two cells, so less of the tail fits: one fewer leading
      // character is visible, and the caret — still immediately before ° —
      // sits one column earlier than under the default measurer.
      expect(_dump(cjkFrame.buffer), 'f°h\n');
      expect(cjkFrame.cursorPosition, const Position(1, 0));
    });
  });
}
