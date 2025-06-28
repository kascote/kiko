import 'package:kiko/iterators.dart';
import 'package:test/test.dart';

void main() {
  group('zip', () {
    test('combines two iterables of the same length', () {
      final iterable1 = [1, 2, 3];
      final iterable2 = ['a', 'b', 'c'];
      final result = iterable1.zip(iterable2).toList();
      expect(result, [(1, 'a'), (2, 'b'), (3, 'c')]);
    });

    test('combines two iterables of different lengths', () {
      final iterable1 = [1, 2];
      final iterable2 = ['a', 'b', 'c'];
      final result = iterable1.zip(iterable2).toList();
      expect(result, [(1, 'a'), (2, 'b')]);
    });

    test('combines with an empty iterable', () {
      final iterable1 = [1, 2, 3];
      final iterable2 = <String>[];
      final result = iterable1.zip(iterable2).toList();
      expect(result, isEmpty);
    });
  });

  group('zip', () {
    test('combines two iterables of the same length', () {
      final iterable1 = ['z', 'x', 'y'];
      final iterable2 = ['a', 'b', 'c'];
      final result = iterable1.zipIndex(iterable2).toList();
      expect(result, [(0, 'z', 'a'), (1, 'x', 'b'), (2, 'y', 'c')]);
    });
  });

  group('chunks', () {
    test('splits iterable into chunks of given size', () {
      final iterable = [1, 2, 3, 4, 5];
      final result = iterable.chunks(2).toList();
      expect(result, [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });

    test('handles chunk size larger than iterable length', () {
      final iterable = [1, 2, 3];
      final result = iterable.chunks(5).toList();
      expect(result, [
        [1, 2, 3],
      ]);
    });

    test('handles chunk size of zero', () {
      final iterable = [1, 2, 3];
      final result = iterable.chunks(0).toList();
      expect(result, isEmpty);
    });
  });

  group('tuples', () {
    test('generates tuples of consecutive elements', () {
      final iterable = [1, 2, 3, 4];
      final result = iterable.tuples().toList();
      expect(result, [(1, 2), (3, 4)]);
    });

    test('handles iterable with odd number of elements', () {
      final iterable = [1, 2, 3];
      final result = iterable.tuples().toList();
      expect(result, [(1, 2)]);
    });

    test('handles empty iterable', () {
      final iterable = <Object>[];
      final result = iterable.tuples().toList();
      expect(result, isEmpty);
    });
  });

  group('tupleWindow', () {
    test('generates tuples of consecutive elements', () {
      final iterable = [1, 2, 3, 4];
      final result = iterable.tupleWindow().toList();
      expect(result, [(1, 2), (2, 3), (3, 4)]);
    });

    test('handles iterable with single element', () {
      final iterable = [1];
      final result = iterable.tupleWindow().toList();
      expect(result, isEmpty);
    });

    test('handles empty iterable', () {
      final iterable = <Object>[];
      final result = iterable.tupleWindow().toList();
      expect(result, isEmpty);
    });
  });

  group('tupleCombinations', () {
    test('generates all possible combinations of tuples', () {
      final iterable = [1, 2, 3, 4];
      final result = iterable.tupleCombinations().toList();
      expect(result, [(1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4)]);
    });

    test('handles iterable with single element', () {
      final iterable = [1];
      final result = iterable.tupleCombinations().toList();
      expect(result, isEmpty);
    });

    test('handles empty iterable', () {
      final iterable = <Object>[];
      final result = iterable.tupleCombinations().toList();
      expect(result, isEmpty);
    });
  });

  group('cartesianProduct', () {
    test('generates Cartesian product of two iterables', () {
      final iterable1 = [1, 2];
      final iterable2 = ['a', 'b'];
      final result = iterable1.cartesianProduct(iterable2).toList();
      expect(result, [(1, 'a'), (1, 'b'), (2, 'a'), (2, 'b')]);
    });

    test('handles empty first iterable', () {
      final iterable1 = <Object>[];
      final iterable2 = ['a', 'b'];
      final result = iterable1.cartesianProduct(iterable2).toList();
      expect(result, isEmpty);
    });

    test('handles empty second iterable', () {
      final iterable1 = [1, 2];
      final iterable2 = <Object>[];
      final result = iterable1.cartesianProduct(iterable2).toList();
      expect(result, isEmpty);
    });
  });
}
