import 'package:kiko/kiko.dart';
import 'package:termlib/termlib.dart' as tl;
import 'package:termparser/termparser_events.dart' as tle;

export 'package:termlib/termlib.dart' show ProfileEnum;

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

/// A Backend implementation that uses the [termlib](https://pub.dev/packages/termlib) library.
class TermlibBackend {
  final tl.InteractiveTerm _term;

  /// Creates a new [TermlibBackend] instance.
  ///
  /// Requires an interactive terminal (stdin connected to a TTY): the render
  /// loop relies on raw mode, parsed events and cursor queries, which only
  /// exist on [tl.InteractiveTerm].
  TermlibBackend() : _term = _openInteractive();

  static tl.InteractiveTerm _openInteractive() {
    final term = tl.Term.open();
    if (term is tl.InteractiveTerm) return term;
    throw StateError('TermlibBackend requires an interactive terminal (stdin must be a TTY).');
  }

  /// Erase the entire screen.
  void clear() => _term.eraseScreen();

  /// Clears a region of the terminal based on the specified [ClearType].
  void clearRegion(ClearType type) {
    return switch (type) {
      ClearType.all => _term.eraseScreen(),
      ClearType.afterCursor => _term.eraseDown(),
      ClearType.beforeCursor => _term.eraseUp(),
      ClearType.currentLine => _term.eraseLine(),
      ClearType.untilNewLine => _term.eraseLineFromCursor(),
    };
  }

  /// Draws the given [cellPos] iterable to the terminal.
  ///
  /// Consecutive, screen-adjacent cells that share the same style are batched
  /// into one styled run. Each run is rendered through an immutable [tl.Style],
  /// which self-closes with an SGR reset, so a cell whose colors are
  /// [Color.reset] omits them and falls back to the terminal default instead of
  /// inheriting the previous run's style. The trailing reset is a safety net to
  /// keep styling from leaking past the frame.
  void draw(Iterable<CellPos> cellPos) {
    final run = StringBuffer();
    tl.Style? runStyle;
    Position? lastPos;

    void flush() {
      if (run.isEmpty) return;
      _term.write(runStyle!(run.toString()));
      run.clear();
    }

    _term.startSyncUpdate();
    for (final (:x, :y, :cell) in cellPos) {
      final style = _styleFor(cell);
      // Adjacent means the cursor is already where this cell should be drawn
      // (one column right of the previously emitted cell on the same row).
      final adjacent = lastPos != null && x == lastPos.x + 1 && y == lastPos.y;

      if (run.isNotEmpty && adjacent && style == runStyle) {
        run.write(cell.symbol);
      } else {
        flush();
        if (!adjacent) {
          // base terminal coordinates are 1 based, KiKo is 0 based
          _term.moveTo(y + 1, x + 1);
        }
        runStyle = style;
        run.write(cell.symbol);
      }
      lastPos = Position(x, y);
    }
    flush();

    _term
      ..write('\x1b[0m')
      ..endSyncUpdate();
  }

  /// Builds the immutable [tl.Style] for [cell], translating Kiko colors and
  /// modifiers into termlib's representation for the active color profile.
  tl.Style _styleFor(Cell cell) {
    final modifier = cell.modifier;
    final underlineColor = cell.underline;
    final hasUnderlineColor = underlineColor.value >= 0;

    return _term.style(
      fg: _resolveColor(cell.fg),
      bg: _resolveColor(cell.bg),
      bold: modifier.has(Modifier.bold),
      faint: modifier.has(Modifier.dim),
      italic: modifier.has(Modifier.italic),
      blink: modifier.has(Modifier.slowBlink) || modifier.has(Modifier.rapidBlink),
      reverse: modifier.has(Modifier.reversed),
      crossOut: modifier.has(Modifier.crossedOut),
      underline: modifier.has(Modifier.underlined) || hasUnderlineColor ? tl.Underline.single : tl.Underline.none,
      underlineColor: hasUnderlineColor ? _toTlColor(underlineColor) : null,
    );
  }

  /// Flushes any buffered output to the terminal.
  void flush() {
    // noop
  }

