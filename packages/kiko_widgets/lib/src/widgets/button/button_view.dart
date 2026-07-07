import 'package:kiko/kiko.dart';

import 'button_model.dart';

/// A button as a view — the plume-native view for [ButtonModel].
///
/// A button is a single filled row: the resolved style paints the whole width,
/// the label sits inside a symmetric horizontal [ButtonModel.padding], and the
/// built subtree is stamped with the model's id so a click resolves back to it
/// through [Frame.hitId]. Styles come from the [theme] and the model's state
/// (focused / disabled / loading), with the same button defaults the old widget
/// used; [styleOverrides] fully replaces the style for a given state.
///
/// The content area is pinned to the label's width so the button keeps its size
/// while loading, when the [ButtonModel.loadingText] indicator sits in that same
/// width instead of the label.
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
/// overrides, mirroring the button defaults (focused → primary fill,
/// loading → warning fill) over a base of the surface fill.
Style _resolveStyle(ButtonModel model, Theme theme, Map<WidgetState, Style>? styleOverrides) {
  final resolver = StyleResolver(theme);
  final states = <WidgetState>{
    if (model.focused) WidgetState.focused,
    if (model.disabled) WidgetState.disabled,
    if (model.loading) WidgetState.loading,
  };
  final widgetDefaults = <WidgetState, Style>{
    WidgetState.focused: theme.primary.fill,
    WidgetState.loading: theme.warning.fill,
  };
  return resolver.resolve(
    theme.surface.fill,
    states,
    overrides: <WidgetState, Style>{...widgetDefaults, ...?styleOverrides},
  );
}
