import 'package:kiko/kiko.dart';

import 'button_model.dart';

/// A button as a view — the plume-native view for [ButtonModel].
///
/// A button is a single filled row: the resolved style paints the whole width,
/// the label sits inside a symmetric horizontal [ButtonModel.padding], and the
/// built subtree is stamped with the model's id so a click resolves back to it
/// through [HitMap.hitId]. Styles come from the [theme] and the model's state
/// (focused / disabled / loading) through the built-in matrix over a primary
/// resting face; [styleOverrides] fully replaces the style for a given state.
///
/// The content area is pinned to the label's width so the button keeps its size
/// while loading, when the [ButtonModel.loadingText] indicator sits in that same
/// width instead of the label.
///
/// A button is a primary action, so its resting face is `theme.primary.fill`.
/// Its states then ride the built-in state × class matrix (via [StyleResolver])
/// rather than per-widget overrides: focused → `theme.focus.fill` + bold,
/// loading → warning ink + slow blink, disabled → dim. Passing a
/// [styleOverrides] entry for a state replaces that state's contribution.
final class Button implements View {
  /// Creates a button over [model], styled by [theme].
  const Button({required this.model, required this.theme, this.styleOverrides});

  /// The model whose label, state, and padding this view renders.
  final ButtonModel model;

  /// The theme that resolves the button's styles.
  final Theme theme;

  /// Per-state style overrides that fully replace the resolved style for a state.
  final Map<WidgetState, Style>? styleOverrides;

  @override
  Node build() {
    final style = _resolveStyle(model, theme, styleOverrides);
    final labelWidth = model.label.width;
    final content = model.loading ? model.loadingText.patchStyle(style) : model.label.patchStyle(style);

    return Box(
      background: style,
      padding: EdgeInsets.symmetric(horizontal: model.padding),
      child: ConstrainedBox(
        additionalConstraints: BoxConstraints(minW: labelWidth, maxW: labelWidth, minH: 1, maxH: 1),
        child: content,
      ),
    ).build()..tag = model.id;
  }
}

/// Resolves the button style from the theme, the model's active states, and any
/// overrides: a resting face of `theme.primary.fill` (a button is a primary
/// action) with the state contributions coming straight from the built-in
/// matrix, so a focused button lights up in the focus tone and a loading one
/// blinks — no per-widget default overrides to keep in sync with the doctrine.
Style _resolveStyle(ButtonModel model, Theme theme, Map<WidgetState, Style>? styleOverrides) {
  final resolver = StyleResolver(theme);
  final states = <WidgetState>{
    if (model.focused) WidgetState.focused,
    if (model.disabled) WidgetState.disabled,
    if (model.loading) WidgetState.loading,
  };
  return resolver.resolve(theme.primary.fill, states, overrides: styleOverrides);
}
