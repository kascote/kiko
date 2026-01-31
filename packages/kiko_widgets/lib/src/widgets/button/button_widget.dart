import 'package:kiko/kiko.dart';

import 'button_model.dart';

/// A single-line focusable button widget.
///
/// Stateless widget that renders from [ButtonModel]. The model holds all
/// state and config; this widget just renders.
class Button extends Widget {
  /// The model containing state and config.
  final ButtonModel model;

  /// Creates a Button widget.
  Button(this.model);

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final buf = frame.buffer;
    final renderArea = area.intersection(buf.area);
    if (renderArea.isEmpty) return;

    final m = model;
    final style = m.currentStyle ?? const Style();

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
