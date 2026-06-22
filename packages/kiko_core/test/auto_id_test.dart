import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('autoId', () {
    // The counter is a single shared module-global; reset so each test can
    // assert on exact values without others perturbing the sequence.
    setUp(resetAutoIdCounter);

    test('is sequential and monotonic', () {
      expect(autoId('x'), equals('x-1'));
      expect(autoId('x'), equals('x-2'));
      expect(autoId('x'), equals('x-3'));
    });

    test('shared counter keeps ids unique across types', () {
      // The counter is shared across prefixes, so two different widget types
      // never collide even though each has its own prefix.
      expect(autoId('tableview'), equals('tableview-1'));
      expect(autoId('listview'), equals('listview-2'));
      expect(autoId('treeview'), equals('treeview-3'));
    });

    test('format is <prefix>-<n>', () {
      expect(autoId('button'), matches(RegExp(r'^button-\d+$')));
    });

    test('distinct calls yield distinct ids', () {
      final ids = List.generate(100, (_) => autoId('w'));
      expect(ids.toSet().length, equals(100));
    });

    test('resetAutoIdCounter restarts numbering at 1', () {
      autoId('a');
      autoId('a');
      resetAutoIdCounter();
      expect(autoId('a'), equals('a-1'));
    });
  });
}
