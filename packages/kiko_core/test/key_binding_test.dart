import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

enum TestAction { quit, save, search, help }

void main() {
  group('KeyBinding', () {
    test('map and resolve', () {
      final binding = KeyBinding<TestAction>()
        ..map(['ctrl+q', 'escape'], TestAction.quit)
        ..map(['ctrl+s'], TestAction.save);

      expect(binding.resolve(const KeyMsg('ctrl+q')), TestAction.quit);
      expect(binding.resolve(const KeyMsg('escape')), TestAction.quit);
      expect(binding.resolve(const KeyMsg('ctrl+s')), TestAction.save);
      expect(binding.resolve(const KeyMsg('ctrl+x')), null);
    });

    test('resolve only matches press events', () {
      final binding = KeyBinding<TestAction>()..map(['ctrl+q'], TestAction.quit);

      expect(binding.resolve(const KeyMsg('ctrl+q')), TestAction.quit);
      expect(binding.resolve(const KeyMsg.repeat('ctrl+q')), null);
      expect(binding.resolve(const KeyMsg.release('ctrl+q')), null);
    });

    test('map overrides existing binding', () {
      final binding = KeyBinding<TestAction>()
        ..map(['ctrl+q'], TestAction.quit)
        ..map(['ctrl+q'], TestAction.save);

      expect(binding.resolve(const KeyMsg('ctrl+q')), TestAction.save);
    });

    test('keysFor returns all keys for action', () {
      final binding = KeyBinding<TestAction>()
        ..map(['ctrl+q', 'escape'], TestAction.quit)
        ..map(['ctrl+s'], TestAction.save);

      expect(binding.keysFor(TestAction.quit), ['ctrl+q', 'escape']);
      expect(binding.keysFor(TestAction.save), ['ctrl+s']);
      expect(binding.keysFor(TestAction.search), <String>[]);
    });

    test('addAll merges bindings', () {
      final base = KeyBinding<TestAction>()
        ..map(['ctrl+q'], TestAction.quit)
        ..map(['ctrl+s'], TestAction.save);

      final override = KeyBinding<TestAction>()
        ..map(['escape'], TestAction.quit)
        ..map(['ctrl+s'], TestAction.search); // override save

      base.addAll(override);

      expect(base.resolve(const KeyMsg('ctrl+q')), TestAction.quit);
      expect(base.resolve(const KeyMsg('escape')), TestAction.quit);
      expect(base.resolve(const KeyMsg('ctrl+s')), TestAction.search);
    });

    test('copy creates independent copy', () {
      final original = KeyBinding<TestAction>()..map(['ctrl+q'], TestAction.quit);

      final copied = original.copy()..map(['ctrl+q'], TestAction.save);

      expect(original.resolve(const KeyMsg('ctrl+q')), TestAction.quit);
      expect(copied.resolve(const KeyMsg('ctrl+q')), TestAction.save);
    });

    test('remove removes single binding', () {
      final binding = KeyBinding<TestAction>()
        ..map(['ctrl+q', 'escape'], TestAction.quit)
        ..remove('ctrl+q');

      expect(binding.resolve(const KeyMsg('ctrl+q')), null);
      expect(binding.resolve(const KeyMsg('escape')), TestAction.quit);
    });

    test('unbind removes all bindings for action', () {
      final binding = KeyBinding<TestAction>()
        ..map(['ctrl+q', 'escape'], TestAction.quit)
        ..map(['ctrl+s'], TestAction.save)
        ..unbind(TestAction.quit);

      expect(binding.resolve(const KeyMsg('ctrl+q')), null);
      expect(binding.resolve(const KeyMsg('escape')), null);
      expect(binding.resolve(const KeyMsg('ctrl+s')), TestAction.save);
    });

    test('clear removes all bindings', () {
      final binding = KeyBinding<TestAction>()
        ..map(['ctrl+q'], TestAction.quit)
        ..map(['ctrl+s'], TestAction.save)
        ..clear();

      expect(binding.resolve(const KeyMsg('ctrl+q')), null);
      expect(binding.resolve(const KeyMsg('ctrl+s')), null);
    });

    test('toGroupedMap groups keys by action', () {
      final binding = KeyBinding<TestAction>()
        ..map(['ctrl+q', 'escape'], TestAction.quit)
        ..map(['ctrl+s'], TestAction.save);

      final grouped = binding.toGroupedMap();

      expect(grouped[TestAction.quit], ['ctrl+q', 'escape']);
      expect(grouped[TestAction.save], ['ctrl+s']);
      expect(grouped.containsKey(TestAction.search), false);
    });

    test('isValidKey returns true for valid keys', () {
      expect(KeyBinding.isValidKey('a'), true);
      expect(KeyBinding.isValidKey('enter'), true);
      expect(KeyBinding.isValidKey('ctrl+a'), true);
      expect(KeyBinding.isValidKey('shift+ctrl+enter'), true);
    });

    test('isValidKey returns false for invalid keys', () {
      expect(KeyBinding.isValidKey('ctr+a'), false);
      expect(KeyBinding.isValidKey('foo'), false);
    });

    test('validateKey throws InvalidKeySpecException on invalid key', () {
      expect(
        () => KeyBinding.validateKey('ctr+a'),
        throwsA(isA<InvalidKeySpecException>()),
      );
    });
  });

  // Regression guard: 'space'/'plus'/'minus' are word-aliased specs for the
  // literal ' '/'+'/'-' characters (see KeyMsg.char), needed because '+' is
  // the modifier separator in a spec like 'ctrl+s'. KeyBinding and
  // KeyMsg.char read the SAME spec string but answer different questions —
  // "is this bound?" vs "what text would this insert?" — and both must stay
  // correct independently. List/Table bind 'space' to toggleSelect today.
  group('KeyBinding aliased literal keys (space/plus/minus)', () {
    test('space, plus, and minus are valid, bindable specs', () {
      expect(KeyBinding.isValidKey('space'), true);
      expect(KeyBinding.isValidKey('plus'), true);
      expect(KeyBinding.isValidKey('minus'), true);
    });

    test('a binding on space resolves against a real space KeyMsg', () {
      final binding = KeyBinding<TestAction>()..map(['space'], TestAction.search);

      expect(binding.resolve(const KeyMsg('space')), TestAction.search);
      // Whether or not 'space' is bound to an action, KeyMsg.char must still
      // answer independently — the two systems share a string, not a result.
      expect(const KeyMsg('space').char, equals(' '));
    });
  });
}
