// coverage:ignore-file
//
import '../buffer.dart';
import '../layout/position.dart';
import '../layout/rect.dart';

/// A widget that can be rendered in a buffer.
// ignore: one_member_abstracts
abstract class Widget {
  /// Renders the widget in the given area of the buffer.
  void render(Rect area, Buffer buffer);
}

/// A consistent view into the terminal state for rendering a single frame.
///
/// This is obtained via the closure argument of [Terminal.draw()]. It is used to
/// render widgets to the terminal and control the cursor position.
///
/// The changes drawn to the frame are applied only to the current [Buffer].
/// After the closure returns, the current buffer is compared to the previous
/// buffer and only the changes are applied to the terminal. This avoids
/// drawing redundant cells.
class Frame {
  /// Where should the cursor be after drawing this frame?
  ///
  /// If `null`, the cursor is hidden and its position is controlled by the
  /// backend. If has value, the cursor is shown and placed at `(x, y)` after
  /// the call to `Terminal.draw()`
  Position? cursorPosition;

  /// The area of the viewport
  final Rect area;

  /// The buffer that is used to draw the current frame
  final Buffer buffer;

  /// The frame count indicating the sequence number of this frame
  final int count;

  /// Creates a new frame with the given area and buffer.
  Frame(this.area, this.buffer, this.count);

  /// Renders a widget in the given area of the frame.
  void renderWidget(Widget widget, Rect area) {
    widget.render(area, buffer);
  }
}

/// [CompletedFrame] represents the state of the terminal after all changes
/// performed in the last [Terminal.draw()] call have been applied. Therefore,
/// it is only valid until the next call to [Terminal.draw()].
class CompletedFrame {
  /// The buffer that was used to draw the last frame
  final Buffer buffer;

  /// The size of the last frame
  final Rect area;

  /// The frame count indicating the sequence number of this frame
  final int count;

  /// Creates a new completed frame with the given area and buffer.
  const CompletedFrame(this.buffer, this.area, this.count);
}
