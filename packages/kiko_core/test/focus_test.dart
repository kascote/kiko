import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// Simple focusable model for testing.
class MockFocusable implements Focusable {
  @override
  bool focused = false;

  final String name;

  MockFocusable(this.name);
}

/// Minimal widget-model satisfying the [Component] contract (`id` + `update`).
class MockComponent implements Component {
  @override
  final String id;

  @override
  bool focused = false;

  MockComponent(this.id);

  @override
  UpdateResult update(Msg msg) => const Handled();
}

/// A message no model understands: the probe for the decline path.
class _UnknownMsg extends Msg {
  const _UnknownMsg();
}

/// A stand-in widget event, the shape a real one takes ([id] plus payload).
class _TestEvent extends WidgetEvent {
  _TestEvent(this.id);

  @override
  final String id;
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
      final group = FocusGroup(items)..cycle(1);
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
      final group = FocusGroup(items, initial: 2)..cycle(1);
      expect(group.index, equals(0));
      expect(items[2].focused, isFalse);
      expect(items[0].focused, isTrue);
    });

    test('cycle moves backward', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items, initial: 2)..cycle(-1);
      expect(group.index, equals(1));
      expect(items[2].focused, isFalse);
      expect(items[1].focused, isTrue);
    });

    test('cycle wraps backward', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items)..cycle(-1);
      expect(group.index, equals(2));
      expect(items[0].focused, isFalse);
      expect(items[2].focused, isTrue);
    });

    test('cycle by multiple positions', () {
      final items = List.generate(5, (i) => MockFocusable('$i'));
      final group = FocusGroup(items)..cycle(3);
      expect(group.index, equals(3));
      expect(items[0].focused, isFalse);
      expect(items[3].focused, isTrue);

      group.cycle(-2);
      expect(group.index, equals(1));
      expect(items[3].focused, isFalse);
      expect(items[1].focused, isTrue);
    });

    test('cycle does nothing for empty group', () {
      final group = FocusGroup<MockFocusable>([])..cycle(1);
      expect(group.length, equals(0));
    });

    test('setIndex changes focus and updates focused fields', () {
      final items = [MockFocusable('a'), MockFocusable('b'), MockFocusable('c')];
      final group = FocusGroup(items)..setIndex(2);
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
      final group = FocusGroup(items, initial: 1)..setIndex(5);
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

  group('Component', () {
    test('exposes a stable id through the Component interface', () {
      final Component c = MockComponent('widget-1');
      expect(c.id, equals('widget-1'));
    });

    test('is a Focusable (id is identity, focus is one use of it)', () {
      final c = MockComponent('w')..focused = true;
      expect(c, isA<Focusable>());
      expect(c.focused, isTrue);
    });

    test('update is reachable generically through Component', () {
      final Component c = MockComponent('w');
      expect(c.update(const _UnknownMsg()), isA<Handled>());
    });
  });

  group('UpdateResult', () {
    test('Handled and Declined are UpdateResults', () {
      expect(const Handled(), isA<UpdateResult>());
      expect(const Declined(), isA<UpdateResult>());
    });

    test('Handled carries an optional command', () {
      expect(const Handled().cmd, isNull);
      expect(const Handled(cmd: Quit()).cmd, isA<Quit>());
    });

    test('Handled carries widget events apart from the command', () {
      expect(const Handled().events, isEmpty);
      final event = _TestEvent('w');
      expect(Handled.event(event).events, equals([event]));
      expect(Handled.event(event).cmd, isNull);
    });

    test('a decline is distinguishable from a handle', () {
      UpdateResult result = const Declined();
      expect(result is Declined, isTrue);
      expect(result is Handled, isFalse);

      result = const Handled();
      expect(result is Handled, isTrue);
      expect(result is Declined, isFalse);
    });
  });
}
