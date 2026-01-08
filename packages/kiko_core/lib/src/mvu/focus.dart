/// Interface for objects that can receive focus.
///
/// Implement this to use [FocusGroup] for automatic focus management.
/// If you don't want to use FocusGroup, manage focus manually instead.
abstract interface class Focusable {
  /// Whether this object currently has focus.
  // ignore: avoid_setters_without_getters
  set focused(bool value);
}

/// Manages focus among a list of [Focusable] items.
///
/// A helper that tracks which item is focused and automatically updates
/// the `focused` field when cycling. Optional - you can manage focus manually.
///
/// Example:
/// ```dart
/// class FormModel {
///   late final focus = FocusGroup([
///     TextInputModel(placeholder: 'Username'),
///     TextInputModel(placeholder: 'Password'),
///   ]);
///
///   TextInputModel get username => focus.children[0];
///   TextInputModel get password => focus.children[1];
/// }
///
/// (FormModel, Cmd?) formUpdate(FormModel m, Msg msg) {
///   final cmd = m.focus.focused.update(msg);
///   if (cmd is! Unhandled) return (m, cmd);
///
///   // Handle unhandled keys
///   if (isTab(msg)) {
///     m.focus.cycle(1);  // automatically updates focused fields
///     return (m, null);
///   }
///   if (isQuit(msg)) return (m, const Quit());
///   return (m, null);
/// }
/// ```
class FocusGroup<T extends Focusable> {
  /// The list of focusable items.
  final List<T> children;

  int _index;

  /// Creates a FocusGroup with the given items.
  ///
  /// The item at [initial] index will have `focused = true` set.
  /// All other items will have `focused = false` set.
  FocusGroup(this.children, {int initial = 0}) : _index = initial {
    for (var i = 0; i < children.length; i++) {
      children[i].focused = i == initial;
    }
  }

  /// Number of items.
  int get length => children.length;

  /// The index of the currently focused item.
  int get index => _index;

  /// The currently focused item.
  T get focused => children[_index];

  /// The currently focused item cast to a specific type.
  ///
  /// Useful when children are mixed types.
  S focusedAs<S>() => focused as S;

  /// Cycle focus by [delta] positions (positive = forward, negative = back).
  ///
  /// Wraps around at boundaries. Automatically updates `focused` fields.
  void cycle(int delta) {
    if (children.isEmpty) return;
    children[_index].focused = false;
    _index = (_index + delta) % children.length;
    if (_index < 0) _index += children.length;
    children[_index].focused = true;
  }

  /// Set focus to a specific index.
  ///
  /// Does nothing if index is out of bounds. Automatically updates `focused` fields.
  void setIndex(int index) {
    if (index < 0 || index >= children.length) return;
    children[_index].focused = false;
    _index = index;
    children[_index].focused = true;
  }
}
