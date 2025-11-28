import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:termparser/termparser_events.dart' as evt;

import '../backend/backend.dart';
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
/// The [Terminal] is generic over a [Backend] implementation which is used to
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
class Terminal<T extends Backend> {
  /// The backend used to interface with the terminal
  T backend;

  /// Holds the results of the current and previous draw calls. The two are compared at the end
  /// of each draw pass to output the necessary updates to the terminal
  final buffers = <Buffer>[];

  /// Index of the current buffer
  int current;

  /// Whether the cursor is currently hidden
  bool hiddenCursor;

  /// Terminal's viewport
  ViewPort viewport = const ViewPortFullScreen();

  /// Last known position of the cursor. Used to find the new area when the viewport is inlined
  /// and the terminal resized.
  Position lastKnowCursorPosition;

  /// Area of the viewport
  Rect _viewportArea;

  // Last known area of the terminal. Used to detect if the internal buffers have to be resized.
  Rect _lastKnowArea;

  // Number of frames rendered up until current time.
  int _frameCount;

  final Logger? _logger;

  Terminal._(
    this.backend, {
    this.hiddenCursor = false,
    this.viewport = const ViewPortFullScreen(),
    this.lastKnowCursorPosition = Position.origin,
    Rect viewportArea = Rect.zero,
    Logger? logger,
  }) : current = 0,
       _frameCount = 0,
       _viewportArea = viewportArea,
       _lastKnowArea = Rect.zero,
       _logger = logger;

  /// Returns the current frame count.
  int get frameCount => _frameCount;

  /// Creates a new [Terminal] with the given [Backend] with a full screen
  /// viewport by default.
  static Future<Terminal<T>> create<T extends Backend>(
    T backend, {
    bool hiddenCursor = false,
    ViewPort viewport = const ViewPortFullScreen(),
    Position lastKnowCursorPosition = Position.origin,
    Logger? logger,
  }) async {
    const origin = Position.origin;
    final area = switch (viewport) {
      ViewPortFullScreen() || ViewPortInline() => Rect.create(
        x: origin.x,
        y: origin.y,
        width: backend.size().width,
        height: backend.size().height,
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

    if (logger == null) {
      logger = Logger('Terminal');
      PrintAppender.setupLogging(stderrLevel: Level.ALL);
    }

    logger.finest('viewport $viewportArea');

    final terminal = Terminal._(
      backend,
      hiddenCursor: hiddenCursor,
      viewport: viewport,
      lastKnowCursorPosition: cursorPosition,
      viewportArea: viewportArea,
      logger: logger,
    );
    terminal.buffers.addAll([
      Buffer.empty(viewportArea),
      Buffer.empty(viewportArea),
    ]);

    return terminal;
  }

  /// Returns the current active buffer
  Buffer get currentBuffer => buffers[current];

  /// Sets the area of the viewport
  set viewportArea(Rect area) {
    buffers[current].resize(area);
    buffers[1 - current].resize(area);
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
    final prevBuffer = buffers[1 - current];
    final currentBuffer = buffers[current];
    final diff = prevBuffer.diff(currentBuffer);
    if (diff.isNotEmpty) {
      final last = diff.last;
      lastKnowCursorPosition = Position(last.x, last.y);
    }
    backend.draw(diff);
  }

  /// Updates the Terminal so that internal buffers match the requested area.
  ///
  /// Requested area will be saved to remain consistent when rendering. This
  /// leads to a full clear of the screen.
  Future<void> resize(Rect area) async {
    final nextArea = switch (viewport) {
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
    switch (viewport) {
      case ViewPortFullScreen() || ViewPortInline():
        const origin = Position.origin;
        final size = this.size;
        final area = Rect.create(
          x: origin.x,
          y: origin.y,
          width: size.width,
          height: size.height,
        );
        if (_lastKnowArea != area) resize(area);
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
      buffers[1 - current],
      _lastKnowArea,
      _frameCount,
    );

    _frameCount = _frameCount.wrappingAdd(1);
    return completedFrame;
  }

  /// Hides the cursor
  void hideCursor() {
    backend.hideCursor();
    hiddenCursor = true;
  }

  /// Shows the cursor
  void showCursor() {
    backend.showCursor();
    hiddenCursor = false;
  }

  /// Reads an event from the Terminal
  Future<evt.Event> readEvent<E extends evt.Event>({int timeout = 100}) async => backend.readEvent<E>(timeout: timeout);

  /// Flush the stdout and stderr buffers and exits the application
  Future<void> flushThenExit(int status) async => backend.flushThenExit(status);

  /// Queries the backend for the current cursor position
  Future<Position?> getCursorPosition() => backend.getCursorPosition();

  /// Sets the cursor position
  void setCursorPosition(Position position) {
    backend.setCursorPosition(position);
    lastKnowCursorPosition = position;
  }

  /// Clears the terminal
  void clear() {
    switch (viewport) {
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
    buffers[1 - current].reset();
  }

  /// Swaps the current and previous buffers
  void swapBuffers() {
    buffers[1 - current].reset();
    current = 1 - current;
  }

  /// Inserts a new line at the current cursor position
  void insertBefore(int height, RenderLineCallback drawFn) {
    if (viewport is! ViewPortInline) return;

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

    setCursorPosition(Position(0, _lastKnowArea.height.saturatingSub(1)));
    backend.insertNewLines(linesToScroll);
  }

  /// Logs a message
  void log(Level level, Object value) => _logger?.log(level, value);

  /// Enables the alternate screen
  void enableAlternateScreen() => backend.enableAlternateScreen();

  /// Disables the alternate screen
  void disableAlternateScreen() => backend.disableAlternateScreen();

  /// Enables raw mode
  void enableRawMode() => backend.enableRawMode();

  /// Disables raw mode
  void disableRawMode() => backend.disableRawMode();
}

Future<Rect> _computeSize(Terminal t, Rect area, int height) async {
  final offsetInPreviousViewport = t.lastKnowCursorPosition.y.saturatingSub(
    t._lastKnowArea.top,
  );
  return (await _computeInlineSize(
    t.backend,
    height,
    area.asSize,
    offsetInPreviousViewport,
  )).$1;
}

Future<(Rect, Position)> _computeInlineSize(
  Backend backend,
  int height,
  Size size,
  int offsetInPreviousViewport,
) async {
  final pos = await backend.getCursorPosition();
  var row = pos!.y;
  final maxHeight = math.min(size.height, height);
  final linesAfterCursor = height.saturatingSub(offsetInPreviousViewport).saturatingSub(1);

  backend.insertNewLines(linesAfterCursor);

  final availableLines = size.height.saturatingSub(row).saturatingSub(1);
  final missingLines = linesAfterCursor.saturatingSub(availableLines);
  if (missingLines > 0) row = row.saturatingSub(missingLines);
  row = row.saturatingSub(offsetInPreviousViewport);

  return (Rect.create(x: 0, y: row, width: size.width, height: maxHeight), pos);
}
