import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

Buffer _buf(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

/// The cell a fresh buffer ends up with after painting one styled space.
Cell _fillCell(Style style) => Cell.empty().setCell(char: ' ', style: style);

/// A leaf that fills its box and, when painted, claims the terminal cursor at
/// [position] if the active clip still contains it.
///
/// A [Node] and its own [View] at once — the same shape a self-painting
/// widget such as `TextInput` builds, minimal down to just the cursor claim.
class _CursorClaim extends Node implements View {
  _CursorClaim(this.position);

  /// Where this leaf claims the cursor.
  final Position position;

  @override
  Node build() => this;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.biggest;

  @override
  void paintSelf(Surface surface) {
    if (surface is BufferSurface) surface.placeCursor(position);
  }
}

void main() {
  group('Frame.renderLayer / clean slate', () {
    for (final policy in RenderPolicy.values) {
      test('replaces the base rect cleanly rather than blending with it ($policy)', () {
        final b = _buf(8, 4);
        final frame = Frame(b.area, b, 0);
        final resolver = StyleResolver(Theme.dark, policy: policy);

        // A styled base: a colored (or reversed, under noColor) fill plus a
        // bold span, covering the whole frame.
        final baseStyle = resolver.fill(Theme.dark.selection).incModifier(Modifier.bold);
        frame.render(Container(width: 8, height: 4, ground: baseStyle, child: Line('B')));

        // A layer that paints only an fg-only (or, under noColor, entirely
        // bare) glyph in the corner of its rect and nothing else.
        final layerRect = Rect.create(x: 2, y: 1, width: 3, height: 2);
        final layerStyle = resolver.ink(Theme.dark.error);
        frame.renderLayer(Container(width: 3, height: 2, child: Line('Q', style: layerStyle)), layerRect);

        expect(
          b[(x: 2, y: 1)],
          Cell.empty().setCell(char: 'Q', style: layerStyle),
          reason: 'a cell the layer painted shows only layer content',
        );

        for (final (x, y) in const [(3, 1), (4, 1), (2, 2), (3, 2), (4, 2)]) {
          expect(
            b[(x: x, y: y)],
            Cell.empty(),
            reason: '($x,$y) is inside the rect but the layer never painted it — no base ghosting',
          );
        }

        expect(b[(x: 7, y: 0)], _fillCell(baseStyle), reason: 'outside the rect, the base is untouched');
        expect(b[(x: 0, y: 3)], _fillCell(baseStyle), reason: 'outside the rect, the base is untouched');
      });
    }
  });

  group('Frame.renderLayer / hit regions', () {
    test('a layer tag wins over an overlapping base tag; a base tag outside the rect still resolves', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(
          Row(
            children: [
              Expanded(
                child: Tagged('base-left', Container(border: BorderType.plain, child: Line(''))),
              ),
              Expanded(
                child: Tagged('base-right', Container(border: BorderType.plain, child: Line(''))),
              ),
            ],
          ),
        );

      final layerRect = Rect.create(x: 0, y: 0, width: 4, height: 4);
      frame.renderLayer(Tagged('layer', Container(width: 4, height: 4, child: Line(''))), layerRect);

      expect(frame.hits.hitId(1, 1), 'layer', reason: 'the layer sits on top of base-left');
      expect(frame.hits.hitId(6, 1), 'base-right', reason: 'outside the rect, the base tag still resolves');
    });
  });

  group('Frame.renderLayer / cursor claims', () {
    test('a claimless layer drops a standing claim that falls inside its rect', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)..render(NodeView(_CursorClaim(const Position(3, 2))));
      expect(frame.cursorPosition, const Position(3, 2));

      frame.renderLayer(
        Container(width: 4, height: 3, child: Line('')),
        Rect.create(x: 2, y: 1, width: 4, height: 3),
      );

      expect(frame.cursorPosition, isNull);
    });

    test('a standing claim outside the rect survives a layer render', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)..render(NodeView(_CursorClaim(Position.origin)));
      expect(frame.cursorPosition, Position.origin);

      frame.renderLayer(
        Container(width: 4, height: 3, child: Line('')),
        Rect.create(x: 2, y: 1, width: 4, height: 3),
      );

      expect(frame.cursorPosition, Position.origin);
    });

    test("a layer's own claim wins over a standing claim inside its rect", () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)..render(NodeView(_CursorClaim(const Position(3, 1))));
      expect(frame.cursorPosition, const Position(3, 1));

      frame.renderLayer(NodeView(_CursorClaim(const Position(5, 2))), Rect.create(x: 2, y: 1, width: 4, height: 3));

      expect(frame.cursorPosition, const Position(5, 2));
    });
  });

  group('Frame.renderLayer / clipping', () {
    test('a rect that runs outside the frame area renders without error and clips', () {
      final b = _buf(6, 4);
      final frame = Frame(b.area, b, 0);
      final rect = Rect.create(x: 4, y: 2, width: 5, height: 5);

      expect(
        () => frame.renderLayer(
          Container(
            width: 5,
            height: 5,
            ground: const Style(bg: Color.blue),
            child: Line(''),
          ),
          rect,
        ),
        returnsNormally,
      );

      expect(b[(x: 5, y: 3)].bg, Color.blue, reason: 'inside both the rect and the frame area');
    });
  });
}
