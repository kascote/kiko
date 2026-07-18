import 'dart:async';

import 'package:termparser/termparser_events.dart' as evt;

import '../buffer.dart';
import '../layout/position.dart';
import '../layout/rect.dart';
import '../layout/size.dart';
import 'backend.dart';

/// A [Backend] that renders to memory instead of a terminal.
///
/// Construct one in a test, hand it to `Terminal.create` or `Application`, and
/// the whole render loop runs under `dart test` — no TTY, no escape sequences,
/// no process exit.
///
/// It keeps a [screen]: a [Buffer] the size of the terminal, onto which every
/// [draw] applies the cells it is handed. So it answers what was *rendered*,
/// not merely what was *written*. Assert against [screen] to check the picture,
/// against [lastDiff] to check the double buffer only redrew what changed.
///
/// Feed the event loop with [emit]. Coordinates are 0-based buffer cells, the
/// same space as [Rect] and [Position] — a [TestBackend] has no terminal, so it
/// has nothing to translate.
///
/// ## What it does not do
///
/// This is not a terminal emulator. It parses no escape sequences and simulates
/// no scroll regions: [draw] receives structured [CellPos] records, and every
/// other call — [clearRegion], [insertNewLines], the mode toggles — is recorded
/// rather than applied to [screen].
class TestBackend implements Backend {
  final _events = StreamController<evt.Event>.broadcast();
  final _pending = <evt.Event>[];

  TermSize _size;

  /// The applied result of every [draw] so far.
  late Buffer screen;

  /// The cells the last [draw] was handed.
  List<CellPos> lastDiff = const [];

  /// How many times [draw] has been called.
  int drawCount = 0;

  /// How many times [flush] has been called.
  int flushCount = 0;

  /// Every [clearRegion] call, in order.
  final List<ClearType> clears = <ClearType>[];

  /// Total lines requested through [insertNewLines].
  int insertedNewLines = 0;

  /// How many times [insertNewLines] has been called.
  int insertNewLinesCount = 0;

  /// The cursor position, as last set by [setCursorPosition].
  Position cursor = Position.origin;

  /// Whether the cursor is visible.
  bool cursorVisible = true;

  /// Whether the alternate screen buffer is enabled.
  bool alternateScreen = false;

  /// Whether raw mode is enabled.
  bool rawMode = false;

  /// Whether mouse event tracking is enabled.
  bool mouseEvents = false;

  /// Whether the Kitty keyboard enhancement protocol is enabled.
  bool keyboardEnhancement = false;

  /// How many times [enableKeyboardEnhancement] has been called.
  int enableKeyboardEnhancementCount = 0;

  /// How many times [disableKeyboardEnhancement] has been called.
  int disableKeyboardEnhancementCount = 0;

  /// Whether the startup probe should report kitty keyboard enhancement
  /// support. Defaults to `false`, so a test that never touches this keeps
  /// today's plain behavior; set it before handing this backend to an
  /// `Application` to simulate a terminal that answered the capability query.
  @override
  bool supportsKeyboardEnhancement = false;

  /// Whether bracketed paste is enabled.
  bool bracketedPaste = false;

  /// Whether focus reporting is enabled.
  bool focusTracking = false;

  /// Whether terminal resize reporting is enabled.
  bool windowResizeEvents = false;

  /// The title last set through [setTitle].
  String? title;

  /// Whether [init] has been called.
  bool initialized = false;

  /// Whether [dispose] has been called.
  bool disposed = false;

  /// The set of colors this backend reports. Set it to drive style projection.
  @override
  ColorProfile profile;

  /// Creates a backend over a [size]-sized screen, `80x24` by default.
  TestBackend({
    TermSize size = const TermSize(80, 24),
    this.profile = ColorProfile.trueColor,
  }) : _size = size {
    screen = Buffer.empty(_areaOf(size));
  }

  static Rect _areaOf(TermSize size) => Rect.create(x: 0, y: 0, width: size.width, height: size.height);

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  TermSize size() => _size;

  /// Resizes the terminal to [size], clearing [screen].
  ///
  /// A `Terminal` notices on its next draw, so this is how a resize is driven.
  void resizeTo(TermSize size) {
    _size = size;
    screen = Buffer.empty(_areaOf(size));
  }

  /// Applies [cellPos] onto [screen] and records it as [lastDiff].
  ///
  /// Cells outside the screen are dropped, the way a terminal clips them.
  /// [lastDiff] still records them, so a test can tell the difference.
  @override
  void draw(Iterable<CellPos> cellPos) {
    final diff = cellPos.toList(growable: false);
    lastDiff = diff;
    drawCount++;
    for (final (:x, :y, :cell) in diff) {
      if (!screen.area.contains(Position(x, y))) continue;
      screen[(x: x, y: y)] = cell;
    }
  }

  @override
  void flush() => flushCount++;

  @override
  void clearRegion(ClearType type) => clears.add(type);

  @override
  void insertNewLines(int n) {
    insertedNewLines += n;
    insertNewLinesCount++;
  }

  @override
  void hideCursor() => cursorVisible = false;

  @override
  void showCursor() => cursorVisible = true;

  @override
  void setCursorPosition(Position pos) => cursor = pos;

  @override
  Future<Position?> getCursorPosition() async => cursor;

  @override
  Stream<evt.Event> get events => _events.stream;

  /// Pushes [event] to [events], and buffers it for [poll] and [readEvent].
  ///
  /// Positions are 0-based buffer cells.
  void emit(evt.Event event) {
    _pending.add(event);
    _events.add(event);
  }

  /// Pushes every event in order. See [emit].
  void emitAll(Iterable<evt.Event> events) => events.forEach(emit);

  @override
  evt.Event? poll<E extends evt.Event>() {
    for (var i = 0; i < _pending.length; i++) {
      if (_pending[i] is E) return _pending.removeAt(i);
    }
    return null;
  }

  @override
  Future<evt.Event?> readEvent<E extends evt.Event>({int timeout = 100}) async {
    final buffered = poll<E>();
    if (buffered != null) return buffered;

    final matched = Completer<evt.Event?>();
    void complete([evt.Event? event]) {
      if (!matched.isCompleted) matched.complete(event);
    }

    final timer = Timer(Duration(milliseconds: timeout), complete);
    final subscription = _events.stream.listen(
      (event) {
        if (event is! E) return;
        _pending.remove(event);
        complete(event);
      },
      onDone: complete,
    );

    final event = await matched.future;
    timer.cancel();
    await subscription.cancel();
    return event;
  }

  @override
  void enableAlternateScreen() => alternateScreen = true;

  @override
  void disableAlternateScreen() => alternateScreen = false;

  @override
  void enableRawMode() => rawMode = true;

  @override
  void disableRawMode() => rawMode = false;

  @override
  void enableMouseEvents() => mouseEvents = true;

  @override
  void disableMouseEvents() => mouseEvents = false;

  @override
  void enableKeyboardEnhancement() {
    keyboardEnhancement = true;
    enableKeyboardEnhancementCount++;
  }

  @override
  void disableKeyboardEnhancement() {
    keyboardEnhancement = false;
    disableKeyboardEnhancementCount++;
  }

  @override
  void enableBracketedPaste() => bracketedPaste = true;

  @override
  void disableBracketedPaste() => bracketedPaste = false;

  @override
  void enableFocusTracking() => focusTracking = true;

  @override
  void disableFocusTracking() => focusTracking = false;

  @override
  void enableWindowResizeEvents() => windowResizeEvents = true;

  @override
  void disableWindowResizeEvents() => windowResizeEvents = false;

  @override
  void setTitle(String title) => this.title = title;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }
}
