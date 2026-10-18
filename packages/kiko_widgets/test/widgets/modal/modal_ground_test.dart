import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  for (final policy in [RenderPolicy.color, RenderPolicy.ansi16]) {
    test('the dialog binds the surface tone under $policy', () {
      final resolver = StyleResolver(Theme.dark, policy: policy);
      final surface = resolver.on(resolver.tones.surface);
      final dialog = modalDialog(id: 'confirm', content: Line('Sure?').build(), resolver: resolver);
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 12, height: 3));
      Frame(buffer.area, buffer, 0).render(NodeView(dialog));

      final expectedGround = surface.ground(surface.tones.surface);
      final expectedBg = expectedGround.bg ?? Color.reset;
      final expectedBorder = surface.border(const {});
      // Padding cell inside the frame: ground only.
      expect(buffer[(x: 1, y: 1)].bg, expectedBg);
      // The text cell sits on the same ground.
      expect(buffer[(x: 2, y: 1)].bg, expectedBg);
      // The frame paints the surface-bound border.
      expect(buffer[(x: 0, y: 1)].fg, expectedBorder.fg);
      expect(buffer[(x: 2, y: 1)].fg, expectedGround.fg);
    });
  }
}
