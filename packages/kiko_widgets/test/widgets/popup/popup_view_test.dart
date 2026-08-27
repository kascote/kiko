import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// An anchor scoped `combo/field`, placed at the given rect within a
/// viewport-filling stack.
Node _anchor({required int left, required int top, required int width, required int height}) => Stack(
  fit: StackFit.expand,
  children: <View>[
    Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Tagged.scope(
        'combo',
        Container(
          child: Tagged('field', SizedBox(width: width, height: height)),
        ),
      ),
    ),
  ],
).build();

/// A popup body tagged `popup`, sized to whatever box it is placed in.
Node _popup(int height) => const Tagged('popup', SizedBox()).build();

void main() {
  group('renderAnchoredPopup', () {
    test('fits below', () {
      final frame = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 2, width: 6, height: 1)));

      final decision = renderAnchoredPopup(
        frame,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: _popup,
      );

      expect(decision, PopupPlacement(side: PopupSide.below, height: 3, decidedAgainst: frame.area));
      expect(frame.hits.rectOf('popup'), Rect.create(x: 2, y: 3, width: 6, height: 3));
    });

    test('below blocked, fits above', () {
      final frame = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 8, width: 6, height: 1)));

      final decision = renderAnchoredPopup(
        frame,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: _popup,
      );

      expect(decision, PopupPlacement(side: PopupSide.above, height: 3, decidedAgainst: frame.area));
      expect(frame.hits.rectOf('popup'), Rect.create(x: 2, y: 5, width: 6, height: 3));
    });

    test('neither fits, shrunk to the larger side', () {
      final frame = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 4, width: 6, height: 1)));

      // room below = 10 - 5 = 5, room above = 4 - 0 = 4: below has more room.
      final decision = renderAnchoredPopup(
        frame,
        anchorPath: 'combo/field',
        requestedHeight: 8,
        width: 6,
        popupBuilder: _popup,
      );

      expect(decision, PopupPlacement(side: PopupSide.below, height: 5, decidedAgainst: frame.area));
      expect(frame.hits.rectOf('popup'), Rect.create(x: 2, y: 5, width: 6, height: 5));
    });

    test('the decision stays across paints', () {
      final first = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 2, width: 6, height: 1)));
      final decision = renderAnchoredPopup(
        first,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: _popup,
      );
      expect(decision, isNotNull);
      expect(decision!.side, PopupSide.below);

      // A later paint moves the anchor near the bottom, where a fresh
      // decision would go above. The standing decision holds below anyway.
      final second = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 8, width: 6, height: 1)));
      final held = renderAnchoredPopup(
        second,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: _popup,
        decision: decision,
      );

      expect(held, decision);
      expect(second.hits.rectOf('popup'), Rect.create(x: 2, y: 9, width: 6, height: 3));
    });

    test('a viewport-area change re-decides', () {
      final first = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 2, width: 6, height: 1)));
      final decision = renderAnchoredPopup(
        first,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: _popup,
      );
      expect(decision, PopupPlacement(side: PopupSide.below, height: 3, decidedAgainst: first.area));

      // Same anchor position, but a shorter viewport: neither side has room
      // for 3 rows any more (below = 1, above = 2), so it decides again.
      final second = _frame(20, 4)..render(NodeView(_anchor(left: 2, top: 2, width: 6, height: 1)));
      final redecided = renderAnchoredPopup(
        second,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: _popup,
        decision: decision,
      );

      expect(redecided, PopupPlacement(side: PopupSide.above, height: 2, decidedAgainst: second.area));
      expect(second.hits.rectOf('popup'), Rect.create(x: 2, y: 0, width: 6, height: 2));
    });

    test('a missing anchor path renders no overlay', () {
      final frame = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 2, width: 6, height: 1)));

      final decision = renderAnchoredPopup(
        frame,
        anchorPath: 'combo/missing',
        requestedHeight: 3,
        width: 6,
        popupBuilder: _popup,
      );

      expect(decision, isNull);
      expect(frame.hits.rectOf('popup'), isNull);
    });

    test('a width wider than the room right of the anchor clamps into the viewport', () {
      final frame = _frame(20, 10)..render(NodeView(_anchor(left: 12, top: 2, width: 6, height: 1)));

      // anchor.left (12) + width (10) = 22 overhangs area.right (20).
      renderAnchoredPopup(
        frame,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 10,
        popupBuilder: _popup,
      );

      expect(frame.hits.rectOf('popup'), Rect.create(x: 10, y: 3, width: 10, height: 3));
    });
  });

  group('renderAnchoredPopup / degraded policies', () {
    test('under noColor, a cell the popup never paints stays blank inside its rect', () {
      final frame = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 2, width: 6, height: 1)));
      final resolver = StyleResolver(Theme.dark, policy: RenderPolicy.noColor);

      // A reversed selection fill covers the whole frame, including where the
      // popup will land — under noColor a selection fill degrades to
      // Modifier.reversed rather than a background color.
      final baseStyle = resolver.fill(resolver.tones.selection);
      frame.render(Container(width: 20, height: 10, ground: baseStyle, child: Line('base row, base row')));

      renderAnchoredPopup(
        frame,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: (height) => Tagged(
          'popup',
          Container(
            ground: resolver.ground(resolver.tones.surface),
            child: Line('Q', style: resolver.ink(resolver.tones.error)),
          ),
        ).build(),
      );

      final rect = frame.hits.rectOf('popup')!;
      expect(rect, Rect.create(x: 2, y: 3, width: 6, height: 3));

      expect(
        frame.buffer[(x: rect.left + 4, y: rect.bottom - 1)],
        Cell.empty(),
        reason: 'a cell the popup never painted stays blank, not the base text or its reversed selection',
      );
      for (var y = rect.top; y < rect.bottom; y++) {
        for (var x = rect.left; x < rect.right; x++) {
          expect(
            frame.buffer[(x: x, y: y)].modifier,
            Modifier.empty,
            reason: 'no reversed modifier from the base selection survives inside the popup rect',
          );
        }
      }
    });

    test('under ansi16, base backgrounds and modifiers do not survive inside the popup rect', () {
      final frame = _frame(20, 10)..render(NodeView(_anchor(left: 2, top: 2, width: 6, height: 1)));
      final resolver = StyleResolver(Theme.dark, policy: RenderPolicy.ansi16);

      // A selection fill covers the whole frame with a real background plus
      // a bold modifier, as an active selection would under ansi16.
      final baseStyle = resolver.fill(resolver.tones.selection).incModifier(Modifier.bold);
      frame.render(Container(width: 20, height: 10, ground: baseStyle, child: Line('base row, base row')));

      final groundStyle = resolver.ground(resolver.tones.surface);
      renderAnchoredPopup(
        frame,
        anchorPath: 'combo/field',
        requestedHeight: 3,
        width: 6,
        popupBuilder: (height) => Tagged('popup', Container(ground: groundStyle, child: Line(''))).build(),
      );

      final rect = frame.hits.rectOf('popup')!;
      expect(rect, Rect.create(x: 2, y: 3, width: 6, height: 3));

      final expected = Cell.empty().setCell(char: ' ', style: groundStyle);
      for (var y = rect.top; y < rect.bottom; y++) {
        for (var x = rect.left; x < rect.right; x++) {
          expect(
            frame.buffer[(x: x, y: y)],
            expected,
            reason: 'no ghost band: the base bg and bold modifier do not survive under the fg-only ground',
          );
        }
      }
    });
  });
}
