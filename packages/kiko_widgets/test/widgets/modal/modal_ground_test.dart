import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  for (final policy in [RenderPolicy.color, RenderPolicy.ansi16]) {
    test('the dialog binds the surface tone under $policy', () {
      final resolver = StyleResolver(Theme.dark, policy: policy);
      final surface = resolver.on(resolver.tones.surface);
      final dialog = modalDialog(id: 'confirm', content: (_) => Line('Sure?'), resolver: resolver);
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

  group('a text input built through the content builder', () {
    for (final policy in [RenderPolicy.color, RenderPolicy.ansi16]) {
      test('paints on the dialog ground with the surface-bound resolver under $policy', () {
        final resolver = StyleResolver(Theme.dark, policy: policy);
        final surface = resolver.on(resolver.tones.surface);
        final models = {
          'rest': TextInputModel(id: 'rest', initial: 'ada'),
          'focused': TextInputModel(id: 'focused', initial: 'ada', focused: true),
          'disabled': TextInputModel(id: 'disabled', initial: 'ada', disabled: true),
          'placeholder': TextInputModel(id: 'placeholder', placeholder: 'name'),
        };
        StyleResolver? handed;
        final dialog = modalDialog(
          id: 'confirm',
          resolver: resolver,
          content: (r) {
            handed = r;
            return Column(
              children: [
                for (final m in models.values)
                  ConstrainedBox(
                    additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
                    child: TextInput(model: m, resolver: r),
                  ),
              ],
            );
          },
        );
        final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 14, height: 6));
        final frame = Frame(buffer.area, buffer, 0)..render(NodeView(dialog));

        expect(handed!.groundTone, resolver.tones.surface);
        final groundBg = surface.ground(surface.tones.surface).bg ?? Color.reset;
        final expectedFg = {
          'rest': surface.resolve(null, const {}, cls: PaintClass.ink).fg,
          'focused': surface.resolve(null, const {WidgetState.focused}, cls: PaintClass.ink).fg,
          'disabled': surface.resolve(null, const {WidgetState.disabled}, cls: PaintClass.ink).fg,
          'placeholder': surface.ink(surface.tones.muted).fg,
        };
        for (final MapEntry(:key, :value) in models.entries) {
          final rect = frame.hits.rectOf(value.id)!;
          final cell = buffer[(x: rect.x, y: rect.y)];
          expect(cell.bg, groundBg, reason: '$key sits on the surface ground');
          expect(cell.fg, expectedFg[key] ?? cell.fg, reason: '$key paints the surface-bound ink');
        }
      });
    }
  });
}
