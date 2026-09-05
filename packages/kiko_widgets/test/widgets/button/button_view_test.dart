import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

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
  group('button view', () {
    test('renders the label inside horizontal padding', () {
      final frame = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK')),
            theme: Theme.dark,
          ),
        );
      // one pad cell, "OK", one pad cell (the trailing pad trims away).
      expect(_dump(frame.buffer), ' OK\n');
      expect(frame.hits.rectOf('ok'), Rect.create(x: 0, y: 0, width: 4, height: 1));
    });

    test('keeps the label width while loading, indicator at the start', () {
      final model = ButtonModel(id: 'go', label: Line('HELLO'), loadingText: Line('.'), loading: true);
      final frame = _frame(7, 1)..render(Button(model: model, theme: Theme.dark));
      // width stays label+padding (7); "." sits at the start of the 5-cell content band.
      expect(_dump(frame.buffer), ' .\n');
      expect(frame.hits.rectOf('go'), Rect.create(x: 0, y: 0, width: 7, height: 1));
    });
  });

  group('button view pressed', () {
    test('a pressed button inverts its resting face', () {
      // The press runs through WidgetState.pressed in the resolver, so the
      // label cell's fg/bg swap versus resting.
      final resting = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK')),
            theme: Theme.dark,
          ),
        );
      final pressed = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK'))..pressed = true,
            theme: Theme.dark,
          ),
        );

      final rc = resting.buffer[(x: 1, y: 0)]; // the 'O'
      final pc = pressed.buffer[(x: 1, y: 0)];
      expect(pc.symbol, equals('O'));
      expect(pc.fg, equals(rc.bg));
      expect(pc.bg, equals(rc.fg));
    });
  });

  group('button view hover', () {
    test('a hovered button lifts its face', () {
      final resting = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK')),
            theme: Theme.dark,
          ),
        );
      final hovered = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK'))..hovered = true,
            theme: Theme.dark,
          ),
        );

      final rc = resting.buffer[(x: 1, y: 0)]; // the 'O'
      final hc = hovered.buffer[(x: 1, y: 0)];
      expect(hc.bg, equals(Theme.dark.primary.color!.lift(Theme.hoverLift)));
      expect(hc.fg, equals(rc.fg));
    });
  });

  group('button view style', () {
    test('a given face paints the resting button with that style verbatim', () {
      const face = Style(fg: Color.black, bg: Color.red);
      final frame = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK')),
            theme: Theme.dark,
            style: const ButtonStyle(face: face),
          ),
        );

      final cell = frame.buffer[(x: 1, y: 0)]; // the 'O'
      expect(cell.fg, Color.black);
      expect(cell.bg, Color.red);
    });

    test('a given face yields to the matrix when focused', () {
      const face = Style(fg: Color.black, bg: Color.red);
      final resolver = StyleResolver(Theme.dark);
      final expectedFill = resolver.fill(resolver.tones.focus);
      final frame = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK'), focused: true),
            theme: Theme.dark,
            style: const ButtonStyle(face: face),
          ),
        );

      final cell = frame.buffer[(x: 1, y: 0)]; // the 'O'
      // The focused fill replaces the face's fg/bg outright; the face never
      // shows through while focused.
      expect(cell.fg, expectedFill.fg);
      expect(cell.bg, expectedFill.bg);
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('a theme switch with no change to style repaints the default face from the new theme', () {
      final darkFrame = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK')),
            theme: Theme.dark,
          ),
        );
      final lightFrame = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK')),
            theme: Theme.light,
          ),
        );

      final darkCell = darkFrame.buffer[(x: 1, y: 0)];
      final lightCell = lightFrame.buffer[(x: 1, y: 0)];
      expect(darkCell.bg, Theme.dark.primary.color);
      expect(lightCell.bg, Theme.light.primary.color);
      expect(darkCell.bg, isNot(equals(lightCell.bg)));
    });
  });

  group('button click routing', () {
    test('a click resolves to the button under it, padding included', () {
      final frame = _frame(4, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'ok', label: Line('OK')),
            theme: Theme.dark,
          ),
        );
      expect(frame.hits.hitId(0, 0), 'ok'); // left padding cell
      expect(frame.hits.hitId(1, 0), 'ok'); // the label
      expect(frame.hits.hitId(3, 0), 'ok'); // right padding cell
      expect(frame.hits.hitId(4, 0), isNull); // off the button
    });

    test('a click resolves to the right button among several', () {
      final a = Button(
        model: ButtonModel(id: 'a', label: Line('A')),
        theme: Theme.dark,
      );
      final b = Button(
        model: ButtonModel(id: 'b', label: Line('B')),
        theme: Theme.dark,
      );
      // Each button's content area is the max of its label and its (default)
      // loading text — the hourglass is 2 cells wide, so a 1-cell label still
      // reserves a 2-cell content band: width 4 (1 pad + 2 content + 1 pad).
      final frame = _frame(8, 1)..render(Row(children: <View>[a, b]));

      expect(frame.hits.hitId(1, 0), 'a');
      expect(frame.hits.hitId(5, 0), 'b');
      expect(frame.hits.rectOf('a'), Rect.create(x: 0, y: 0, width: 4, height: 1));
      expect(frame.hits.rectOf('b'), Rect.create(x: 4, y: 0, width: 4, height: 1));
    });

    test('a click still resolves to the button while loading, after the recomposition', () {
      final model = ButtonModel(id: 'go', label: Line('Go'), loadingText: Line('Loading...'), loading: true);
      const measurer = TermUnicodeMeasurer();
      final width = model.width(measurer);
      final frame = _frame(width, 1)..render(Button(model: model, theme: Theme.dark));

      expect(frame.hits.hitId(0, 0), 'go'); // left padding cell
      expect(frame.hits.hitId(width - 1, 0), 'go'); // right padding cell
      expect(frame.hits.rectOf('go'), Rect.create(x: 0, y: 0, width: width, height: 1));
    });
  });

  group('button view / cjk measurer', () {
    // ° is ambiguous width: one cell by default, two under a cjk locale. The
    // label is the longer of the two contents here, so the whole button widens
    // by exactly the one extra cell ° costs, and the label is never truncated.
    test('a label with an ambiguous-width character renders untruncated under both measurers', () {
      final defaultModel = ButtonModel(id: 'b', label: Line('a°b'), loadingText: Line('.'));
      final defaultFrame = _frame(5, 1)..render(Button(model: defaultModel, theme: Theme.dark));
      expect(_dump(defaultFrame.buffer), ' a°b\n');
      expect(defaultFrame.hits.rectOf('b'), Rect.create(x: 0, y: 0, width: 5, height: 1));

      final cjkModel = ButtonModel(id: 'b', label: Line('a°b'), loadingText: Line('.'));
      final cjkFrame = _frame(6, 1, measurer: const TermUnicodeMeasurer(cjk: true))
        ..render(Button(model: cjkModel, theme: Theme.dark));
      expect(_dump(cjkFrame.buffer), ' a°b\n');
      expect(cjkFrame.hits.rectOf('b'), Rect.create(x: 0, y: 0, width: 6, height: 1));
    });
  });

  group('button view / loading width stability', () {
    // The loading text ("Loading...", 10 cells) is longer than the label
    // ("Go", 2 cells), so the content area — and the button's painted width —
    // is pinned to the loading text's width whether or not loading is active.
    test('the painted width is identical whether or not loading is active', () {
      const measurer = TermUnicodeMeasurer();
      final label = Line('Go');
      final loadingText = Line('Loading...');
      final width = ButtonModel(id: 'x', label: label, loadingText: loadingText).width(measurer);
      expect(width, equals(12)); // max(2, 10) + 2*1 padding

      final resting = _frame(width, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'x', label: label, loadingText: loadingText),
            theme: Theme.dark,
          ),
        );
      final busy = _frame(width, 1)
        ..render(
          Button(
            model: ButtonModel(id: 'x', label: label, loadingText: loadingText, loading: true),
            theme: Theme.dark,
          ),
        );

      expect(resting.hits.rectOf('x'), Rect.create(x: 0, y: 0, width: width, height: 1));
      expect(busy.hits.rectOf('x'), Rect.create(x: 0, y: 0, width: width, height: 1));
    });

    test('a loading text longer than the label shows in full, not truncated', () {
      final model = ButtonModel(id: 'x', label: Line('Go'), loadingText: Line('Loading...'), loading: true);
      const measurer = TermUnicodeMeasurer();
      final width = model.width(measurer);
      final frame = _frame(width, 1)..render(Button(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), ' Loading...\n');
    });
  });
}
