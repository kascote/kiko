import 'dart:async';
import 'dart:math' as math;

import 'package:termparser/termparser_events.dart' as evt;

import '../backend/termlib_backend.dart' show ClearType, TermlibBackend;
import '../buffer.dart';
import '../cell.dart';
import '../extensions/integer.dart';
import '../layout/position.dart';
import '../layout/rect.dart';
import '../layout/size.dart';
import '../widgets/frame.dart';

/// Represents the viewport of the terminal. The viewport is the area of the
/// terminal that is currently visible to the user. It can be either
/// full screen, inline or fixed.
///
/// When the viewport is full screen, the whole terminal is used to draw the
/// application.
///
/// When the viewport is inline, it is drawn inline with the rest of the
/// terminal. The height of the viewport is fixed, but the width is the same
/// as the terminal width.
///
/// When the viewport is fixed, it is drawn in a fixed area of the terminal.
/// The area is specified by a [`Rect`].
sealed class ViewPort {
  const ViewPort();
}

/// A callback that is called to render a widget.
typedef WidgetRenderCallback = void Function(Frame frame);

/// A callback that is called to render a line of the terminal.
typedef RenderLineCallback = void Function(List<Cell> buffer);

/// When the viewport is full screen, the whole terminal is used to draw the
/// application.
class ViewPortFullScreen extends ViewPort {
  /// Creates a new full screen viewport.
  const ViewPortFullScreen();
}

/// When the viewport is inline, it is drawn inline with the rest of the
/// terminal. The height of the viewport is fixed, but the width is the same
/// as the terminal width.
class ViewPortInline extends ViewPort {
  /// The height of the inline viewport.
  final int height;

  /// Creates a new inline viewport with the given height.
  const ViewPortInline(this.height);
}

/// When the viewport is fixed, it is drawn in a fixed area of the terminal.
/// The area is specified by a [`Rect`].
class ViewPortFixed extends ViewPort {
  /// The area of the fixed viewport.
  final Rect area;

  /// Creates a new fixed viewport with the given area.
  const ViewPortFixed(this.area);
}

/// An interface to interact and draw [Frame]s on the user's terminal.
///
/// This is the main entry point for Kiko. It is responsible for drawing and
/// maintaining the state of the buffers, cursor and viewport.
///
/// The [Terminal] is generic over a [TermlibBackend] implementation which is used to
/// interface with the underlying terminal library.
///
/// The [Terminal] maintains two buffers: the current and the previous.
/// When the widgets are drawn, the changes are accumulated in the current
/// buffer. At the end of each draw pass, the two buffers are compared, and
/// only the changes between these buffers are written to the terminal,
/// avoiding any redundant operations. After flushing these changes, the
/// buffers are swapped to prepare for the next draw cycle.
///
/// The terminal also has a viewport which is the area of the terminal that is
/// currently visible to the user. It can be either full screen, inline or
/// fixed. See [ViewPort] for more information.
///
/// Applications should detect terminal resizes and call [Terminal.draw] to
/// redraw the application with the new size. This will automatically resize
/// the internal buffers to match the new size for inline and full screen
/// view ports. Fixed view ports are not resized automatically.
///
class Terminal {
  /// The backend used to interface with the terminal
  late final TermlibBackend backend;

  /// Holds the results of the current and previous draw calls. The two are compared at the end
  /// of each draw pass to output the necessary updates to the terminal
  final _buffers = <Buffer>[];

  /// Index of the current buffer
  int _currentBufferIndex;

  /// Whether the cursor is currently hidden
  bool _hiddenCursor;

  /// Terminal's viewport
  late final ViewPort _viewPort;

  /// Last known position of the cursor. Used to find the new area when the viewport is inlined
  /// and the terminal resized.
  Position _lastKnowCursorPosition;

  /// Area of the viewport
  Rect _viewportArea;

  // Last known area of the terminal. Used to detect if the internal buffers have to be resized.
  Rect _lastKnowArea;

