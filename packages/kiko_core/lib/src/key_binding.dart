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
  /// Asserts valid key specs in debug mode (with typo suggestions).
  void map(List<String> keys, A action) {
    for (final key in keys) {
      assert(_validateKey(key), 'Invalid key: $key');
      _bindings[key] = action;
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
  /// Only matches key press events (not repeat or release).
  A? resolve(KeyMsg msg) {
    if (msg.type != KeyEventType.press) return null;
    return _bindings[msg.key];
  }

  /// Returns all keys bound to [action] (for help screens).
  List<String> keysFor(A action) => _bindings.entries.where((e) => e.value == action).map((e) => e.key).toList();

  /// Adds all bindings from [other], overriding on conflict.
  void addAll(KeyBinding<A> other) {
    _bindings.addAll(other._bindings);
  }

  /// Removes binding for [key].
  void remove(String key) {
    _bindings.remove(key);
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
