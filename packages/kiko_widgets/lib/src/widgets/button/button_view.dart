import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

import 'button_model.dart';

/// Builds a button as a plume node — the plume-native view for [ButtonModel].
///
/// A button is a single filled row: the resolved style paints the whole width,
/// the label sits inside a symmetric horizontal [ButtonModel.padding], and the
/// subtree root is stamped with the model's id so a click resolves back to it
/// through [Frame.hitId]. Styles come from the [theme] and the model's state
/// (focused / disabled / loading), with the same button defaults the old widget
/// used; [styleOverrides] fully replaces the style for a given state.
///
/// The content area is pinned to the label's width so the button keeps its size
/// while loading, when the [ButtonModel.loadingText] indicator is centred in
/// that same width instead of the label.
plume.RenderNode<PaintToken> button(ButtonModel model, Theme theme, {Map<WidgetState, Style>? styleOverrides}) {
  final style = _resolveStyle(model, theme, styleOverrides);
  final labelWidth = model.label.width;
  final content = model.loading
      ? model.loadingText.patchStyle(style).copyWith(alignment: Alignment.center)
      : model.label.patchStyle(style);

  return box(
    background: style,
    padding: plume.EdgeInsets.symmetric(horizontal: model.padding),
    child: plume.ConstrainedBox<PaintToken>(
      additionalConstraints: plume.BoxConstraints(minW: labelWidth, maxW: labelWidth, minH: 1, maxH: 1),
      child: lineNode(content),
    ),
  )..tag = model.id;
}

/// Resolves the button style from the theme, the model's active states, and any
/// overrides, mirroring the button defaults (focused → primary inverted,
/// loading → warning inverted) over a base of the inverted surface.
Style _resolveStyle(ButtonModel model, Theme theme, Map<WidgetState, Style>? styleOverrides) {
  final resolver = StyleResolver(theme);
  final states = <WidgetState>{
    if (model.focused) WidgetState.focused,
    if (model.disabled) WidgetState.disabled,
    if (model.loading) WidgetState.loading,
  };
  final widgetDefaults = <WidgetState, Style>{
    WidgetState.focused: theme.primary.inverted,
    WidgetState.loading: theme.warning.inverted,
  };
  return resolver.resolve(
    theme.surface.inverted,
    states,
    overrides: <WidgetState, Style>{...widgetDefaults, ...?styleOverrides},
  );
}