  // Number of frames rendered up until current time.
  int _frameCount;

  Terminal._(
    this.backend, {
    bool hiddenCursor = false,
    ViewPort? viewport,
    Position lastKnowCursorPosition = Position.origin,
    Rect viewportArea = Rect.zero,
  }) : _lastKnowCursorPosition = lastKnowCursorPosition,
       _currentBufferIndex = 0,
       _hiddenCursor = hiddenCursor,
       _frameCount = 0,
       _viewPort = viewport ?? const ViewPortFullScreen(),
       _viewportArea = viewportArea,
       _lastKnowArea = Rect.zero;

  /// Returns the current frame count.
  int get frameCount => _frameCount;

  /// Creates a new [Terminal] with a full screen viewport by default.
  static Future<Terminal> create({
    bool hiddenCursor = false,
    ViewPort viewport = const ViewPortFullScreen(),
    Position lastKnowCursorPosition = Position.origin,
  }) async {
    final backend = TermlibBackend();
    const origin = Position.origin;
    final screenSize = backend.size();
    final area = switch (viewport) {
      ViewPortFullScreen() || ViewPortInline() => Rect.create(
        x: origin.x,
        y: origin.y,
        width: screenSize.width,
        height: screenSize.height,
      ),
      ViewPortFixed(:final area) => area,
    };
    final (viewportArea, cursorPosition) = switch (viewport) {
      ViewPortFullScreen() => (area, origin),
      ViewPortInline(:final height) => await _computeInlineSize(
        backend,
        height,
        area.asSize,
        0,
      ),
      ViewPortFixed(:final area) => (area, area.asPosition),
    };

    final terminal = Terminal._(
      backend,
      hiddenCursor: hiddenCursor,
      viewport: viewport,
      lastKnowCursorPosition: cursorPosition,
      viewportArea: viewportArea,
    );
    terminal._buffers.addAll([
      Buffer.empty(viewportArea),
      Buffer.empty(viewportArea),
    ]);

    return terminal;
  }

  /// Returns the current active buffer
  Buffer get currentBuffer => _buffers[_currentBufferIndex];

  /// Returns whether the cursor is hidden
  bool get hiddenCursor => _hiddenCursor;

  /// Sets the area of the viewport
  set viewportArea(Rect area) {
    _buffers[_currentBufferIndex].resize(area);
    _buffers[1 - _currentBufferIndex].resize(area);
    _viewportArea = area;
  }

  /// Returns the area of the viewport
  Rect get viewportArea => _viewportArea;

  /// Returns the size of the terminal
  Size get size => backend.size();

  /// Returns the current frame
  Frame getFrame() => Frame(
    _viewportArea,
    currentBuffer,
    _frameCount,
  );

  /// Obtains a difference between the previous and the current buffer and
  /// passes it to the current backend for drawing.
  void flush() {
    final prevBuffer = _buffers[1 - _currentBufferIndex];
    final currentBuffer = _buffers[_currentBufferIndex];
    final diff = prevBuffer.diff(currentBuffer);
    if (diff.isNotEmpty) {
      final last = diff.last;
      _lastKnowCursorPosition = Position(last.x, last.y);
    }
    backend.draw(diff);
  }

  /// Updates the Terminal so that internal buffers match the requested area.
  ///
  /// Requested area will be saved to remain consistent when rendering. This
  /// leads to a full clear of the screen.
  Future<void> resize(Rect area) async {
    final nextArea = switch (_viewPort) {
      ViewPortFullScreen() || ViewPortFixed() => area,
      ViewPortInline(:final height) => await _computeSize(this, area, height),
    };

    viewportArea = nextArea;
    clear();
    _lastKnowArea = area;
  }

