import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

PointerMsg _pressOn(String targetId) =>
    PointerMsg(global: Position.origin, action: PointerAction.down, local: Position.origin, targetId: targetId);

void main() {
  for (final policy in [RenderPolicy.color, RenderPolicy.ansi16]) {
    test('the popup rows lift from the surface tone under $policy', () {
      final resolver = StyleResolver(Theme.dark, policy: policy);
      final popup = resolver.on(resolver.tones.surface);
      // The sixteen-color ground carries no background of its own: the
      // terminal's reset color stands for it.
      final surfaceBg = popup.ground(popup.tones.surface).bg ?? Color.reset;

      final combo = ComboboxModel<String>(
        id: 'combo',
        fieldId: 'field',
        toggleId: 'toggle',
        label: (s) => s,
        options: const ['Apple', 'Banana', 'Cherry', 'Date'],
        focused: true,
        maxVisibleRows: 3,
      )..update(_pressOn('combo/toggle'));
      final view = Combobox(model: combo, resolver: resolver);
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 6));
      final frame = Frame(buffer.area, buffer, 0)
        ..render(
          Column(
            children: [
              ConstrainedBox(additionalConstraints: const BoxConstraints(minH: 1, maxH: 1), child: view),
            ],
          ),
        );
      view.renderPopup(frame);

      // Rows 1..3 are the popup; the last one holds no cursor, so it keeps
      // the surface ground.
      expect(buffer[(x: 9, y: 3)].bg, surfaceBg);
      // The cursor row lifts the surface, not the window.
      final cursorRow = popup.resolve(
        popup.ground(popup.tones.surface),
        const {WidgetState.cursor, WidgetState.focused},
        cls: PaintClass.fill,
      );
      expect(buffer[(x: 9, y: 1)].bg, cursorRow.bg);
      expect(buffer[(x: 9, y: 1)].bg, isNot(surfaceBg), reason: 'the cursor row is lifted');
      expect(buffer[(x: 9, y: 3)].fg, popup.ground(popup.tones.surface).fg);
    });
  }
}
