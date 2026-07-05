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
      expect(frame.rectOf('ok'), Rect.create(x: 0, y: 0, width: 4, height: 1));
    });

    test('keeps the label width while loading, indicator at the start', () {
      final model = ButtonModel(id: 'go', label: Line('HELLO'), loadingText: Line('.'), loading: true);
      final frame = _frame(7, 1)..render(Button(model: model, theme: Theme.dark));
      // width stays label+padding (7); "." sits at the start of the 5-cell content band.
      expect(_dump(frame.buffer), ' .\n');
      expect(frame.rectOf('go'), Rect.create(x: 0, y: 0, width: 7, height: 1));
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
      expect(frame.hitId(0, 0), 'ok'); // left padding cell
      expect(frame.hitId(1, 0), 'ok'); // the label
      expect(frame.hitId(3, 0), 'ok'); // right padding cell
      expect(frame.hitId(4, 0), isNull); // off the button
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
      final frame = _frame(6, 1)..render(Row(children: <View>[a, b]));

      expect(frame.hitId(1, 0), 'a');
      expect(frame.hitId(4, 0), 'b');
      expect(frame.rectOf('a'), Rect.create(x: 0, y: 0, width: 3, height: 1));
      expect(frame.rectOf('b'), Rect.create(x: 3, y: 0, width: 3, height: 1));
    });
  });
}
