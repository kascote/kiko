import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

/// A frame over a fresh [width]×[height] buffer.
Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

void main() {
  group('Frame addressing', () {
    // Two bordered boxes side by side, each three cells wide, stamped a and b.
    late Frame frame;
    setUp(() {
      final a = box(border: BorderType.plain, child: lineNode(Line('A')))..tag = 'btn-a';
      final b = box(border: BorderType.plain, child: lineNode(Line('B')))..tag = 'btn-b';
      frame = _frame(6, 3)..renderNode(plume.Row<PaintToken>(children: <plume.RenderNode<PaintToken>>[a, b]));
    });

    test('hitId resolves a point to the enclosing widget id', () {
      expect(frame.hitId(1, 1), 'btn-a');
      expect(frame.hitId(4, 1), 'btn-b');
    });

    test('hitId resolves the box border itself, not just its inside', () {
      expect(frame.hitId(0, 0), 'btn-a');
    });

    test('hitId returns null off the tree', () {
      expect(frame.hitId(20, 20), isNull);
    });

    test('rectOf returns the on-screen rect of each id', () {
      expect(frame.rectOf('btn-a'), Rect.create(x: 0, y: 0, width: 3, height: 3));
      expect(frame.rectOf('btn-b'), Rect.create(x: 3, y: 0, width: 3, height: 3));
    });

    test('rectOf returns null for an unknown id', () {
      expect(frame.rectOf('btn-z'), isNull);
    });
  });

  test('a later renderNode wins an overlap', () {
    final frame = _frame(4, 3);
    final under = box(border: BorderType.plain, child: lineNode(Line('U')))..tag = 'under';
    final over = box(border: BorderType.plain, child: lineNode(Line('O')))..tag = 'over';
    frame
      ..renderNode(under)
      ..renderNode(over);
    // Both cover the frame; the tree painted last is what the viewer sees.
    expect(frame.hitId(1, 1), 'over');
  });
}