  /// Queries the backend for size and resizes if it doesn't match the
  /// previous size.
  void autoResize() {
    switch (_viewPort) {
      case ViewPortFullScreen() || ViewPortInline():
        const origin = Position.origin;
        final size = this.size;
        final area = Rect.create(
          x: origin.x,
          y: origin.y,
          width: size.width,
          height: size.height,
        );
        if (_lastKnowArea != area) unawaited(resize(area));
      default:
        return;
    }
  }

  /// Draws a single frame to the terminal.
  ///
  /// Returns a [CompletedFrame] if successful.
  ///
  /// Applications should call [draw] in a loop to continuously render the
  /// terminal. These methods are the main entry points for drawing to the
  /// terminal.
  CompletedFrame draw(WidgetRenderCallback renderCallback) {
    autoResize();
    final frame = getFrame();
    renderCallback(frame);

    final cursorPosition = frame.cursorPosition;
    flush();
    if (cursorPosition != null) {
      backend
        ..showCursor()
        ..setCursorPosition(cursorPosition);
    }

    swapBuffers();
    backend.flush();

    final completedFrame = CompletedFrame(
      _buffers[1 - _currentBufferIndex],
      _lastKnowArea,
      _frameCount,
    );

    _frameCount = _frameCount.wrappingAddU32(1);
    return completedFrame;
  }

  /// Hides the cursor
  void hideCursor() {
    backend.hideCursor();
    _hiddenCursor = true;
  }

  /// Shows the cursor
  void showCursor() {
    backend.showCursor();
    _hiddenCursor = false;
  }

  /// Reads an event from the Terminal
  Future<evt.Event> readEvent<E extends evt.Event>({int timeout = 100}) async => backend.readEvent<E>(timeout: timeout);

  /// Polls for a terminal event without blocking.
  evt.Event poll<E extends evt.Event>() => backend.poll<E>();

  /// Broadcast stream of parsed terminal events.
  ///
  /// Provides push-based event delivery for subscribers.
  Stream<evt.Event> get events => backend.events;

  /// Flush the stdout and stderr buffers and exits the application
  Future<void> flushThenExit(int status) async => backend.flushThenExit(status);

  /// Queries the backend for the current cursor position
  Future<Position?> getCursorPosition() => backend.getCursorPosition();

  /// Sets the cursor position
  void setCursorPosition(Position position) {
    backend.setCursorPosition(position);
    _lastKnowCursorPosition = position;
  }

  /// Clears the terminal
  void clear() {
    switch (_viewPort) {
      case ViewPortFullScreen():
        backend.clearRegion(ClearType.all);
      case ViewPortInline():
        backend.setCursorPosition(_viewportArea.asPosition);
        backend.clearRegion(ClearType.afterCursor);
      case ViewPortFixed(:final area):
        final top = area.top;
        final bottom = area.bottom;
        for (var y = top; y < bottom; y++) {
          backend
            ..setCursorPosition(Position(0, y))
            ..clearRegion(ClearType.afterCursor);
        }
    }
    // Reset the back buffer to make sure the next update will redraw everything
    _buffers[1 - _currentBufferIndex].reset();
  }

  /// Swaps the current and previous buffers
  void swapBuffers() {
    _buffers[1 - _currentBufferIndex].reset();
    _currentBufferIndex = 1 - _currentBufferIndex;
  }

  /// Inserts a new line at the current cursor position
  void insertBefore(int height, RenderLineCallback drawFn) {
    if (_viewPort is! ViewPortInline) return;

    final area = Rect.create(
      x: 0,
      y: 0,
      width: _viewportArea.width,
      height: height,
    );
    var buffer = Buffer.empty(area).buf;
    drawFn(buffer);

    var drawHeight = _viewportArea.top;
    var bufferHeight = height;
    final viewportHeight = _viewportArea.height;
    final screenHeight = _lastKnowArea.height;

    while (bufferHeight + viewportHeight > screenHeight) {
      final toDraw = math.min(bufferHeight, screenHeight);
      final toScrollUp = math.max(0, drawHeight + toDraw - screenHeight);
      scrollUp(toScrollUp);
      buffer = drawLines(drawHeight - toScrollUp, toDraw, buffer);
      drawHeight += toDraw - toScrollUp;
      bufferHeight -= toDraw;
    }

    final toScrollUp = math.max(
      0,
      drawHeight + bufferHeight + viewportHeight - screenHeight,
    );
    scrollUp(toScrollUp);
    drawLines(drawHeight - toScrollUp, bufferHeight, buffer);
    drawHeight += bufferHeight - toScrollUp;

    viewportArea = _viewportArea.copyWith(y: drawHeight);

    clear();
  }

