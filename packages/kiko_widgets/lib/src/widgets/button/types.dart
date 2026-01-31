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

/// Command emitted when a button is pressed.
@immutable
class ButtonPressCmd extends Cmd {
  /// The id of the pressed button.
  final String id;

  /// Creates a ButtonPressCmd.
  const ButtonPressCmd(this.id);

  @override
  bool operator ==(Object other) => identical(this, other) || other is ButtonPressCmd && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ButtonPressCmd($id)';
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
