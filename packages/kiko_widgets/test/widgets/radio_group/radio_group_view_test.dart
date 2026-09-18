import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

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
  group('radio group view', () {
    test('a three-option vertical group dumps three rows; the chosen row shows (*)', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
          RadioOption(value: 3, label: Line('Three')),
        ],
        value: 2,
      );
      final frame = _frame(12, 3)..render(RadioGroup(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '( ) One\n(*) Two\n( ) Three\n');
      expect(frame.hits.rectOf('r'), Rect.create(x: 0, y: 0, width: 12, height: 3));
    });

    test('regionAt answers RowRegion per row, spare cells included, and null below the group', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
          RadioOption(value: 3, label: Line('Three')),
        ],
        value: 2,
      );
      // A plain outer Column, in a frame taller than the group, so there is
      // a row below it that carries no region.
      final frame = _frame(12, 5)
        ..render(
          Column(
            children: [RadioGroup(model: model, theme: Theme.dark)],
          ),
        );
      expect(frame.hits.regionAt('r', 0, 0), const RowRegion(0)); // box cell
      expect(frame.hits.regionAt('r', 4, 0), const RowRegion(0)); // label cell
      expect(frame.hits.regionAt('r', 10, 0), const RowRegion(0)); // spare cell past the label
      expect(frame.hits.regionAt('r', 0, 1), const RowRegion(1));
      expect(frame.hits.regionAt('r', 0, 2), const RowRegion(2));
      expect(frame.hits.regionAt('r', 0, 3), isNull); // below the group
    });

    test('a horizontal group dumps one row, options two cells apart', () {
      final model = RadioGroupModel<String>(
        id: 'r',
        options: [
          RadioOption(value: 'a', label: Line('A')),
          RadioOption(value: 'b', label: Line('B')),
          RadioOption(value: 'c', label: Line('C')),
        ],
        direction: Axis.horizontal,
      );
      final frame = _frame(19, 1)..render(RadioGroup(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '( ) A  ( ) B  ( ) C\n');
      expect(frame.hits.regionAt('r', 5, 0), isNull); // the gap between rows
    });
  });

  group('radio group view sizing', () {
    test('a vertical group inside a Column hugs its own height', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
          RadioOption(value: 3, label: Line('Three')),
        ],
        value: 2,
      );
      final frame = _frame(12, 5)
        ..render(
          Column(
            children: [RadioGroup(model: model, theme: Theme.dark)],
          ),
        );
      expect(frame.hits.rectOf('r'), Rect.create(x: 0, y: 0, width: 12, height: 3));
      expect(frame.buffer[(x: 0, y: 3)].symbol, ' ');
      expect(frame.buffer[(x: 0, y: 4)].symbol, ' ');
    });

    test('a horizontal group inside a Row hugs its own width', () {
      final model = RadioGroupModel<String>(
        id: 'r',
        options: [
          RadioOption(value: 'a', label: Line('A')),
          RadioOption(value: 'b', label: Line('B')),
          RadioOption(value: 'c', label: Line('C')),
        ],
        direction: Axis.horizontal,
      );
      final frame = _frame(30, 1)
        ..render(
          Row(
            children: [RadioGroup(model: model, theme: Theme.dark)],
          ),
        );
      expect(frame.hits.rectOf('r'), Rect.create(x: 0, y: 0, width: 19, height: 1));
      expect(frame.buffer[(x: 19, y: 0)].symbol, ' ');
    });
  });

  group('radio group view layout', () {
    RadioGroup<int> combo({required bool labelFirst, required TextAlign labelAlign}) => RadioGroup(
      model: RadioGroupModel<int>(
        id: 'r',
        options: [RadioOption(value: 1, label: Line('Option 1'))],
        labelFirst: labelFirst,
        labelAlign: labelAlign,
      ),
      theme: Theme.dark,
    );

    test('box first, label start: spare width trails the label', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: false, labelAlign: TextAlign.start));
      expect(_dump(frame.buffer), '( ) Option 1\n');
    });

    test('box first, label end: spare width sits between box and label', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: false, labelAlign: TextAlign.end));
      expect(_dump(frame.buffer), '( )${' ' * 15}Option 1\n');
    });

    test('label first, label start: spare width sits between label and box', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: true, labelAlign: TextAlign.start));
      expect(_dump(frame.buffer), 'Option 1${' ' * 15}( )\n');
    });

    test('label first, label end: spare width leads the label', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: true, labelAlign: TextAlign.end));
      expect(_dump(frame.buffer), '${' ' * 14}Option 1 ( )\n');
    });

    test('a horizontal group ignores labelAlign', () {
      RadioGroup<int> horiz(TextAlign labelAlign) => RadioGroup(
        model: RadioGroupModel<int>(
          id: 'r',
          options: [RadioOption(value: 1, label: Line('Option 1'))],
          direction: Axis.horizontal,
          labelAlign: labelAlign,
        ),
        theme: Theme.dark,
      );
      final start = _frame(26, 1)..render(horiz(TextAlign.start));
      final end = _frame(26, 1)..render(horiz(TextAlign.end));
      expect(_dump(end.buffer), _dump(start.buffer));
    });
  });

  group('radio group view glyphs', () {
    test('dot preset dumps its glyphs', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
        value: 2,
        glyphs: CheckGlyphs.dot,
      );
      final frame = _frame(10, 2)..render(RadioGroup(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '( ) One\n(•) Two\n');
    });

    test('circle preset dumps its glyphs, with no brackets', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
        value: 2,
        glyphs: CheckGlyphs.circle,
      );
      final frame = _frame(10, 2)..render(RadioGroup(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '◌ One\n◉ Two\n');
    });

    test('orb preset dumps a two-cell mark; the label starts after it and the gap', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [RadioOption(value: 1, label: Line('One'))],
        glyphs: CheckGlyphs.orb,
      );
      final frame = _frame(10, 1)..render(RadioGroup(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '⚪ One\n');
      expect(frame.buffer[(x: 0, y: 0)].symbol, '⚪');
      expect(frame.buffer[(x: 1, y: 0)].skip, isTrue); // the orb's second cell
      expect(frame.buffer[(x: 2, y: 0)].symbol, ' '); // the one-cell gap
      expect(frame.buffer[(x: 3, y: 0)].symbol, 'O'); // the label starts here
    });

    test('a value matching no option paints every row unchosen', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
        value: 99,
      );
      final frame = _frame(10, 2)..render(RadioGroup(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '( ) One\n( ) Two\n');
    });
  });

  group('radio group view styles', () {
    test('the cursor row carries focus ink and bold on its brackets and mark; another row does not', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
        value: 1,
        focused: true,
      );
      final frame = _frame(10, 2)..render(RadioGroup(model: model, theme: Theme.dark));

      final cursorOpen = frame.buffer[(x: 0, y: 0)];
      expect(cursorOpen.fg, Theme.dark.focus.color);
      expect(cursorOpen.modifier.has(Modifier.bold), isTrue);
      final cursorMark = frame.buffer[(x: 1, y: 0)];
      expect(cursorMark.fg, Theme.dark.focus.color);
      expect(cursorMark.modifier.has(Modifier.bold), isTrue);

      final otherOpen = frame.buffer[(x: 0, y: 1)];
      expect(otherOpen.fg, Theme.dark.border.color);
      expect(otherOpen.modifier.has(Modifier.bold), isFalse);
    });

    test("error puts error ink on every row's brackets, and keeps the cursor row's focus bold", () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
        value: 1,
        focused: true,
        error: true,
      );
      final frame = _frame(10, 2)..render(RadioGroup(model: model, theme: Theme.dark));

      final cursorOpen = frame.buffer[(x: 0, y: 0)];
      expect(cursorOpen.fg, Theme.dark.error.color);
      expect(cursorOpen.modifier.has(Modifier.bold), isTrue);

      final otherOpen = frame.buffer[(x: 0, y: 1)];
      expect(otherOpen.fg, Theme.dark.error.color);
      expect(otherOpen.modifier.has(Modifier.bold), isFalse);
    });

    test('a disabled option dims every cell of its row only', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One'), disabled: true),
          RadioOption(value: 2, label: Line('Two')),
        ],
      );
      final frame = _frame(10, 2)..render(RadioGroup(model: model, theme: Theme.dark));

      for (final x in [0, 1, 2, 4]) {
        final cell = frame.buffer[(x: x, y: 0)];
        expect(cell.fg, Theme.dark.disabled.color, reason: 'cell at x=$x, y=0');
        expect(cell.modifier.has(Modifier.dim), isTrue, reason: 'cell at x=$x, y=0');
      }
      for (final x in [0, 1, 2, 4]) {
        final cell = frame.buffer[(x: x, y: 1)];
        expect(cell.modifier.has(Modifier.dim), isFalse, reason: 'cell at x=$x, y=1');
      }
    });

    test('a disabled group dims every row', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
        disabled: true,
      );
      final frame = _frame(10, 2)..render(RadioGroup(model: model, theme: Theme.dark));

      for (final y in [0, 1]) {
        for (final x in [0, 1, 2, 4]) {
          final cell = frame.buffer[(x: x, y: y)];
          expect(cell.modifier.has(Modifier.dim), isTrue, reason: 'cell at x=$x, y=$y');
        }
      }
    });

    test('hoveredIndex washes that row, spare cells included, and no other row', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
      )..hoveredIndex = 0;
      final frame = _frame(12, 2)..render(RadioGroup(model: model, theme: Theme.dark));

      final bracket = frame.buffer[(x: 0, y: 0)];
      final spare = frame.buffer[(x: 11, y: 0)]; // past "( ) One", still inside the row
      expect(bracket.bg, Theme.dark.hover.color);
      expect(spare.bg, Theme.dark.hover.color);

      final otherBracket = frame.buffer[(x: 0, y: 1)];
      expect(otherBracket.bg, isNot(Theme.dark.hover.color));
    });

    test("pressedIndex inverts that row's box, not its label", () {
      final restingModel = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
      );
      final restingFrame = _frame(10, 2)..render(RadioGroup(model: restingModel, theme: Theme.dark));

      final pressedModel = RadioGroupModel<int>(
        id: 'r',
        options: [
          RadioOption(value: 1, label: Line('One')),
          RadioOption(value: 2, label: Line('Two')),
        ],
      )..pressedIndex = 0;
      final pressedFrame = _frame(10, 2)..render(RadioGroup(model: pressedModel, theme: Theme.dark));

      final bracket = pressedFrame.buffer[(x: 0, y: 0)];
      expect(bracket.bg, Theme.dark.border.color);

      final restingLabel = restingFrame.buffer[(x: 4, y: 0)];
      final pressedLabel = pressedFrame.buffer[(x: 4, y: 0)];
      expect(pressedLabel.bg, restingLabel.bg);

      final otherBracket = pressedFrame.buffer[(x: 0, y: 1)];
      expect(otherBracket.bg, isNot(Theme.dark.border.color));
    });

    test('a style.open slot wins verbatim', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [RadioOption(value: 1, label: Line('One'))],
      );
      final frame = _frame(10, 1)
        ..render(
          RadioGroup(
            model: model,
            theme: Theme.dark,
            style: const RadioStyle(open: Style(fg: Color.magenta)),
          ),
        );
      expect(frame.buffer[(x: 0, y: 0)].fg, Color.magenta);
    });

    test('an app-set style.checkedMark keeps its fg on the chosen row', () {
      final model = RadioGroupModel<int>(
        id: 'r',
        options: [RadioOption(value: 1, label: Line('One'))],
        value: 1,
      );
      final frame = _frame(10, 1)
        ..render(
          RadioGroup(
            model: model,
            theme: Theme.dark,
            style: const RadioStyle(checkedMark: Style(fg: Color.cyan)),
          ),
        );
      expect(frame.buffer[(x: 1, y: 0)].fg, Color.cyan);
    });
  });
}