  /// Gets the current cursor position in the terminal.
  Future<Position?> getCursorPosition() async {
    final pos = await _term.cursorPosition;
    if (pos == null) return null;
    // base terminal coordinates are 1 based, KiKo is 0 based
    return Position(pos.col - 1, pos.row - 1);
  }

  /// Hides the terminal cursor.
  void hideCursor() => _term.cursorHide();

  /// Inserts [n] new lines at the current cursor position.
  void insertNewLines(int n) {
    for (var i = 0; i < n; i++) {
      _term.write('\n');
    }
  }

  /// Sets the cursor position to the specified [pos].
  void setCursorPosition(Position pos) => _term.moveTo(pos.y + 1, pos.x + 1);

  /// Shows the terminal cursor.
  void showCursor() => _term.cursorShow();

  /// Gets the current size of the terminal.
  TermSize size() => TermSize(_term.terminalColumns, _term.terminalLines);

  /// Gets the terminal color profile.
  tl.ProfileEnum get profile => _term.profile;

  /// Enables the alternate screen buffer.
  void enableAlternateScreen() => _term.enableAlternateScreen();

  /// Disables the alternate screen buffer.
  void disableAlternateScreen() => _term.disableAlternateScreen();

  /// Enables raw mode for terminal input.
  void enableRawMode() => _term.enableRawMode();

  /// Disables raw mode for terminal input.
  void disableRawMode() => _term.disableRawMode();

  /// Reads a terminal event of type [T], waiting up to [timeout] milliseconds.
  ///
  /// Returns `null` if no matching event arrives before the timeout elapses.
  Future<tle.Event?> readEvent<T extends tle.Event>({int timeout = 100}) =>
      _term.awaitEvent<T>(timeout: Duration(milliseconds: timeout));

  /// Polls for a terminal event of type [T] without blocking.
  ///
  /// Returns `null` when no matching event is currently buffered.
  tle.Event? poll<T extends tle.Event>() => _term.tryEvent<T>();

  /// Broadcast stream of parsed terminal events.
  ///
  /// Provides push-based event delivery for subscribers.
  Stream<tle.Event> get events => _term.events;

  /// Flushes any buffered output and then exits the application with the given [status] code.
  Future<void> flushThenExit(int status) async => _term.flushThenExit(status);

  /// Disposes of the terminal resources.
  Future<void> dispose() async {
    return _term.dispose();
  }

  /// Enables mouse event tracking.
  void enableMouseEvents() => _term.enableMouseEvents();

  /// Disables mouse event tracking.
  void disableMouseEvents() => _term.disableMouseEvents();

  /// Enables Kitty keyboard enhancement protocol.
  void enableKeyboardEnhancement() => _term.enableKeyboardEnhancement();

  /// Disables Kitty keyboard enhancement protocol.
  void disableKeyboardEnhancement() => _term.disableKeyboardEnhancement();

  /// Enables bracketed paste, so a paste arrives as one paste event.
  void enableBracketedPaste() => _term.enableBracketedPaste();

  /// Disables bracketed paste.
  void disableBracketedPaste() => _term.disableBracketedPaste();

  /// Enables focus reporting, so terminal focus in/out arrives as events.
  void enableFocusTracking() => _term.startFocusTracking();

  /// Disables focus reporting.
  void disableFocusTracking() => _term.endFocusTracking();

  /// Sets the terminal title.
  void setTitle(String title) => _term.setTerminalTitle(title);
} // End TermlibBackend

/// Maps a Kiko [Color] to a termlib color, or `null` when it is [Color.reset]
/// so the rendered run falls back to the terminal default for that channel.
tl.Color? _resolveColor(Color color) => color.value < 0 ? null : _toTlColor(color);

/// Maps a concrete (non-reset) Kiko [Color] to its termlib equivalent.
tl.Color _toTlColor(Color color) => switch (color.kind) {
  ColorKind.rgb => tl.Color.fromRGB(color.value),
  ColorKind.ansi => tl.Color.ansi(color.value),
  ColorKind.indexed => tl.Color.indexed(color.value),
};
