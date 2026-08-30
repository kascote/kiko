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
  group('checkbox view', () {
    test('unchecked dumps the box, the gap, and the label', () {
      final frame = _frame(12, 1)
        ..render(
          Checkbox(
            model: CheckboxModel(id: 'c', label: Line('Option')),
            theme: Theme.dark,
          ),
        );
      expect(_dump(frame.buffer), '[ ] Option\n');
      // Rendered straight into the frame, the row fills it — the full row,
      // not just the content, is what the hit map answers for.
      expect(frame.hits.rectOf('c'), Rect.create(x: 0, y: 0, width: 12, height: 1));
    });

    test('checked dumps the checked glyph', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), state: CheckState.checked);
      final frame = _frame(12, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '[x] Option\n');
      expect(frame.hits.rectOf('c'), Rect.create(x: 0, y: 0, width: 12, height: 1));
    });
  });

  group('checkbox view sizing', () {
    test('hugs its content under a loose width', () {
      // A Row gives an inflexible child an unbounded main axis, so the
      // checkbox measures to its own content instead of filling the frame.
      final frame = _frame(40, 1)
        ..render(
          Row(
            children: [
              Checkbox(
                model: CheckboxModel(id: 'c', label: Line('Option')),
                theme: Theme.dark,
              ),
            ],
          ),
        );
      expect(frame.hits.rectOf('c'), Rect.create(x: 0, y: 0, width: 10, height: 1));
    });
  });

  group('checkbox view layout', () {
    Checkbox combo({required bool labelFirst, required TextAlign labelAlign}) => Checkbox(
      model: CheckboxModel(id: 'c', label: Line('Option 1'), labelFirst: labelFirst, labelAlign: labelAlign),
      theme: Theme.dark,
    );

    // Row width 26, box+gap 4 cells, label "Option 1" 8 cells: 14 spare
    // cells. Box first puts its own trailing gap cell before the spare run,
    // label first puts the box's own leading gap cell after it — one more
    // cell of spacing than the bare spare count on the side next to the box.
    test('box first, label start: spare width trails the label', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: false, labelAlign: TextAlign.start));
      expect(_dump(frame.buffer), '[ ] Option 1\n');
    });

    test('box first, label end: spare width sits between box and label', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: false, labelAlign: TextAlign.end));
      expect(_dump(frame.buffer), '[ ]${' ' * 15}Option 1\n');
    });

    test('label first, label start: spare width sits between label and box', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: true, labelAlign: TextAlign.start));
      expect(_dump(frame.buffer), 'Option 1${' ' * 15}[ ]\n');
    });

    test('label first, label end: spare width leads the label', () {
      final frame = _frame(26, 1)..render(combo(labelFirst: true, labelAlign: TextAlign.end));
      expect(_dump(frame.buffer), '${' ' * 14}Option 1 [ ]\n');
    });

    test('a stretched column gives every row the same width', () {
      final rows = [
        CheckboxModel(id: 'a', label: Line('A')),
        CheckboxModel(id: 'b', label: Line('A longer label')),
        CheckboxModel(id: 'c', label: Line('Mid')),
      ];
      final frame = _frame(30, 3)
        ..render(
          Column(
            crossAxis: CrossAxisAlignment.stretch,
            children: [for (final m in rows) Checkbox(model: m, theme: Theme.dark)],
          ),
        );
      expect(frame.hits.rectOf('a'), Rect.create(x: 0, y: 0, width: 30, height: 1));
      expect(frame.hits.rectOf('b'), Rect.create(x: 0, y: 1, width: 30, height: 1));
      expect(frame.hits.rectOf('c'), Rect.create(x: 0, y: 2, width: 30, height: 1));
    });
  });

  group('checkbox view glyphs', () {
    test('mixed paints glyphs.mixed', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), state: CheckState.mixed);
      final frame = _frame(12, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '[-] Option\n');
    });

    test('ballot paints one cell with no brackets', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), glyphs: CheckGlyphs.ballot);
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '☐ Option\n');
    });

    test('emoji paints a two-cell mark and the label starts after it', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), glyphs: CheckGlyphs.emoji, state: CheckState.checked);
      final frame = _frame(12, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '✅ Option\n');
      expect(frame.buffer[(x: 0, y: 0)].symbol, '✅');
      expect(frame.buffer[(x: 1, y: 0)].skip, isTrue); // the emoji's second cell
      expect(frame.buffer[(x: 2, y: 0)].symbol, ' '); // the one-cell gap
      expect(frame.buffer[(x: 3, y: 0)].symbol, 'O'); // the label starts here
    });

    test('a custom glyph set pads the unchecked box so the label does not move', () {
      const glyphs = CheckGlyphs(checked: '✅');
      final unchecked = CheckboxModel(id: 'c', label: Line('Option'), glyphs: glyphs);
      final checked = CheckboxModel(id: 'c', label: Line('Option'), glyphs: glyphs, state: CheckState.checked);
      final f1 = _frame(12, 1)..render(Checkbox(model: unchecked, theme: Theme.dark));
      final f2 = _frame(12, 1)..render(Checkbox(model: checked, theme: Theme.dark));
      expect(f1.buffer[(x: 5, y: 0)].symbol, 'O');
      expect(f2.buffer[(x: 5, y: 0)].symbol, 'O');
    });
  });

  group('checkbox view clipping', () {
    test('box first: the row clips the label at the right edge', () {
      final model = CheckboxModel(id: 'c', label: Line('Option 1'));
      final frame = _frame(6, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '[ ] Op\n'); // the box paints whole, the label is cut
    });

    test('label first: the row clips the box at the right edge', () {
      final model = CheckboxModel(id: 'c', label: Line('Option 1'), labelFirst: true);
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), 'Option 1 [\n'); // the label paints whole, the box is cut
    });
  });

  group('checkbox view styles', () {
    test('the checked mark carries the selection ink', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), state: CheckState.checked);
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(frame.buffer[(x: 1, y: 0)].fg, Theme.dark.selection.color);
    });

    test('brackets carry the border ink at rest', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'));
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(frame.buffer[(x: 0, y: 0)].fg, Theme.dark.border.color);
      expect(frame.buffer[(x: 2, y: 0)].fg, Theme.dark.border.color);
    });

    test('brackets carry the focus ink and bold when focused', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), focused: true);
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      final cell = frame.buffer[(x: 0, y: 0)];
      expect(cell.fg, Theme.dark.focus.color);
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('error puts the error ink on the brackets only', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), error: true);
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(frame.buffer[(x: 0, y: 0)].fg, Theme.dark.error.color);
      expect(frame.buffer[(x: 2, y: 0)].fg, Theme.dark.error.color);
      expect(frame.buffer[(x: 1, y: 0)].fg, Color.reset); // the mark keeps its own style
      expect(frame.buffer[(x: 4, y: 0)].fg, Color.reset); // the label keeps its own style
    });

    test('disabled dims every cell', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), disabled: true);
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      for (final x in [0, 1, 2, 4]) {
        final cell = frame.buffer[(x: x, y: 0)];
        expect(cell.fg, Theme.dark.disabled.color, reason: 'cell at x=$x');
        expect(cell.modifier.has(Modifier.dim), isTrue, reason: 'cell at x=$x');
      }
    });

    test('hover washes the whole row, spare cells included, and leaves fgs intact', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'))..hovered = true;
      final frame = _frame(12, 1)..render(Checkbox(model: model, theme: Theme.dark));
      final bracket = frame.buffer[(x: 0, y: 0)];
      final spare = frame.buffer[(x: 11, y: 0)]; // past "[ ] Option", still inside the row
      expect(bracket.bg, Theme.dark.hover.color);
      expect(bracket.fg, Theme.dark.border.color); // the wash never touches fg
      expect(spare.bg, Theme.dark.hover.color);
    });

    test('a styleOverrides entry for selected replaces the checked mark style', () {
      final model = CheckboxModel(id: 'c', label: Line('Option'), state: CheckState.checked);
      final frame = _frame(10, 1)
        ..render(
          Checkbox(
            model: model,
            theme: Theme.dark,
            styleOverrides: const {WidgetState.selected: Style(fg: Color.yellow)},
          ),
        );
      expect(frame.buffer[(x: 1, y: 0)].fg, Color.yellow);
    });

    test('a styles.open slot wins verbatim at rest', () {
      final model = CheckboxModel(
        id: 'c',
        label: Line('Option'),
        styles: const CheckboxStyle(open: Style(fg: Color.magenta)),
      );
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      expect(frame.buffer[(x: 0, y: 0)].fg, Color.magenta);
    });

    test('an app-set styles.checkedMark keeps its fg when checked', () {
      final model = CheckboxModel(
        id: 'c',
        label: Line('Option'),
        state: CheckState.checked,
        styles: const CheckboxStyle(checkedMark: Style(fg: Color.cyan)),
      );
      final frame = _frame(10, 1)..render(Checkbox(model: model, theme: Theme.dark));
      // The selected state would otherwise overwrite an app-set checkedMark
      // color, so this pins that the explicit slot is the base, not a patch
      // target.
      expect(frame.buffer[(x: 1, y: 0)].fg, Color.cyan);
    });
  });
}
