/// Utilities for Iterables
extension IterableUtils<E> on Iterable<E> {
  /// Combines two iterables into a single iterable of pairs.
  ///
  /// This function takes another iterable [other] and combines it with the
  /// current iterable, yielding pairs of elements from both iterables. The
  /// resulting iterable will have the length of the shorter of the two input
  /// iterables.
  ///
  /// Example:
  ///
  /// ```dart
  /// final iterable1 = [1, 2, 3];
  /// final iterable2 = ['a', 'b', 'c'];
  /// final zipped = iterable1.zip(iterable2);
  ///
  /// for (var pair in zipped) {
  ///   print(pair); // (1, 'a'), (2, 'b'), (3, 'c')
  /// }
  /// ```
  ///
  /// - Returns: An iterable of pairs, where each pair contains one element
  /// from the current iterable and one element from the [other] iterable.
  Iterable<(E, O)> zip<O>(Iterable<O> other) sync* {
    final it1 = iterator;
    final it2 = other.iterator;
    while (it1.moveNext() && it2.moveNext()) {
      yield (it1.current, it2.current);
    }
  }

  /// Combines two iterables into a single iterable of pairs.
  /// Works like [zip] but also provides the index of each pair.
  Iterable<(int, E, O)> zipIndex<O>(Iterable<O> other) sync* {
    final it1 = iterator;
    final it2 = other.iterator;
    var i = 0;
    while (it1.moveNext() && it2.moveNext()) {
      yield (i++, it1.current, it2.current);
    }
  }

  /// Splits this collection into a new lazy [Iterable] of lists each not
  /// exceeding the given [size].
  ///
  /// The last list in the resulting list may have less elements than the given
  /// [size].
  ///
  /// [size] must be positive and can be greater than the number of elements in
  /// this collection.
  Iterable<List<E>> chunks(int size) sync* {
    if (size == 0) return;
    // if (size < 1) {
    //   throw ArgumentError('Requested chunk size $size is less than one.');
    // }

    var currentChunk = <E>[];
    for (final current in this) {
      currentChunk.add(current);
      if (currentChunk.length >= size) {
        yield currentChunk;
        currentChunk = <E>[];
      }
    }
    if (currentChunk.isNotEmpty) {
      yield currentChunk;
    }
  }

  /// Generates an iterable of tuples from the elements of the original iterable.
  ///
  /// Each tuple contains two consecutive elements from the original iterable.
  ///
  /// Example:
  /// ```dart
  /// final list = [1, 2, 3, 4];
  /// final tuples = list.tuples();
  /// print(tuples); // Output: [(1, 2), (2, 3), (3, 4)]
  /// ```
  Iterable<(E, E)> tuples() sync* {
    final it = iterator;
    while (it.moveNext()) {
      final a = it.current;
      if (it.moveNext()) {
        final b = it.current;
        yield (a, b);
      } else {
        break;
      }
    }
  }

  /// Generates an iterable of tuples containing pairs of consecutive elements
  /// from the original iterable.
  ///
  /// This function yields tuples of type `(E, E)`, where each tuple contains
  /// two consecutive elements from the original iterable. If the iterable has
  /// fewer than two elements, no tuples are yielded.
  ///
  /// # Example
  /// ```dart
  /// final list = [1, 2, 3, 4];
  /// final result = list.tupleWindow();
  /// print(result); // Output: [(1, 2), (2, 3), (3, 4)]
  /// ```
  ///
  /// # Returns
  /// An iterable of tuples containing pairs of consecutive elements.
  Iterable<(E, E)> tupleWindow() sync* {
    final it = iterator;
    if (!it.moveNext()) return;
    var a = it.current;
    while (it.moveNext()) {
      final b = it.current;
      yield (a, b);
      a = b;
    }
  }

  /// Generates all possible combinations of tuples from the elements of the iterable.
  ///
  /// This method yields pairs of elements `(E, E)` from the iterable, where each pair
  /// consists of two elements from the iterable. The order of elements in the pairs
  /// is preserved as in the original iterable.
  ///
  /// # Example
  ///
  /// ```dart
  /// void main() {
  ///   final list = [1, 2, 3];
  ///   final combinations = list.tupleCombinations();
  ///
  ///   for (var combination in combinations) {
  ///     print(combination);
  ///   }
  /// }
  /// ```
  ///
  /// The above example will print:
  /// ```text
  ///   (1, 2)
  ///   (1, 3)
  ///   (2, 3)
  /// ```
  Iterable<(E, E)> tupleCombinations() sync* {
    final it1 = iterator;
    var i = 0;
    while (it1.moveNext()) {
      final a = it1.current;
      final it2 = iterator;
      var j = 0;
      while (it2.moveNext()) {
        if (j > i) {
          yield (a, it2.current);
        }
        j++;
      }
      i++;
    }
  }

  /// Generates the Cartesian product of this iterable with another iterable.
  ///
  /// The Cartesian product of two sets is the set of all ordered pairs
  /// where the first element is from the first set and the second element
  /// is from the second set.
  ///
  /// This method yields tuples of elements from the two iterables.
  ///
  /// Example:
  /// ```dart
  /// final list1 = [1, 2];
  /// final list2 = ['a', 'b'];
  /// final result = list1.cartesianProduct(list2);
  /// print(result.toList()); // [(1, 'a'), (1, 'b'), (2, 'a'), (2, 'b')]
  /// ```
  ///
  /// - Parameter other: The other iterable to combine with this iterable.
  /// - Returns: An iterable of tuples containing elements from both iterables.
  Iterable<(E, O)> cartesianProduct<O>(Iterable<O> other) sync* {
    for (final a in this) {
      for (final b in other) {
        yield (a, b);
      }
    }
  }

  /// Generates all possible ordered pairs (permutations of size 2) from the iterable.
  ///
  /// Uses two iterators to generate pairs where each element is paired with every other
  /// element in the iterable, maintaining order sensitivity. The implementation ensures:
  /// - No element is paired with itself (i != j)
  /// - All possible combinations are generated
  /// - Memory efficiency by using iterators instead of buffering
  ///
  /// Example:
  /// ```dart
  /// final numbers = [1, 2, 3];
  /// final pairs = numbers.tuplePermutations();
  /// print(pairs.toList()); // [(1, 2), (1, 3), (2, 1), (2, 3), (3, 1), (3, 2)]
  /// ```
  ///
  /// Time complexity: O(n²) where n is the length of the iterable
  /// Space complexity: O(1) as it only stores current elements
  Iterable<(E, E)> tuplePermutations() sync* {
    final outerIterator = iterator;
    var outerIndex = 0;

    // Early return for empty iterables
    if (!outerIterator.moveNext()) return;

    do {
      final currentElement = outerIterator.current;
      final innerIterator = iterator;
      var innerIndex = 0;

      while (innerIterator.moveNext()) {
        // Only yield when elements are at different positions
        if (outerIndex != innerIndex) {
          yield (currentElement, innerIterator.current);
        }
        innerIndex++;
      }
      outerIndex++;
    } while (outerIterator.moveNext());
  }
}
