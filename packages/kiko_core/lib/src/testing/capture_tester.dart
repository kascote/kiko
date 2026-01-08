import '../buffer.dart';
import '../layout/rect.dart';
import '../widgets/frame.dart';

/// Tester object provided to capture callbacks.
///
/// Provides access to frame, buffer, and area for rendering widgets.
class CaptureTester {
  /// The render area.
  final Rect area;

  /// The frame for rendering.
  final Frame frame;

  /// The underlying buffer.
  Buffer get buffer => frame.buffer;

  /// Creates a new [CaptureTester].
  CaptureTester({required this.area, required this.frame});

  /// Render a widget to the test buffer.
  void render(Widget widget, [Rect? renderArea]) {
    widget.render(renderArea ?? area, frame);
  }

  /// Render a widget using frame.renderWidget().
  void renderWidget(Widget widget, [Rect? renderArea]) {
    frame.renderWidget(widget, renderArea ?? area);
  }
}
