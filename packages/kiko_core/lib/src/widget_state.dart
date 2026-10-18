/// Visual states a widget can be in.
///
/// `StyleResolver.resolve` applies the active states in its own fixed order,
/// not in declaration order: roles ([selected], [loading], [error]), then
/// [focused], [cursor], [disabled], [hover], [pressed]. [cursor] and [focused]
/// lift the background of whatever they land on by one step, so a [selected]
/// row keeps its selection color, one step lighter or darker.
/// [disabled] blends a filled background toward the ground, or swaps the
/// foreground on a bare one, and ends the chain: [hover] and [pressed] do
/// nothing once [disabled] is active.
enum WidgetState {
  /// The mouse pointer is over the widget. Mouse only — never set by keyboard.
  hover,

  /// The widget is in the chosen set (e.g. a selected list item or checkbox).
  selected,

  /// The widget is the current item — the keyboard cursor position.
  cursor,

  /// The widget owns keyboard input.
  focused,

  /// A pointer is held down on the widget. Mouse only.
  pressed,

  /// The widget is performing an async operation.
  loading,

  /// The widget is in an error state (e.g. validation failure).
  error,

  /// The widget is non-interactive — overrides every other state.
  disabled,
}
