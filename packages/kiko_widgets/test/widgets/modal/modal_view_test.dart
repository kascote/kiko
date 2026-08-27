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

  group('centeredRect', () {
    test('centres a fixed size within an origin-zero area', () {
      final rect = centeredRect(area: Rect.create(x: 0, y: 0, width: 20, height: 10), width: 6, height: 4);
      expect(rect, Rect.create(x: 7, y: 3, width: 6, height: 4));
    });

    test('offsets by the area origin, so the result is frame-absolute', () {
      final rect = centeredRect(area: Rect.create(x: 2, y: 5, width: 20, height: 10), width: 6, height: 4);
      expect(rect, Rect.create(x: 9, y: 8, width: 6, height: 4));
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
        ground: Style(bg: Color.rgb(0xC8C8C8)),
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

  group('renderModalOverlay / layer compositing', () {
    const width = 20;
    const height = 8;
    const dialogWidth = 10;
    const dialogHeight = 4;

    Node buildDialog() => modalDialog(id: 'confirm', content: Line('Sure?').build(), theme: Theme.dark);

    for (final policy in RenderPolicy.values) {
      test('the dialog replaces the base rect cleanly, never blended with it ($policy)', () {
        StyleResolver.defaultPolicy = policy;
        addTearDown(() => StyleResolver.defaultPolicy = RenderPolicy.color);
        final resolver = StyleResolver(Theme.dark, policy: policy);

        // A styled base: a colored (or reversed, under noColor) fill plus a
        // bold, reversed span, covering the whole frame under the dialog rect.
        final baseFill = resolver.fill(Theme.dark.selection);
        final spanStyle = resolver.ink(Theme.dark.error).incModifier(Modifier.bold | Modifier.reversed);
        Node buildBase() => Container(
          width: width,
          height: height,
          ground: baseFill,
          child: Column(children: [for (var i = 0; i < height; i++) Line('B' * width, style: spanStyle)]),
        ).build();

        final frame = _frame(width, height);
        renderModalOverlay(frame, base: buildBase(), width: dialogWidth, height: dialogHeight, dialog: buildDialog());

        final rect = centeredRect(area: frame.area, width: dialogWidth, height: dialogHeight);

        // Render the same dialog alone into a buffer matching just the rect,
        // so we know exactly what a clean composite looks like.
        final isolated = Buffer.empty(rect);
        Frame(isolated.area, isolated, 0).render(NodeView(buildDialog()));

        for (var y = rect.top; y < rect.bottom; y++) {
          for (var x = rect.left; x < rect.right; x++) {
            final composited = frame.buffer[(x: x, y: y)];
            final alone = isolated[(x: x, y: y)];
            expect(
              composited,
              anyOf(equals(alone), equals(Cell.empty())),
              reason:
                  '($x,$y) inside the dialog rect must be dialog content or empty — never base '
                  'glyphs, backgrounds, or modifiers showing through',
            );
          }
        }
      });
    }

    test('the dim reaches only cells painted before the layer, never the dialog', () {
      final base = const Container(
        ground: Style(bg: Color.rgb(0xC8C8C8)),
        child: SizedBox(width: width, height: height),
      ).build();

      final frame = _frame(width, height);
      renderModalOverlay(frame, base: base, width: dialogWidth, height: dialogHeight, dialog: buildDialog());

      final rect = centeredRect(area: frame.area, width: dialogWidth, height: dialogHeight);

      // Outside the rect, the base is dimmed.
      expect(frame.buffer[(x: 0, y: 0)].bg, isNot(equals(const Color.rgb(0xC8C8C8))));

      // Inside the rect, the dialog matches an undimmed, standalone render —
      // if the dim had reached the layer, colors here would differ.
      final isolated = Buffer.empty(rect);
      Frame(isolated.area, isolated, 0).render(NodeView(buildDialog()));
      for (var y = rect.top; y < rect.bottom; y++) {
        for (var x = rect.left; x < rect.right; x++) {
          expect(
            frame.buffer[(x: x, y: y)],
            isolated[(x: x, y: y)],
            reason: 'dialog cell ($x,$y) must match an undimmed render — the dim never reaches the layer',
          );
        }
      }
    });
  });
}
