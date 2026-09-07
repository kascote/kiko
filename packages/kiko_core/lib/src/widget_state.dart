/// Visual states a widget can be in.
///
/// Declaration order is the order `StyleResolver.resolve` walks the states,
/// so a later state's transform runs after an earlier one's. [cursor] lifts
/// the background of whatever it lands on — a [selected] row keeps its
/// selection color, one step brighter or darker — instead of replacing it.
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
