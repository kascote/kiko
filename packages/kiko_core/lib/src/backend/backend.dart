import 'package:termparser/termparser_events.dart' as evt;

import '../buffer.dart';
import '../layout/position.dart';
import '../layout/size.dart';

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

/// The set of colors a backend can render.
///
/// Reported by [Backend.profile] and read once at startup to decide how styles
/// are projected: a [noColor] backend re-expresses meaning through modifiers
/// instead of color.
enum ColorProfile {
  /// No color at all. Styles carry meaning through modifiers.
  noColor,

  /// The 16 ANSI colors.
  ansi16,

  /// The 256 color indexed palette.
  ansi256,

  /// 24-bit RGB color.
  trueColor,
}

/// The surface `Terminal` and `Application` use to reach a terminal.
///
/// One implementation talks to a real terminal; another records calls in memory
/// so the render loop can run under `dart test`. Everything above this seam —
/// buffers, widgets, the MVU loop — is written against this interface and never
/// names a concrete backend.
///
/// ## Coordinates
///
/// A backend delivers events in 0-based buffer cells, and accepts draw and
/// cursor calls in 0-based buffer cells. Above the backend there is exactly one
/// coordinate space, the space of `Rect`, [Buffer] and [Position]: the top-left
/// cell is `(0, 0)`.
///
/// Terminals number their cells from 1. That is the private business of a
/// backend that speaks to one, which translates on the way out and on the way
/// in. No caller of this interface ever sees a 1-based coordinate.
abstract interface class Backend {
  /// The current size of the terminal, in cells.
  TermSize size();

  /// Draws the given cells, each addressed by its 0-based buffer position.
  ///
  /// Receives the diff between the previous and the current buffer, so only
  /// the cells that changed are handed over.
  void draw(Iterable<CellPos> cellPos);

  /// Flushes any buffered output.
  void flush();

  /// Clears a region of the screen, relative to the cursor for every
  /// [ClearType] but [ClearType.all].
  void clearRegion(ClearType type);

  /// Inserts [n] new lines at the cursor, scrolling the screen up.
  void insertNewLines(int n);

  /// Hides the cursor.
  void hideCursor();

  /// Shows the cursor.
  void showCursor();

  /// Moves the cursor to [pos], a 0-based buffer position.
  void setCursorPosition(Position pos);

  /// The current cursor position as a 0-based buffer position, or `null` when
  /// the backend cannot report it.
  Future<Position?> getCursorPosition();

  /// Broadcast stream of parsed terminal events.
  ///
  /// Events that carry a position — mouse events — arrive in 0-based buffer
  /// cells, ready to resolve against a `Rect` without further translation.
  Stream<evt.Event> get events;

  /// Reads an event of type [E], waiting up to [timeout] milliseconds.
  ///
  /// Returns `null` if no matching event arrives before the timeout elapses.
  Future<evt.Event?> readEvent<E extends evt.Event>({int timeout = 100});

  /// Polls for an event of type [E] without blocking.
  ///
  /// Returns `null` when no matching event is currently buffered.
  evt.Event? poll<E extends evt.Event>();

  /// Enables the alternate screen buffer.
  void enableAlternateScreen();

  /// Disables the alternate screen buffer.
  void disableAlternateScreen();

  /// Enables raw mode for terminal input.
  void enableRawMode();

  /// Disables raw mode for terminal input.
  void disableRawMode();

  /// Enables mouse event tracking.
  void enableMouseEvents();

  /// Disables mouse event tracking.
  void disableMouseEvents();

  /// Enables the Kitty keyboard enhancement protocol.
  void enableKeyboardEnhancement();

  /// Disables the Kitty keyboard enhancement protocol.
  void disableKeyboardEnhancement();

  /// Enables bracketed paste, so a paste arrives as one paste event.
  void enableBracketedPaste();

  /// Disables bracketed paste.
  void disableBracketedPaste();

  /// Enables focus reporting, so terminal focus in/out arrives as events.
  void enableFocusTracking();

  /// Disables focus reporting.
  void disableFocusTracking();

  /// Sets the terminal title.
  void setTitle(String title);

  /// The set of colors this backend can render.
  ColorProfile get profile;

  /// Flushes any buffered output and then exits the process with [status].
  Future<void> flushThenExit(int status);

  /// Releases the backend's resources.
  Future<void> dispose();
}
