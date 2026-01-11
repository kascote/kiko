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
  final tl.TermLib _term;

  /// Creates a new [TermlibBackend] instance.
  TermlibBackend() : _term = tl.TermLib();

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
  /// Resets terminal style at end of draw to prevent style leaking between
  /// frames. Without reset, tracking vars reset to Color.reset each frame but
  /// terminal keeps last frame's state, causing cells with reset color to
  /// inherit stale styles.
  void draw(Iterable<CellPos> cellPos) {
    var fg = Color.reset;
    var bg = Color.reset;
    var underline = Color.reset;
    var modifier = Modifier.empty;
    Position? lastPos;

    _term.startSyncUpdate();
    for (final (x: x, y: y, cell: cell) in cellPos) {
      final tStyle = _term.style(cell.symbol);
      if (!((x == (lastPos?.x ?? 0) + 1) && (y == (lastPos?.y ?? 0)))) {
        // base terminal coordinates are 1 based, KiKo is 0 based
        _term.moveTo(y + 1, x + 1);
      }
      lastPos = Position(x, y);

      if (cell.modifier != modifier) {
        _mergeModifier(tStyle, modifier, cell.modifier);
        modifier = cell.modifier;
      }

      if (cell.fg != fg || cell.bg != bg) {
        _mergeColor(tStyle, cell.fg, cell.bg);
        fg = cell.fg;
        bg = cell.bg;
      }
      if (cell.underline != underline) {
        _mergeUnderline(tStyle, underline);
        underline = cell.underline;
      }

      _term.write(tStyle);
    }

    // Reset terminal style to match tracking state for next frame.
    // This ensures cells with Color.reset won't inherit stale styles.
    _term
      ..write('\x1b[0m')
      ..endSyncUpdate();
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
  Size size() => Size(_term.terminalColumns, _term.terminalLines);

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

  /// Reads a terminal event of type [T] with an optional [timeout] in milliseconds.
  Future<tle.Event> readEvent<T extends tle.Event>({int timeout = 100}) async => _term.pollTimeout<T>(timeout: timeout);

  /// Polls for a terminal event of type [T] without blocking.
  tle.Event poll<T extends tle.Event>() => _term.poll<T>();

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

  /// Sets the terminal title.
  void setTitle(String title) => _term.setTerminalTitle(title);
} // End TermlibBackend

void _mergeModifier(
  tl.Style style,
  Modifier fromModifier,
  Modifier toModifier,
) {
  final removed = fromModifier - toModifier;

  if (removed.has(Modifier.bold)) style.boldOff();
  if (removed.has(Modifier.italic)) style.italicOff();
  if (removed.has(Modifier.dim)) style.faintOff();
  if (removed.has(Modifier.crossedOut)) style.crossoutOff();
  if (removed.has(Modifier.reversed)) style.reverseOff();
  if (removed.has(Modifier.slowBlink)) style.blinkOff();
  if (removed.has(Modifier.rapidBlink)) style.blinkOff();
  // if (removed.has(Modifier.hidden)) style.hideOff();
  if (removed.has(Modifier.underlined)) style.underlineOff();

  final added = toModifier - fromModifier;
  if (added.has(Modifier.bold)) style.bold();
  if (added.has(Modifier.italic)) style.italic();
  if (added.has(Modifier.dim)) style.faint();
  if (added.has(Modifier.crossedOut)) style.crossout();
  if (added.has(Modifier.reversed)) style.reverse();
  if (added.has(Modifier.slowBlink)) style.blink();
  if (added.has(Modifier.rapidBlink)) style.blink();
  // if (added.has(Modifier.hidden)) style.hide();
  if (added.has(Modifier.underlined)) style.underline();
}

void _mergeColor(tl.Style style, Color fg, Color bg) {
  final _ = switch (fg.kind) {
    ColorKind.rgb => style.fg(
      tl.Color.fromRGBComponent(
        fg.value >> 16 & 0xff,
        fg.value >> 8 & 0xff,
        fg.value & 0xff,
      ),
    ),
    ColorKind.ansi => fg.value < 0 ? style.fg(tl.Color.reset) : style.fg(tl.Color.ansi(fg.value)),
    ColorKind.indexed => style.fg(tl.Color.indexed(fg.value)),
  };

  return switch (bg.kind) {
    ColorKind.rgb => style.bg(
      tl.Color.fromRGBComponent(
        bg.value >> 16 & 0xff,
        bg.value >> 8 & 0xff,
        bg.value & 0xff,
      ),
    ),
    ColorKind.ansi => bg.value < 0 ? style.bg(tl.Color.reset) : style.bg(tl.Color.ansi(bg.value)),
    ColorKind.indexed => style.bg(tl.Color.indexed(bg.value)),
  };
}

void _mergeUnderline(tl.Style style, Color under) {
  return switch (under.kind) {
    ColorKind.rgb => style.underline(
      tl.Color.fromRGBComponent(
        under.value >> 16 & 0xff,
        under.value >> 8 & 0xff,
        under.value & 0xff,
      ),
    ),
    ColorKind.ansi => under.value < 0 ? style.underlineOff() : style.underline(tl.Color.ansi(under.value)),
    ColorKind.indexed => style.underline(tl.Color.indexed(under.value)),
  };
}
