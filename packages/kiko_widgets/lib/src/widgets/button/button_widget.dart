import 'package:kiko/kiko.dart';

import 'button_model.dart';

/// A single-line focusable button widget.
///
/// Stateless widget that renders from [ButtonModel]. The model holds all
/// state and config; this widget just renders.
///
/// Styles are resolved via [StyleResolver] from the [theme], with
/// button-specific defaults (e.g. focused = primary inverted).
/// Use [styleOverrides] to customize per-state styles.
class Button extends Widget {
  /// The model containing state and config.
  final ButtonModel model;

  /// Theme for deriving styles.
  final Theme theme;

  /// Optional per-state style overrides.
  ///
  /// Fully replaces the default style for that [WidgetState].
  final Map<WidgetState, Style>? styleOverrides;

  /// Creates a Button widget.
  Button(this.model, {required this.theme, this.styleOverrides});

  /// Resolves the button style from theme + model state + overrides.
  Style _resolveStyle() {
    final resolver = StyleResolver(theme);
    final states = <WidgetState>{
      if (model.focused) WidgetState.focused,
      if (model.disabled) WidgetState.disabled,
      if (model.loading) WidgetState.loading,
    };

    // Button-specific defaults override resolver's generic defaults.
    final widgetDefaults = {
      WidgetState.focused: theme.primary.inverted,
      WidgetState.loading: theme.warning.inverted,
    };

    return resolver.resolve(
      theme.surface.inverted,
      states,
      overrides: {...widgetDefaults, ...?styleOverrides},
    );
  }

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final buf = frame.buffer;
    final renderArea = area.intersection(buf.area);
    if (renderArea.isEmpty) return;

    final m = model;
    final style = _resolveStyle();

    // Calculate the button width
    final buttonWidth = m.width.clamp(0, renderArea.width);
    final buttonArea = renderArea.copyWith(width: buttonWidth, height: 1);

    // Fill background
    buf.setStyle(buttonArea, style);

    // Render content
    if (m.loading) {
      // Render loading text centered, preserving user styles
      m.loadingText.patchStyle(style).copyWith(alignment: Alignment.center).render(buttonArea, frame);
    } else {
      // Render label with padding
      final contentArea = buttonArea.copyWith(x: buttonArea.x + m.padding);
      m.label.patchStyle(style).render(contentArea, frame);
    }
  }
}
