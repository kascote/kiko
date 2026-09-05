/// Visual states a widget can be in.
///
/// Declaration order is priority order: when several states are active, later
/// values are applied last and win. For example, [disabled] overrides every
/// other state, and [cursor] shows through a [selected] item so the moving bar
/// stays visible over a selected run.
enum WidgetState {
  /// The mouse pointer is over the widget. Mouse only — never set by keyboard.
  hover,

  /// The widget is in the chosen set (e.g. a selected list item or checkbox).
  selected,

  /// The widget is the current item — the keyboard cursor position.
  cursor,

  /// The widget owns keyboard input.
  focused,

  /// The widget is performing an async operation.
  loading,

  /// The widget is in an error state (e.g. validation failure).
  error,

  /// The widget is non-interactive — overrides every other state.
  disabled,
}