  /// Draws the lines of the buffer to the terminal
  List<Cell> drawLines(int yOffset, int linesToDraw, List<Cell> cells) {
    final width = _lastKnowArea.width;
    final lines = width * linesToDraw;
    final toDraw = cells.sublist(0, lines);
    final remainder = cells.sublist(lines);
    if (linesToDraw > 0) {
      final cells = List.generate(toDraw.length, (i) {
        final x = i % width;
        final y = yOffset + i ~/ width;
        return (x: x, y: y, cell: toDraw[i]);
      });

      backend
        ..draw(cells)
        ..flush();
    }
    return remainder;
  }

  /// Scrolls the terminal up by the given number of lines
  void scrollUp(int linesToScroll) {
    if (linesToScroll < 0) return;

    setCursorPosition(Position(0, _lastKnowArea.height.saturatingSubU16(1)));
    backend.insertNewLines(linesToScroll);
  }

  /// Enables the alternate screen
  void enableAlternateScreen() => backend.enableAlternateScreen();

  /// Disables the alternate screen
  void disableAlternateScreen() => backend.disableAlternateScreen();

  /// Enables raw mode
  void enableRawMode() => backend.enableRawMode();

  /// Disables raw mode
  void disableRawMode() => backend.disableRawMode();

  /// Enables mouse event tracking
  void enableMouseEvents() => backend.enableMouseEvents();

  /// Disables mouse event tracking
  void disableMouseEvents() => backend.disableMouseEvents();

  /// Enables Kitty keyboard enhancement protocol
  void enableKeyboardEnhancement() => backend.enableKeyboardEnhancement();

  /// Disables Kitty keyboard enhancement protocol
  void disableKeyboardEnhancement() => backend.disableKeyboardEnhancement();

  /// Sets the terminal title
  void setTitle(String title) => backend.setTitle(title);

  /// Disposes terminal resources
  Future<void> dispose() => backend.dispose();
}

Future<Rect> _computeSize(Terminal t, Rect area, int height) async {
  final offsetInPreviousViewport = t._lastKnowCursorPosition.y.saturatingSubU16(t._lastKnowArea.top);
  return (await _computeInlineSize(
    t.backend,
    height,
    area.asSize,
    offsetInPreviousViewport,
  )).$1;
}

Future<(Rect, Position)> _computeInlineSize(
  TermlibBackend backend,
  int height,
  Size size,
  int offsetInPreviousViewport,
) async {
  // TODO(nelson): we need to review this. If for some reason we can't get the cursor position,
  // is there a way to get an educated guess ?
  final pos = await backend.getCursorPosition() ?? Position.origin;
  var row = pos.y;
  final maxHeight = math.min(size.height, height);
  final linesAfterCursor = height.saturatingSubU16(offsetInPreviousViewport).saturatingSubU16(1);

  backend.insertNewLines(linesAfterCursor);

  final availableLines = size.height.saturatingSubU16(row).saturatingSubU16(1);
  final missingLines = linesAfterCursor.saturatingSubU16(availableLines);
  if (missingLines > 0) row = row.saturatingSubU16(missingLines);
  row = row.saturatingSubU16(offsetInPreviousViewport);

  return (Rect.create(x: 0, y: row, width: size.width, height: maxHeight), pos);
}
