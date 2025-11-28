import 'package:termlib/termlib.dart' as tl;
import 'package:termparser/termparser_events.dart' as tle;

import '../buffer.dart';
import '../colors.dart';
import '../layout/position.dart';
import '../layout/size.dart';
import '../style.dart';
import 'backend.dart';

/// A [Backend] implementation that uses the [termlib](https://pub.dev/packages/termlib) library.
class TermlibBackend implements Backend {
  final tl.TermLib _term;

  /// Creates a new [TermlibBackend] instance.
  TermlibBackend() : _term = tl.TermLib();

  @override
  void clear() => _term.eraseScreen();

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

  @override
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
    _term.endSyncUpdate();
  }

  @override
  void flush() {
    // noop
  }

  @override
  Future<Position?> getCursorPosition() async {
    final pos = await _term.cursorPosition;
    if (pos == null) return null;
    // base terminal coordinates are 1 based, KiKo is 0 based
    return Position(pos.col - 1, pos.row - 1);
  }

  @override
  void hideCursor() => _term.cursorHide();

  @override
  void insertNewLines(int n) {
    for (var i = 0; i < n; i++) {
      _term.write('\n');
    }
  }

  @override
  void setCursorPosition(Position pos) => _term.moveTo(pos.y + 1, pos.x + 1);

  @override
  void showCursor() => _term.cursorShow();

  @override
  Size size() => Size(_term.terminalColumns, _term.terminalLines);

  @override
  void enableAlternateScreen() => _term.enableAlternateScreen();

  @override
  void disableAlternateScreen() => _term.disableAlternateScreen();

  @override
  void enableRawMode() => _term.enableRawMode();

  @override
  void disableRawMode() => _term.disableRawMode();

  @override
  Future<tle.Event> readEvent<T extends tle.Event>({int timeout = 100}) async => _term.pollTimeout<T>(timeout: timeout);

  @override
  Future<void> flushThenExit(int status) async => _term.flushThenExit(status);

  @override
  Future<void> dispose() async {
    return _term.dispose();
  }
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
