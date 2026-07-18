import 'package:termparser/termparser_events.dart' show KeyEvent;

import 'mvu/msg.dart';

/// Exception thrown when an invalid key spec is provided.
class InvalidKeySpecException implements Exception {
  /// The invalid key spec.
  final String key;

  /// Creates an InvalidKeySpecException.
  InvalidKeySpecException(this.key);

  @override
  String toString() => 'InvalidKeySpecException: "$key"';
}

/// Maps key specs to actions of type [A].
///
/// Supports multiple keys per action, merging, and reverse lookup.
///
/// ```dart
/// final binding = KeyBinding<AppAction>()
///   ..map(['ctrl+q', 'escape'], AppAction.quit)
///   ..map(['ctrl+s'], AppAction.save);
///
/// // In update()
/// final action = binding.resolve(msg);
/// if (action != null) {
///   return _executeAction(action);
/// }
/// ```
class KeyBinding<A> {
  final Map<String, A> _bindings = {};

  /// Maps one or more key specs to an action.
  ///
  /// Silently overrides existing bindings (enables user overrides).
  ///
  /// Every spec is canonicalized through the same parser round-trip a
  /// [KeyMsg] goes through at intake (`KeyEvent.fromString(spec).toSpec()`),
  /// so two spellings of the same keystroke land on one table entry:
  /// `map(['shift+a'], x)` and `map(['A'], x)` are indistinguishable
  /// afterwards, and a `KeyMsg` for either the Shift+A chord or a bare
  /// uppercase A resolves to `x`. See [KeyEvent.toSpec] for the exact
  /// folding rule (cased letters always fold; named keys and degraded
  /// shifted symbols do not).
  ///
  /// Canonicalization runs unconditionally, in every build mode — not just
  /// under `assert`. An invalid spec always throws [InvalidKeySpecException]
  /// (release builds included): a binding that can never match a keystroke
  /// is a bug, not something to swallow silently.
  void map(List<String> keys, A action) {
    for (final key in keys) {
      _bindings[_canonicalize(key)] = action;
    }
  }

  /// Canonicalizes [key] through termparser's parse/print round-trip.
  ///
  /// Throws [InvalidKeySpecException] if [key] is not a valid spec.
  static String _canonicalize(String key) {
    try {
      return KeyEvent.fromString(key).toSpec();
      // KeyEvent.fromString throws ArgumentError for invalid specs; surface
      // kiko's own exception type instead, always (not assert-gated) — see
      // the class-level note on [map].
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw InvalidKeySpecException(key);
    }
  }

  /// Validates key spec using termparser.
  /// Returns true if valid, throws [InvalidKeySpecException] if invalid.
  static bool _validateKey(String key) {
    if (!isValidKey(key)) {
      throw InvalidKeySpecException(key);
    }
    return true;
  }

  /// Returns true if [key] is a valid key spec.
  static bool isValidKey(String key) {
    try {
      KeyEvent.fromString(key);
      return true;
      // KeyEvent.fromString throws ArgumentError for invalid specs
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return false;
    }
  }

  /// Validates key spec for config loading.
  /// Throws [InvalidKeySpecException] if invalid.
  static void validateKey(String key) {
    _validateKey(key);
  }

  /// Resolves a KeyMsg to an action, or null if not bound.
  ///
  /// A [KeyMsg] IS a keystroke — a press or an auto-repeat of one — and both
  /// resolve identically, so a held key (an arrow, backspace) keeps
  /// resolving to its action for as long as it's held. A release or a bare
  /// modifier can never reach this method: they arrive as `KeyReleaseMsg`
  /// and `ModifierKeyMsg`, sibling types `resolve` does not accept, so there
  /// is nothing left to exclude by construction.
  ///
  /// Looks up [KeyMsg.key] first. On a miss, when [KeyMsg.baseKey] is
  /// non-null, retries against it — the base (US-layout) projection of the
  /// same physical key, letting a binding written as `'ctrl+z'` still fire
  /// for Ctrl+Я on a Cyrillic layout. A binding registered for the
  /// layout-specific spec (`'ctrl+я'`) always wins first, since it is tried
  /// before the fallback. Terminals that never report a base layout key
  /// leave [KeyMsg.baseKey] null, so the fallback is simply inert there.
  A? resolve(KeyMsg msg) {
    final action = _bindings[msg.key];
    if (action != null) return action;
    final baseKey = msg.baseKey;
    if (baseKey == null) return null;
    return _bindings[baseKey];
  }

  /// Returns all keys bound to [action] (for help screens).
  ///
  /// Keys come back in their canonical spelling (as [map] stored them),
  /// which may differ from what a caller originally passed to `map` — e.g.
  /// mapping `'shift+a'` shows up here as `'A'`.
  List<String> keysFor(A action) => _bindings.entries.where((e) => e.value == action).map((e) => e.key).toList();

  /// Adds all bindings from [other], overriding on conflict.
  void addAll(KeyBinding<A> other) {
    _bindings.addAll(other._bindings);
  }

  /// Removes binding for [key].
  ///
  /// Canonicalizes [key] the same way [map] does, so `remove('shift+a')`
  /// finds a binding that was registered as `'A'` (and vice versa).
  void remove(String key) {
    _bindings.remove(_canonicalize(key));
  }

  /// Removes all bindings for [action].
  void unbind(A action) {
    _bindings.removeWhere((_, v) => v == action);
  }

  /// Removes all bindings.
  void clear() {
    _bindings.clear();
  }

  /// Creates a copy of this binding.
  KeyBinding<A> copy() => KeyBinding<A>()..addAll(this);

  /// Returns bindings grouped by action (for config export).
  /// Actions with no bindings are omitted.
  Map<A, List<String>> toGroupedMap() {
    final result = <A, List<String>>{};
    for (final entry in _bindings.entries) {
      (result[entry.value] ??= []).add(entry.key);
    }
    return result;
  }
}
