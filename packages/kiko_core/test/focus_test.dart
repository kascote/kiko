import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// Simple focusable model for testing.
class MockFocusable implements Focusable {
  @override
  bool focused = false;

  final String name;

  MockFocusable(this.name);
}

void main() {
  group('FocusGroup', () {
    test('initializes with first item focused', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items);

      expect(items[0].focused, isTrue);
      expect(items[1].focused, isFalse);
      expect(items[2].focused, isFalse);
      expect(group.index, equals(0));
      expect(group.focused, equals(items[0]));
    });

    test('initializes with custom initial index', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items, initial: 1);

      expect(items[0].focused, isFalse);
      expect(items[1].focused, isTrue);
      expect(items[2].focused, isFalse);
      expect(group.index, equals(1));
    });

    test('cycle moves forward and updates focused fields', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items);

      group.cycle(1);
      expect(group.index, equals(1));
      expect(items[0].focused, isFalse);
      expect(items[1].focused, isTrue);
      expect(items[2].focused, isFalse);

      group.cycle(1);
      expect(group.index, equals(2));
      expect(items[1].focused, isFalse);
      expect(items[2].focused, isTrue);
    });

    test('cycle wraps forward', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items, initial: 2);

      group.cycle(1);
      expect(group.index, equals(0));
      expect(items[2].focused, isFalse);
      expect(items[0].focused, isTrue);
    });

    test('cycle moves backward', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items, initial: 2);

      group.cycle(-1);
      expect(group.index, equals(1));
      expect(items[2].focused, isFalse);
      expect(items[1].focused, isTrue);
    });

    test('cycle wraps backward', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items);

      group.cycle(-1);
      expect(group.index, equals(2));
      expect(items[0].focused, isFalse);
      expect(items[2].focused, isTrue);
    });

    test('cycle by multiple positions', () {
      final items = List.generate(5, (i) => MockFocusable('$i'));
      final group = FocusGroup(items);

      group.cycle(3);
      expect(group.index, equals(3));
      expect(items[0].focused, isFalse);
      expect(items[3].focused, isTrue);

      group.cycle(-2);
      expect(group.index, equals(1));
      expect(items[3].focused, isFalse);
      expect(items[1].focused, isTrue);
    });

    test('cycle does nothing for empty group', () {
      final group = FocusGroup<MockFocusable>([]);

      group.cycle(1);
      expect(group.length, equals(0));
    });

    test('setIndex changes focus and updates focused fields', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items);

      group.setIndex(2);
      expect(group.index, equals(2));
      expect(items[0].focused, isFalse);
      expect(items[2].focused, isTrue);

      group.setIndex(0);
      expect(group.index, equals(0));
      expect(items[2].focused, isFalse);
      expect(items[0].focused, isTrue);
    });

    test('setIndex ignores out of bounds', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items, initial: 1);

      group.setIndex(5);
      expect(group.index, equals(1)); // unchanged
      expect(items[1].focused, isTrue);

      group.setIndex(-1);
      expect(group.index, equals(1)); // unchanged
    });

    test('focusedAs casts to specific type', () {
      final items = [MockFocusable('a'), MockFocusable('b')];
      final group = FocusGroup(items);

      final focused = group.focusedAs<MockFocusable>();
      expect(focused.name, equals('a'));
    });

    test('children provides access to list', () {
      final items = [MockFocusable('a'), MockFocusable('b')];
      final group = FocusGroup(items);

      expect(group.children, equals(items));
      expect(group.children[0].name, equals('a'));
    });
  });

  group('Focusable', () {
    test('can be implemented', () {
      final item = MockFocusable('test');
      expect(item.focused, isFalse);
      item.focused = true;
      expect(item.focused, isTrue);
    });
  });

  group('Unhandled cmd', () {
    test('Unhandled is a Cmd', () {
      const unhandled = Unhandled();
      expect(unhandled, isA<Cmd>());
    });

    test('is check works correctly', () {
      Cmd? cmd = const Unhandled();
      expect(cmd is Unhandled, isTrue);

      cmd = null;
      expect(cmd is Unhandled, isFalse);

      cmd = const Quit();
      expect(cmd is Unhandled, isFalse);
    });
  });
}
