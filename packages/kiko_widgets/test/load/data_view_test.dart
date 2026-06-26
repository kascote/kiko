import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// A read-only computed backing: never materializes, never loads. Proves the
/// [DataView] interface serves more than a materialized list (A7 §2.6).
class _SquaresView implements DataView<int> {
  _SquaresView(this._count);
  final int _count;

  @override
  int? get length => _count;

  @override
  int itemAt(int index) => index * index;

  @override
  bool get hasMore => false;
}

/// A computed backing with unknown length (infinite / lazily computed).
class _UnknownLengthView implements DataView<String> {
  @override
  int? get length => null;

  @override
  String itemAt(int index) => 'item-$index';

  @override
  bool get hasMore => false;
}

void main() {
  group('DataView.fromList', () {
    test('exposes length / itemAt / hasMore = false', () {
      final view = DataView.fromList(['a', 'b', 'c']);
      expect(view.length, 3);
      expect(view.itemAt(0), 'a');
      expect(view.itemAt(2), 'c');
      // Static list: never loads.
      expect(view.hasMore, isFalse);
    });

    test('itemAt out of range throws (synchronous, never awaits)', () {
      final view = DataView.fromList(<int>[1, 2]);
      expect(() => view.itemAt(5), throwsRangeError);
    });

    test('is a DataBuffer under the hood', () {
      expect(DataView.fromList(const <int>[1]), isA<DataBuffer<int>>());
    });
  });

  group('DataBuffer', () {
    test('empty by default, hasMore false', () {
      final buf = DataBuffer<int>();
      expect(buf.length, 0);
      expect(buf.hasMore, isFalse);
    });

    test('seeded with initial items; hasMore set after construction', () {
      final buf = DataBuffer<int>([1, 2])..hasMore = true;
      expect(buf.length, 2);
      expect(buf.itemAt(1), 2);
      expect(buf.hasMore, isTrue);
    });

    test('append grows the buffer (List / Table-forward strategy)', () {
      final buf = DataBuffer<int>([1, 2])
        ..append([3, 4])
        ..append([5]);
      expect(buf.length, 5);
      expect(buf.itemAt(4), 5);
    });

    test('replace swaps all items (combobox / drop-stale strategy)', () {
      final buf = DataBuffer<String>(['old1', 'old2'])..replace(['new1']);
      expect(buf.length, 1);
      expect(buf.itemAt(0), 'new1');
    });

    test('clear empties the buffer', () {
      final buf = DataBuffer<int>([1, 2, 3])..clear();
      expect(buf.length, 0);
    });

    test('hasMore is settable', () {
      final buf = DataBuffer<int>([1])..hasMore = true;
      expect(buf.hasMore, isTrue);
      buf.hasMore = false;
      expect(buf.hasMore, isFalse);
    });

    test('renders through the DataView read face', () {
      final DataView<int> view = DataBuffer<int>([10, 20]);
      expect(view.length, 2);
      expect(view.itemAt(0), 10);
      expect(view.hasMore, isFalse);
    });
  });

  group('computed backing (read-only DataView) smoke test', () {
    test('computes items on demand with known length, never loads', () {
      final DataView<int> view = _SquaresView(4);
      expect(view.length, 4);
      expect(view.itemAt(0), 0);
      expect(view.itemAt(3), 9);
      expect(view.hasMore, isFalse);
    });

    test('supports unknown length (null)', () {
      final DataView<String> view = _UnknownLengthView();
      expect(view.length, isNull);
      expect(view.itemAt(7), 'item-7');
      expect(view.hasMore, isFalse);
    });
  });
}
