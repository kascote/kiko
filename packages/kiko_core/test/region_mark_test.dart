import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

/// A frame over a fresh [width]×[height] buffer.
Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// A region double, for asserting a mark without depending on any widget
/// package's own region types.
@immutable
class _TestRegion implements Region {
  const _TestRegion(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is _TestRegion && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => '_TestRegion($name)';
}

void main() {
  group('RegionMark', () {
    test('marks its region over the whole child rect and still paints the child', () {
      const region = _TestRegion('whole');
      final plain = _frame(6, 3)..render(Tagged('field', Line('hi')));
      final marked = _frame(6, 3)..render(Tagged('field', RegionMark(region, Line('hi'))));

      expect(marked.buffer.buf, plain.buffer.buf, reason: 'RegionMark paints nothing beyond the child');
      expect(marked.hits.regionAt('field', 0, 0), region);
      expect(marked.hits.regionAt('field', 5, 2), region, reason: "the mark covers the node's whole rect");
    });

    test('adds no tag of its own, so Tagged.scope can wrap it', () {
      final node = Tagged.scope('cb', RegionMark(const _TestRegion('x'), Line('hi'))).build();

      expect(node.tag, ScopeTag('cb'));
    });
  });
}
