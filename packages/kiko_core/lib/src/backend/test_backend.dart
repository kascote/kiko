import 'dart:async';

import 'package:plume/plume.dart' show TextMeasurer;
import 'package:termparser/termparser_events.dart' as evt;

import '../buffer.dart';
import '../layout/position.dart';
import '../layout/rect.dart';
import '../layout/size.dart';
import '../mvu/pointer_msg.dart' show PointerButton, PointerMsg;
import '../plume/term_unicode_measurer.dart';
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
/// Feed the event loop with [emitKey], [emitClick], [emitMove], [emitDrag],
/// [emitWheel], [emitPaste], [emitFocus] and [emitResize] — kiko-vocabulary
/// helpers that build the matching raw event and hand it to [emit]. [emit]
/// itself stays available for full-fidelity cases the helpers don't cover (a
/// split press/release gesture, a key repeat or release). Coordinates are 0-based
/// buffer cells, the same space as [Rect] and [Position] — a [TestBackend]
/// has no terminal, so it has nothing to translate.
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
  final TextMeasurer _measurer;

  /// The applied result of every [draw] so far.
  ///
  /// Built with the same [TextMeasurer] the paired terminal measures with —
  /// pass the matching one as [TestBackend.new]'s `measurer` so a wide cell's
  /// overwrite bookkeeping here agrees with the buffers that produced the
  /// diffs this screen applies.
  late Buffer screen;

  /// The cells the last [draw] was handed.
  List<CellPos> lastDiff = const [];

  /// How many times [draw] has been called.
  int drawCount = 0;

  /// How many events [emit] has pushed so far, the helpers included.
  ///
  /// A `FrameScript` reads it to tell when every event a step emitted has
  /// reached `update`.
  int emitCount = 0;

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

  /// How many times [setCursorPosition] has been called.
  int setCursorPositionCount = 0;

  /// Whether the cursor is visible.
  bool cursorVisible = true;

  /// How many times [showCursor] has been called.
  int showCursorCount = 0;

  /// How many times [hideCursor] has been called.
  int hideCursorCount = 0;

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

  /// Whether the startup probe should report a dark background. Defaults to
  /// `null`, so a test that never touches this keeps today's plain behavior;
  /// set it to `true`/`false` before handing this backend to an `Application`
  /// to simulate a terminal that answered the background-color query.
  @override
  bool? hasDarkBackground;

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
  ///
  /// [measurer] should match whatever measurer the paired `Terminal` or
  /// `Application` is constructed with — see [screen].
  TestBackend({
    TermSize size = const TermSize(80, 24),
    this.profile = ColorProfile.trueColor,
    TextMeasurer measurer = const TermUnicodeMeasurer(),
  }) : _size = size,
       _measurer = measurer {
    screen = Buffer.empty(_areaOf(size), measurer: measurer);
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
    screen = Buffer.empty(_areaOf(size), measurer: _measurer);
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
  void hideCursor() {
    cursorVisible = false;
    hideCursorCount++;
  }

  @override
  void showCursor() {
    cursorVisible = true;
    showCursorCount++;
  }

  @override
  void setCursorPosition(Position pos) {
    cursor = pos;
    setCursorPositionCount++;
  }

  @override
  Future<Position?> getCursorPosition() async => cursor;

  @override
  Stream<evt.Event> get events => _events.stream;

  /// Pushes [event] to [events], and buffers it for [poll] and [readEvent].
  ///
  /// Positions are 0-based buffer cells.
  void emit(evt.Event event) {
    emitCount++;
    _pending.add(event);
    _events.add(event);
  }

  /// Pushes every event in order. See [emit].
  void emitAll(Iterable<evt.Event> events) => events.forEach(emit);

  /// Emits a key press built from [spec] — the same spec grammar `KeyMsg.key`
  /// and `KeyBinding` accept (`'q'`, `'ctrl+a'`, `'shift+tab'`).
  ///
  /// Parses [spec] through `KeyEvent.fromString`, the exact termparser call
  /// `KeyBinding` canonicalizes bindings with, so a helper call and a bound
  /// key can never disagree about what a spec means. This always builds a
  /// plain press; a repeat or a release (kitty-only) needs raw [emit].
  void emitKey(String spec) => emit(evt.KeyEvent.fromString(spec));

  /// Emits a full click at cell ([x], [y]): a press immediately followed by a
  /// release of the same [button], at the same cell.
  ///
  /// [x] and [y] are 0-based buffer cells, carried straight through with no
  /// translation. For a press and release split across separate ticks, or a
  /// button held down while the pointer travels, use raw [emit].
  void emitClick(
    int x,
    int y, {
    PointerButton button = PointerButton.left,
    bool shift = false,
    bool ctrl = false,
    bool alt = false,
  }) {
    final kind = _mouseButtonKind(button);
    final mods = _keyModifiers(shift: shift, ctrl: ctrl, alt: alt);
    emit(evt.MouseEvent(x, y, evt.MouseButton.down(kind), modifiers: mods));
    emit(evt.MouseEvent(x, y, evt.MouseButton.up(kind), modifiers: mods));
  }

  /// Emits pointer motion to cell ([x], [y]) with no button held.
  void emitMove(int x, int y) => emit(evt.MouseEvent(x, y, evt.MouseButton.moved()));

  /// Emits pointer motion to cell ([x], [y]) with [button] held down — a drag.
  void emitDrag(
    int x,
    int y, {
    PointerButton button = PointerButton.left,
    bool shift = false,
    bool ctrl = false,
    bool alt = false,
  }) {
    emit(
      evt.MouseEvent(
        x,
        y,
        evt.MouseButton.drag(_mouseButtonKind(button)),
        modifiers: _keyModifiers(shift: shift, ctrl: ctrl, alt: alt),
      ),
    );
  }

  /// Emits [deltaY] vertical and [deltaX] horizontal wheel notches at cell
  /// ([x], [y]).
  ///
  /// Sign follows [PointerMsg.wheelDeltaY]/[PointerMsg.wheelDeltaX]: positive
  /// [deltaY] is wheel-down, negative is wheel-up; positive [deltaX] is
  /// wheel-right, negative is wheel-left. Magnitude is how many notch events
  /// go out — `emitWheel(x, y, deltaY: 3)` emits three wheel-down events, one
  /// per notch, since the router never coalesces the wheel. At least one of
  /// [deltaX]/[deltaY] must be non-zero.
  void emitWheel(
    int x,
    int y, {
    int deltaX = 0,
    int deltaY = 0,
    bool shift = false,
    bool ctrl = false,
    bool alt = false,
  }) {
    assert(deltaX != 0 || deltaY != 0, 'emitWheel needs a non-zero deltaX or deltaY');
    final mods = _keyModifiers(shift: shift, ctrl: ctrl, alt: alt);
    final vertical = deltaY >= 0 ? evt.MouseButton.wheelDown() : evt.MouseButton.wheelUp();
    for (var i = 0; i < deltaY.abs(); i++) {
      emit(evt.MouseEvent(x, y, vertical, modifiers: mods));
    }
    final horizontal = deltaX >= 0 ? evt.MouseButton.wheelRight() : evt.MouseButton.wheelLeft();
    for (var i = 0; i < deltaX.abs(); i++) {
      emit(evt.MouseEvent(x, y, horizontal, modifiers: mods));
    }
  }

  /// Emits a paste of [text].
  void emitPaste(String text) => emit(evt.PasteEvent(text));

  /// Emits a change in terminal focus: [hasFocus] true when it was gained,
  /// false when it was lost.
  void emitFocus({required bool hasFocus}) => emit(evt.FocusEvent(hasFocus: hasFocus));

  /// Resizes the terminal to [size] and emits the resize event a terminal
  /// sends with it, so the runtime queues a `ResizeMsg`.
  ///
  /// [resizeTo] alone changes only what the next draw measures. The pixel
  /// size reported is eight by sixteen pixels per cell.
  void emitResize(TermSize size) {
    resizeTo(size);
    emit(evt.WindowResizeEvent(size.height, size.width, size.height * 16, size.width * 8));
  }

  /// Maps kiko's [PointerButton] to termparser's button kind — the same
  /// vocabulary [PointerButton.none] carries a bare `MouseButton.down()`
  /// under, with no button of its own.
  static evt.MouseButtonKind _mouseButtonKind(PointerButton button) => switch (button) {
    PointerButton.none => evt.MouseButtonKind.none,
    PointerButton.left => evt.MouseButtonKind.left,
    PointerButton.middle => evt.MouseButtonKind.middle,
    PointerButton.right => evt.MouseButtonKind.right,
  };

  /// Builds a termparser modifier set from the three plain booleans every
  /// emit helper takes, the same booleans `pointerFieldsFrom` reads back out.
  static evt.KeyModifiers _keyModifiers({required bool shift, required bool ctrl, required bool alt}) {
    var mods = evt.KeyModifiers.none;
    if (shift) mods |= evt.KeyModifiers.shift;
    if (ctrl) mods |= evt.KeyModifiers.ctrl;
    if (alt) mods |= evt.KeyModifiers.alt;
    return mods;
  }

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
