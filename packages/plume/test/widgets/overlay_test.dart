import 'package:plume/plume.dart';
import 'package:test/test.dart';

import '../support/golden.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// A container that paints a solid fill, so it shows up in paint goldens.
Container<String> _panel(String style, {int? width, int? height}) =>
    Container<String>(background: style, width: width, height: height, child: SizedBox<String>());

void main() {
  group('Overlay', () {
    test('sizes the base to fill the viewport', () {
      final base = SizedBox<String>(width: 2, height: 2);
      final overlay = Overlay<String>(base: base)
        ..layout(BoxConstraints.tight(const Size(10, 6)), _ctx)
        ..place(Offset.zero);
      expect(overlay.size, const Size(10, 6));
      expect(base.rect, const Rect(0, 0, 10, 6));
    });

    test('paints overlays after the base, in list order', () {
      final result = paintGolden(
        Overlay<String>(
          base: _panel('base'),
          overlays: [
            _panel('scrim'),
            Positioned<String>(left: 1, top: 1, child: _panel('modal', width: 3, height: 2)),
          ],
        ),
        const Size(8, 4),
      );
      expect(result, [
        'fillRect(Rect(0, 0, 8, 4), base)',
        'fillRect(Rect(0, 0, 8, 4), scrim)',
        'fillRect(Rect(1, 1, 3, 2), modal)',
      ]);
    });
  });
}
