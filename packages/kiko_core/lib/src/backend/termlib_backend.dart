import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:termlib/termlib.dart' as tl;
import 'package:termparser/termparser_events.dart' as tle;

/// Returns [event] with its coordinates moved from the terminal's 1-based
/// numbering into kiko's 0-based buffer cells.
///
/// Events that carry no position are returned unchanged. Sizes are counts, not
/// coordinates, so a resize event passes through untouched.
///
/// Two event kinds carry a position. A mouse event reports the cell the pointer
/// is over, and a cursor-position reply reports where the cursor sits; both are
/// reported from 1. Subtracting is deliberate rather than clamped: SGR and the
/// legacy encodings both number from 1, so a zero would mean the parser is
/// wrong, and a clamp would hide that.
@visibleForTesting
tle.Event toBufferCoords(tle.Event event) => switch (event) {
  tle.MouseEvent(:final x, :final y, :final button, :final modifiers) => tle.MouseEvent(
    x - 1,
    y - 1,
    button,
    modifiers: modifiers,
  ),
  tle.CursorPositionEvent(:final x, :final y) => tle.CursorPositionEvent(x - 1, y - 1),
  _ => event,
};

/// A [Backend] implementation that uses the [termlib](https://pub.dev/packages/termlib) library.
///
/// This is the only backend that speaks to a real terminal, so it is the only
/// place that knows terminals number their cells from 1. It translates on the
/// way out, in [draw] and [setCursorPosition], and on the way in, in
/// [getCursorPosition] and on every event exit — [events], [readEvent] and
/// [poll]. Above it, everything is 0-based.
class TermlibBackend implements Backend {
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

  /// Probes the terminal once, so capability-dependent behavior — like
  /// termlib's resize-event fallback decision — reads a cached answer instead
  /// of querying live. Replies are consumed internally by termlib and never
  /// surface as events.
  @override
  Future<void> init() async {
    await _term.probe();
  }

  /// Clears a region of the terminal based on the specified [ClearType].
  @override
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
  @override
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
  @override
  void flush() {
    // noop
  }

  /// Gets the current cursor position in the terminal.
  @override
  Future<Position?> getCursorPosition() async {
    final pos = await _term.cursorPosition;
    if (pos == null) return null;
    // base terminal coordinates are 1 based, KiKo is 0 based
    return Position(pos.col - 1, pos.row - 1);
  }

  /// Hides the terminal cursor.
  @override
  void hideCursor() => _term.cursorHide();

  /// Inserts [n] new lines at the current cursor position.
  @override
  void insertNewLines(int n) {
    for (var i = 0; i < n; i++) {
      _term.write('\n');
    }
  }

  /// Sets the cursor position to the specified [pos].
  @override
  void setCursorPosition(Position pos) => _term.moveTo(pos.y + 1, pos.x + 1);

  /// Shows the terminal cursor.
  @override
  void showCursor() => _term.cursorShow();

  /// Gets the current size of the terminal.
  @override
  TermSize size() => TermSize(_term.terminalColumns, _term.terminalLines);

  /// Gets the terminal color profile.
  @override
  ColorProfile get profile => switch (_term.profile) {
    tl.ProfileEnum.noColor => ColorProfile.noColor,
    tl.ProfileEnum.ansi16 => ColorProfile.ansi16,
    tl.ProfileEnum.ansi256 => ColorProfile.ansi256,
    tl.ProfileEnum.trueColor => ColorProfile.trueColor,
  };

  /// Enables the alternate screen buffer.
  @override
  void enableAlternateScreen() => _term.enableAlternateScreen();

  /// Disables the alternate screen buffer.
  @override
  void disableAlternateScreen() => _term.disableAlternateScreen();

  /// Enables raw mode for terminal input.
  @override
  void enableRawMode() => _term.enableRawMode();

  /// Disables raw mode for terminal input.
  @override
  void disableRawMode() => _term.disableRawMode();

  /// Reads a terminal event of type [T], waiting up to [timeout] milliseconds.
  ///
  /// Returns `null` if no matching event arrives before the timeout elapses.
  /// Coordinates arrive in 0-based buffer cells, as on [events].
  @override
  Future<tle.Event?> readEvent<T extends tle.Event>({int timeout = 100}) async {
    final event = await _term.awaitEvent<T>(timeout: Duration(milliseconds: timeout));
    return event == null ? null : toBufferCoords(event);
  }

  /// Polls for a terminal event of type [T] without blocking.
  ///
  /// Returns `null` when no matching event is currently buffered. Coordinates
  /// arrive in 0-based buffer cells, as on [events].
  @override
  tle.Event? poll<T extends tle.Event>() {
    final event = _term.tryEvent<T>();
    return event == null ? null : toBufferCoords(event);
  }

  /// Broadcast stream of parsed terminal events.
  ///
  /// Provides push-based event delivery for subscribers. Every event carrying a
  /// position — a mouse event, a cursor-position reply — is translated here, so
  /// subscribers read 0-based buffer cells: the same space as `Rect`, `Buffer`
  /// and `Position`. See [toBufferCoords].
  @override
  Stream<tle.Event> get events => _term.events.map(toBufferCoords);

  /// Flushes pending output, then disposes of the terminal resources.
  ///
  /// termlib writes through `dart:io stdout`, which buffers asynchronously —
  /// without this flush, an app-side `exit(code)` right after `run()`
  /// completes could truncate the terminal-restore bytes this backend just
  /// wrote.
  @override
  Future<void> dispose() async {
    await _term.flush();
    await _term.dispose();
  }

  /// Enables mouse event tracking.
  @override
  void enableMouseEvents() => _term.enableMouseEvents();

  /// Disables mouse event tracking.
  @override
  void disableMouseEvents() => _term.disableMouseEvents();

  /// Enables Kitty keyboard enhancement protocol.
  @override
  void enableKeyboardEnhancement() => _term.enableKeyboardEnhancement();

  /// Disables Kitty keyboard enhancement protocol.
  @override
  void disableKeyboardEnhancement() => _term.disableKeyboardEnhancement();

  /// Enables bracketed paste, so a paste arrives as one paste event.
  @override
  void enableBracketedPaste() => _term.enableBracketedPaste();

  /// Disables bracketed paste.
  @override
  void disableBracketedPaste() => _term.disableBracketedPaste();

  /// Enables focus reporting, so terminal focus in/out arrives as events.
  @override
  void enableFocusTracking() => _term.startFocusTracking();

  /// Disables focus reporting.
  @override
  void disableFocusTracking() => _term.endFocusTracking();

  /// Enables terminal resize reporting.
  @override
  void enableWindowResizeEvents() => _term.enableResizeEvents();

  /// Disables terminal resize reporting.
  @override
  void disableWindowResizeEvents() => _term.disableResizeEvents();

  /// Sets the terminal title.
  @override
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
