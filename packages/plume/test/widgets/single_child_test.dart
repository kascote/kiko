import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

void main() {
  group('Padding', () {
    test('insets the child and grows to include the padding', () {
      final pad = Padding<String>(insets: const EdgeInsets.all(1), child: SizedBox<String>(width: 3, height: 2))
        ..layout(BoxConstraints.loose(const Size(10, 6)), _ctx)
        ..place(Offset.zero);
      expect(pad.size, const Size(5, 4));
      expect(pad.child.rect, const Rect(1, 1, 3, 2));
    });
  });

  group('Align', () {
    test('fills bounded space and positions the child', () {
      final align = Align<String>(alignment: Alignment.bottomRight, child: SizedBox<String>(width: 2, height: 1))
        ..layout(BoxConstraints.tight(const Size(10, 5)), _ctx)
        ..place(Offset.zero);
      expect(align.size, const Size(10, 5));
      expect(align.child.rect, const Rect(8, 4, 2, 1));
    });
  });

  group('Center', () {
    test('centers the child within the available space', () {
      final center = Center<String>(child: SizedBox<String>(width: 2, height: 2))
        ..layout(BoxConstraints.tight(const Size(10, 6)), _ctx)
        ..place(Offset.zero);
      expect(center.child.rect, const Rect(4, 2, 2, 2));
    });
  });

  group('ConstrainedBox', () {
    test('tightens the child up to its extra minimums', () {
      final box = ConstrainedBox<String>(
        additionalConstraints: const BoxConstraints(minW: 5, minH: 3),
        child: SizedBox<String>(width: 2, height: 1),
      )..layout(BoxConstraints.loose(const Size(20, 20)), _ctx);
      expect(box.size, const Size(5, 3));
    });
  });
}
