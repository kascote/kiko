/// Visual states a widget can be in.
///
/// Priority order: later values override earlier when resolving styles.
/// For example, [disabled] overrides [focused] if both are active.
enum WidgetState {
  /// Mouse is hovering over the widget.
  hover,

  /// Widget has keyboard focus.
  focused,

  /// Widget is selected (e.g. list item, checkbox).
  selected,

  /// Widget's parent lost focus (dimmed state).
  unfocused,

  /// Widget is non-interactive.
  disabled,

  /// Widget is performing an async operation.
  loading,

  /// Widget is in an error state (e.g. validation failure).
  error,
}
