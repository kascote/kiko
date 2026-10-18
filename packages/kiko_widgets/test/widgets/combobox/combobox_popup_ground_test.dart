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

  group('the popup list takes its anatomy as given', () {
    Buffer renderPopup(StyleResolver resolver, ComboboxStyle style) {
      final combo = ComboboxModel<String>(
        id: 'combo',
        fieldId: 'field',
        toggleId: 'toggle',
        label: (s) => s,
        options: const ['Apple', 'Banana', 'Cherry'],
        focused: true,
        maxVisibleRows: 3,
      )..update(_pressOn('combo/toggle'));
      final view = Combobox(model: combo, resolver: resolver, style: style);
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 5));
      final frame = Frame(buffer.area, buffer, 0)
        ..render(
          Column(
            children: [
              ConstrainedBox(additionalConstraints: const BoxConstraints(minH: 1, maxH: 1), child: view),
            ],
          ),
        );
      view.renderPopup(frame);
      return buffer;
    }

    test('the cursor row lifts the surface by the step the window list lifts the background', () {
      final resolver = StyleResolver(Theme.dark);
      final buffer = renderPopup(resolver, const ComboboxStyle());
      final surface = resolver.tones.surface.color!;
      final background = resolver.tones.background.color!;

      final popupDelta = buffer[(x: 9, y: 1)].bg.toOklab().l - surface.toOklab().l;

      final windowBuffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 2));
      Frame(windowBuffer.area, windowBuffer, 0).render(
        ListView<String, String>(
          model: ListViewModel<String, String>(items: const ['Apple', 'Banana'], focused: true),
          resolver: resolver,
          itemBuilder: (item, index, state) => [Line(item)],
        ),
      );
      final windowDelta = windowBuffer[(x: 7, y: 0)].bg.toOklab().l - background.toOklab().l;

      expect(popupDelta, closeTo(windowDelta, 0.005));
      expect(popupDelta, greaterThan(0));
    });

    test('a caller item inside the popup is used verbatim', () {
      const item = Style(fg: Color.white, bg: Color.red);
      final resolver = StyleResolver(Theme.dark);
      final buffer = renderPopup(resolver, const ComboboxStyle(list: ListViewStyle(item: item)));

      // Row 2 holds no cursor: its fill is the caller's, not the surface.
      expect(buffer[(x: 9, y: 2)].bg, equals(Color.red));
      // The cursor row lifts the caller's base, not the surface.
      expect(buffer[(x: 9, y: 1)].bg, isNot(Color.red));
      expect(buffer[(x: 9, y: 1)].bg, equals(Color.red.shiftLightness(Theme.step)));
    });
  });
}
