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
  group('modalDialog', () {
    test('tags the dialog with the given id', () {
      final dialog = modalDialog(id: 'confirm', content: Line('Sure?').build(), theme: Theme.dark);
      final frame = _frame(10, 3)..render(NodeView(dialog));
      expect(frame.hits.rectOf('confirm'), isNotNull);
    });
  });

  group('centeredOverlay', () {
    test('centres a fixed-size dialog within the viewport', () {
      final dialog = modalDialog(id: 'confirm', content: Line('Hi').build(), theme: Theme.dark);
      final overlay = centeredOverlay(
        dialog: dialog,
        area: Rect.create(x: 0, y: 0, width: 20, height: 10),
        width: 6,
        height: 4,
      );
      final frame = _frame(20, 10)..render(NodeView(overlay));
      expect(frame.hits.rectOf('confirm'), Rect.create(x: 7, y: 3, width: 6, height: 4));
    });
  });

  group('renderModalOverlay', () {
    test('paints only the base when there is no dialog', () {
      final base = Line('base').build();
      final frame = _frame(10, 3);
      renderModalOverlay(frame, base: base, width: 4, height: 1);
      expect(_dump(frame.buffer), contains('base'));
    });

    test('dims the backdrop then paints the dialog on top', () {
      final base = const Container(
        background: Style(bg: Color.rgb(0xC8C8C8)),
        child: SizedBox(width: 10, height: 3),
      ).build();
      final dialog = modalDialog(id: 'confirm', content: Line('Sure?').build(), theme: Theme.dark);
      final frame = _frame(10, 3);
      renderModalOverlay(frame, base: base, width: 8, height: 3, dialog: dialog);

      expect(frame.hits.rectOf('confirm'), isNotNull);
      // The backdrop's colour was dimmed before the dialog painted over it —
      // a corner cell just outside the dialog should no longer be full-bright.
      final corner = frame.buffer[(x: 0, y: 0)];
      expect(corner.bg, isNot(equals(const Color.rgb(0xC8C8C8))));
    });
  });
}
