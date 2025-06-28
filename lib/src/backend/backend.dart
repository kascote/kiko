import 'package:termparser/termparser_events.dart' as evt;

import '../buffer.dart';
import '../layout/position.dart';
import '../layout/size.dart';
import '../terminal/terminal.dart';

/// The [ClearType] enum defines the different ways to clear the terminal screen.
enum ClearType {
  /// Clears the entire screen
  all,

  /// Clears everything below the cursor
  afterCursor,

  /// Clears everything above the cursor
  beforeCursor,

  /// Clears the current line
  currentLine,

  /// Clears the line from the cursor position
  untilNewLine,
}

/// The [Backend] class provides an abstraction over different terminal
/// libraries. It defines the methods required to draw content, manipulate
/// the cursor, and clear the terminal screen.
///
/// Most applications should not need to interact with the [Backend] directly
/// as the [Terminal] class provides a higher level interface for interacting
/// with the terminal
abstract class Backend {
  /// Draw the current cell to the given position.
  void draw(Iterable<CellPos> cellPos);

  /// Insert `n` line breaks to the terminal screen.
  void insertNewLines(int n);

  /// Hide the cursor.
  void hideCursor();

  /// Show the cursor.
  void showCursor();

  /// Get the cursor position.
  Future<Position?> getCursorPosition();

  /// Sets the cursor position.
  void setCursorPosition(Position pos);

  /// Clear the screen
  void clear();

  /// Clear a region of the screen
  void clearRegion(ClearType type);

  /// Get the size of the screen
  Size size();

  /// Flush the buffer to the terminal
  void flush();

  /// Enable the alternate screen buffer
  void enableAlternateScreen();

  /// Disable the alternate screen buffer
  void disableAlternateScreen();

  /// Enable raw mode
  void enableRawMode();

  /// Disable raw mode
  void disableRawMode();

  /// Read an event from the terminal
  Future<evt.Event> readEvent<T extends evt.Event>({int timeout = 100});

  /// Flush the buffer to the terminal and exit the application
  Future<void> flushThenExit(int status);
}
