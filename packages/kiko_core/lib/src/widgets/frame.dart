// coverage:ignore-file
//
import '../buffer.dart';
import '../cell.dart';
import '../layout/constraint.dart';
import '../layout/position.dart';
import '../layout/rect.dart';

/// A widget that can be rendered in a frame.
// ignore: one_member_abstracts
abstract class Widget {
  /// Renders the widget in the given area of the frame.
  void render(Rect area, Frame frame);
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
    widget.render(area, this);
  }

  /// Renders a widget centered in the frame with the given size constraints.
  ///
  /// This is a helper for modal rendering. The caller should ensure the
  /// backdrop is restored before calling this method.
  void renderModal({
    required Widget child,
    required Constraint width,
    required Constraint height,
  }) {
    final modalWidth = _resolveConstraint(width, area.width);
    final modalHeight = _resolveConstraint(height, area.height);

    // Center the modal in the frame
    final x = area.x + (area.width - modalWidth) ~/ 2;
    final y = area.y + (area.height - modalHeight) ~/ 2;

    final modalArea = Rect.create(
      x: x,
      y: y,
      width: modalWidth,
      height: modalHeight,
    );

    // Clear the modal area to make it opaque
    for (var py = modalArea.top; py < modalArea.bottom; py++) {
      for (var px = modalArea.left; px < modalArea.right; px++) {
        buffer[(x: px, y: py)] = Cell.empty();
      }
    }

    renderWidget(child, modalArea);
  }

  /// Dims all cell colors in the buffer toward black.
  ///
  /// Used to create a backdrop effect for modals.
  ///
  /// Note: This always performs the dim operation regardless of terminal
  /// profile. For noColor terminals, the dimmed RGB values are computed but
  /// ignored at render time. If this becomes a perf issue, could check
  /// `Platform.environment['NO_COLOR']` directly, but prefer letting termlib
  /// handle profile detection consistently.
  void dimBackdrop({double factor = 0.3}) {
    for (var i = 0; i < buffer.buf.length; i++) {
      final cell = buffer.buf[i];
      buffer.buf[i] = cell.copyWith(
        fg: cell.fg.dim(factor: factor),
        bg: cell.bg.dim(factor: factor, isBackground: true),
      );
    }
  }
}

/// Resolves a constraint to an actual size given available space.
int _resolveConstraint(Constraint constraint, int available) {
  return switch (constraint) {
    ConstraintLength(:final value) => value.clamp(0, available),
    ConstraintPercent(:final value) => (available * value ~/ 100).clamp(0, available),
    ConstraintRatio(:final numerator, :final denominator) => (available * numerator ~/ denominator).clamp(0, available),
    ConstraintMin(:final value) => value.clamp(0, available),
    ConstraintMax(:final value) => value.clamp(0, available),
    ConstraintFill(:final value) => (available * value).clamp(0, available),
  };
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
