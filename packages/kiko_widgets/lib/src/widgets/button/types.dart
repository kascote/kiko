import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// Actions for button key bindings.
enum ButtonAction {
  /// Activate the button (press).
  activate,
}

/// Actions for button group navigation.
enum ButtonGroupAction {
  /// Move to previous button.
  prev,

  /// Move to next button.
  next,
}

/// Event emitted when a button is pressed.
@immutable
class ButtonPressEvent extends WidgetEvent {
  /// The id of the pressed button.
  @override
  final String id;

  /// Creates a ButtonPressEvent.
  const ButtonPressEvent(this.id);

  @override
  bool operator ==(Object other) => identical(this, other) || other is ButtonPressEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ButtonPressEvent($id)';
}

/// Button's anatomy: one nullable style slot.
///
/// A `null` slot is derived from the theme's tones by the rule below; a
/// non-null slot is the caller's exact resting face and wins verbatim. The
/// active states still patch over it.
///
/// | slot   | derived default          | matrix source  |
/// | ------ | ------------------------- | -------------- |
/// | `face` | `resolver.fill(primary)`  | resting face   |
@immutable
class ButtonStyle {
  /// The resting face, painted before any state's contribution.
  final Style? face;

  /// Creates a ButtonStyle.
  const ButtonStyle({this.face});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ButtonStyle && other.face == face;
  }

  @override
  int get hashCode => face.hashCode;
}

/// Default key bindings for button activation.
final defaultButtonBindings = KeyBinding<ButtonAction>()..map(['enter'], ButtonAction.activate);

/// Default key bindings for button group navigation.
///
/// All arrow keys and vim keys work. Navigation order = list order.
final defaultButtonGroupBindings = KeyBinding<ButtonGroupAction>()
  ..map(['left', 'h'], ButtonGroupAction.prev)
  ..map(['right', 'l'], ButtonGroupAction.next)
  ..map(['up', 'k'], ButtonGroupAction.prev)
  ..map(['down', 'j'], ButtonGroupAction.next);
