import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// A one-line text node built from a single run, for readable label goldens.
Text<String> _label(String text, String token) => Text<String>(<TextRun<String>>[TextRun<String>(text, token)]);

List<String> _paint(RenderNode<String> node) {
  final surface = RecordingSurface<String>();
  node.paint(surface);
  return surface.intents.map((intent) => '$intent').toList();
}

void main() {
  group('BorderBox layout', () {
    test('insets the child by border and padding, and grows to include them', () {
      final box =
          BorderBox<String>(
              border: 'brd',
              background: 'bg',
              padding: const EdgeInsets.all(1),
              child: SizedBox<String>(width: 2, height: 1),
            )
            ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
            ..place(Offset.zero);

      expect(box.size, const Size(6, 5));
      expect(box.child.rect, const Rect(2, 2, 2, 1));
    });

    test('reserves the top row for a title even without a border', () {
      final box =
          BorderBox<String>(
              labels: <EdgeLabel<String>>[EdgeLabel<String>(child: _label('Hi', 'h'))],
              child: SizedBox<String>(width: 4, height: 2),
            )
            ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
            ..place(Offset.zero);

      // No border, but the top title still pushes the child down one row.
      expect(box.size, const Size(4, 3));
      expect(box.child.rect, const Rect(0, 1, 4, 2));
    });
  });

  group('BorderBox labels', () {
    test('centers a top title between the corners', () {
      final label = _label('Title', 'ttl');
      final box =
          BorderBox<String>(
              border: 'brd',
              labels: <EdgeLabel<String>>[EdgeLabel<String>(child: label, align: LabelAlign.center)],
              child: SizedBox<String>(width: 6, height: 1),
            )
            ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
            ..place(Offset.zero);

      expect(box.size, const Size(8, 3));
      expect(label.rect, const Rect(1, 0, 5, 1));
      expect(_paint(box), <String>[
        'drawBorder(Rect(0, 0, 8, 3), brd)',
        'drawText(1, 0, "Title", ttl)',
      ]);
    });

    test('packs several left titles with a one-cell gap', () {
      final first = _label('AB', 'a');
      final second = _label('CD', 'c');
      final box =
          BorderBox<String>(
              border: 'brd',
              labels: <EdgeLabel<String>>[
                EdgeLabel<String>(child: first),
                EdgeLabel<String>(child: second),
              ],
              child: SizedBox<String>(width: 10, height: 1),
            )
            ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
            ..place(Offset.zero);

      expect(box.size, const Size(12, 3));
      expect(first.rect, const Rect(1, 0, 2, 1));
      expect(second.rect, const Rect(4, 0, 2, 1));
    });

    test('anchors an end-aligned bottom title to the right corner', () {
      final label = _label('R', 'r');
      final box =
          BorderBox<String>(
              border: 'brd',
              labels: <EdgeLabel<String>>[
                EdgeLabel<String>(child: label, side: EdgeSide.bottom, align: LabelAlign.end),
              ],
              child: SizedBox<String>(width: 6, height: 1),
            )
            ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
            ..place(Offset.zero);

      expect(box.size, const Size(8, 3));
      expect(label.rect, const Rect(6, 2, 1, 1));
      expect(_paint(box), <String>[
        'drawBorder(Rect(0, 0, 8, 3), brd)',
        'drawText(6, 2, "R", r)',
      ]);
    });
  });

  group('BorderBox paint order', () {
    test('fills, then strokes the border, then paints labels over it', () {
      final box =
          BorderBox<String>(
              background: 'bg',
              border: 'brd',
              labels: <EdgeLabel<String>>[EdgeLabel<String>(child: _label('T', 'ttl'))],
              child: SizedBox<String>(width: 4, height: 1),
            )
            ..layout(BoxConstraints.loose(const Size(20, 20)), _ctx)
            ..place(Offset.zero);

      expect(_paint(box), <String>[
        'fillRect(Rect(0, 0, 6, 3), bg)',
        'drawBorder(Rect(0, 0, 6, 3), brd)',
        'drawText(1, 0, "T", ttl)',
      ]);
    });
  });
}
