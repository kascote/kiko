import 'cmd.dart';
import 'msg.dart';
import 'widget_event.dart';

/// Interface for objects that can receive focus.
///
/// Implement this to use [FocusGroup] for automatic focus management.
/// If you don't want to use FocusGroup, manage focus manually instead.
abstract interface class Focusable {
  /// Whether this object currently has focus.
  // ignore: avoid_setters_without_getters
  set focused(bool value);
}

/// The outcome of a widget model handling a message: whether it consumed the
/// message, and what handling it produced.
///
/// A parent routes a message to a child through [Component.update] and switches
/// on the result. A [Handled] result ends the message and carries what it
/// produced; a [Declined] result leaves the message in flight, so the parent
/// may offer it to the next candidate — the next id under a pointer, or its
/// own fallback keys.
sealed class UpdateResult {
  /// Const constructor for subclasses.
  const UpdateResult();
}

/// The model consumed the message. [events] holds what it produced for the
/// app to interpret; [cmd] holds what it produced for the runtime to perform.
///
/// The two slots are independent and both optional: a click on a button
/// carries a [WidgetEvent] in [events] and no [cmd]; a widget that queues its
/// own [Tick] carries a [cmd] and no events; most messages carry neither.
class Handled extends UpdateResult {
  /// Widget→app events produced by handling the message. Empty when handling
  /// it produced none.
  final List<WidgetEvent> events;

  /// The runtime effect produced by handling the message, if any.
  final Cmd? cmd;

  /// Creates a [Handled] result carrying [events] and/or [cmd].
  const Handled({this.events = const [], this.cmd});

  /// Creates a [Handled] result carrying the single widget event [event].
  Handled.event(WidgetEvent event) : events = [event], cmd = null;
}

/// The model did not consume the message.
///
/// The message is still in flight, and a decliner has nothing to say about it —
/// carrying no effect is deliberate, so that one message never produces effects
/// from two responders.
class Declined extends UpdateResult {
  /// Creates a [Declined] result.
  const Declined();
}

/// The widget-model contract: a [Focusable] model that handles messages and
/// carries a stable identity.
///
/// Every widget model already exposes [update] (by convention); [Component]
/// promotes that convention to a type so a parent can route to a child
/// generically. [id] is the model's stable identity; widget→app addressing
/// is one *use* of it — every [WidgetEvent] a model emits carries the id as
/// its address. Models that emit no events still have an identity; the id is
/// simply unused.
///
/// Widget models declare `implements Component`; their existing `update` and
/// `id` members satisfy it with no behaviour change.
abstract interface class Component implements Focusable {
  /// Stable identity for this model.
  ///
  /// A [WidgetEvent] carries it as its address, so an app resolves the event
  /// back to its owner by matching this id — an event whose id resolves to no
  /// model is observably dropped rather than silently mishandled.
  String get id;

  /// Handles a message, reporting whether it was consumed and what it produced.
  ///
  /// Returns [Handled] (optionally carrying events and a command) when the
  /// model consumes the message, and [Declined] when it does not — leaving
  /// the message for a parent to route elsewhere.
  UpdateResult update(Msg msg);
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
///   switch (m.focus.focused.update(msg)) {
///     case Handled(:final cmd): return (m, cmd);
///     case Declined(): break; // fall through to the keys below
///   }
///
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
