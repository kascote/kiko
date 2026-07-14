import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

import 'selection.dart';
import 'textarea.dart';

// ═══════════════════════════════════════════════════════════
// STYLE
// ═══════════════════════════════════════════════════════════

/// Region-based styles for TextArea widget.
///
/// These are NOT state-based (focused, disabled) — those are handled by
/// [StyleResolver] in the widget. These style specific visual regions.
@immutable
class TextAreaStyle {
  /// Style for placeholder text.
  final Style? placeholder;

  /// Style for selected text.
  final Style? selection;

  /// Style for line numbers.
  final Style? lineNumber;

  /// Creates a TextAreaStyle.
  const TextAreaStyle({
    this.placeholder,
    this.selection,
    this.lineNumber,
  });

  /// Creates region styles derived from a [Theme].
  factory TextAreaStyle.fromTheme(Theme theme) => TextAreaStyle(
    placeholder: theme.muted.ink,
    selection: theme.selection.fill,
    lineNumber: theme.muted.ink,
  );

  /// Merges [other] on top of this, non-null values override.
  TextAreaStyle merge(TextAreaStyle? other) {
    if (other == null) return this;
    return TextAreaStyle(
      placeholder: other.placeholder ?? placeholder,
      selection: other.selection ?? selection,
      lineNumber: other.lineNumber ?? lineNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextAreaStyle &&
        other.placeholder == placeholder &&
        other.selection == selection &&
        other.lineNumber == lineNumber;
  }

  @override
  int get hashCode => Object.hash(placeholder, selection, lineNumber);
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for a multi-line text area with word wrapping.
///
/// Wraps [TextAreaComponent] and adds MVU integration (update method), focus state,
/// and configuration options. Returns [Declined] for keys it doesn't handle.
///
/// Note: Tab and Shift+Tab are unbound by default, so both fall through as
/// [Declined] for a parent to use for focus cycling. Pass a [keyBinding] that
/// maps `tab` to [TextAreaAction.tab] to opt an editor into space insertion.
class TextAreaModel implements Focusable {
  /// The underlying text area buffer.
  final TextAreaComponent textArea;

  /// Stable identity for this text area.
  ///
  /// A plume view stamps it on the field so a click resolves back through
  /// [HitMap.hitId]; pass an explicit id when addressing must survive a restart.
  final String id;

  /// Whether the text area is focused.
  @override
  bool focused;

  /// Placeholder text shown when empty.
  final String placeholder;

  /// Number of spaces inserted for tab.
  final int tabWidth;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Region styles (placeholder, selection, line numbers).
  ///
  /// Merged with theme-derived defaults in the widget. Only set fields
  /// you want to override.
  final TextAreaStyle? style;

  /// Key bindings for text area actions.
  late final KeyBinding<TextAreaAction> keyBinding;

  int _scrollOffset = 0;

  /// Vertical scroll offset in visual rows.
  int get scrollOffset => _scrollOffset;

  /// Creates a TextAreaModel.
  ///
  /// The wrap width is set dynamically by the widget based on render area.
  /// Pass a custom [keyBinding] to override default key bindings.
  TextAreaModel({
    String? id,
    String initial = '',
    this.placeholder = '',
    this.focused = false,
    this.tabWidth = 4,
    this.showLineNumbers = false,
    this.style,
    int maxCharacters = 0,
    int maxLines = 0,
    int maxColumns = 0,
    KeyBinding<TextAreaAction>? keyBinding,
  }) : id = id ?? autoId('textarea'),
       textArea = TextAreaComponent(
         maxCharacters: maxCharacters,
         maxLines: maxLines,
         maxColumns: maxColumns,
       ) {
    this.keyBinding = keyBinding ?? defaultTextAreaBindings.copy();
    if (initial.isNotEmpty) {
      textArea.initBuffer(initial);
    }
  }

  /// The text content as a string.
  String get value => textArea.content.string;

  /// Current cursor row in buffer.
  int get cursorRow => textArea.row;

  /// Current cursor column in buffer.
  int get cursorCol => textArea.column;

  /// Number of lines in buffer.
  int get lineCount => textArea.lineCount;

  /// Total character count.
  int get length => textArea.length();

  /// The selected block.
  SelectedBlock get selectedBlock => textArea.selectedBlock;

  /// Returns line info for current cursor position.
  LineInfo get currentLineInfo => textArea.lineInfo();

  /// Updates model based on message.
  ///
  /// The pointer branch sits above the focus gate, so a click places the caret
  /// whether or not the area is focused (the app focuses it). A button-down maps
  /// the clicked cell to a buffer position and moves the caret there; a wheel is
  /// declined so a scrollable ancestor gets it, and any other pointer traffic is
  /// declined too. The keyboard path stays behind the gate.
  ///
  /// Returns [Declined] for keys it doesn't handle, for pointers it doesn't
  /// consume, and when not focused. Returns [Handled] for handled keys, a click
  /// that moves the caret, and other non-key messages.
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      // Nothing to scroll vertically — decline so a scrollable ancestor gets
      // the wheel.
      if (pointer.isWheel) return const Declined();
      if (pointer.isDown) {
        caretAt(pointer.local);
        return const Handled();
      }
      // A move, drag, or release half of a click is not ours.
      return const Declined();
    }
    if (msg is PointerLeaveMsg) return const Declined(); // no hover to clear
    if (msg is PointerCancelMsg) return const Declined();

    if (!focused) return const Declined();

    if (msg case KeyMsg()) {
      return _handleKey(msg);
    }
    if (msg case PasteMsg(:final text)) {
      textArea.insert(text);
      return const Handled();
    }
    return const Handled(); // ignore other messages
  }

  /// Places the caret at the buffer cell under [local].
  ///
  /// [local] is a view cell counted from the editor's top-left, the line-number
  /// gutter included. The row is resolved through the wrapped-line layout — one
  /// buffer line can occupy several visual rows — and the vertical scroll; the
  /// column is walked with cell widths, so a click on either cell of a 2-wide
  /// grapheme lands on that grapheme. A click below the last line lands at the
  /// document end; a click left of the text (in the gutter) lands at the line
  /// start.
  void caretAt(Position local) {
    final ta = textArea;
    final gutter = showLineNumbers ? _gutterWidth(ta.lineCount) : 0;
    final targetRow = _scrollOffset + (local.y < 0 ? 0 : local.y);
    final targetColumn = local.x - gutter;

    var visualRow = 0;
    for (var bufferRow = 0; bufferRow < ta.lineCount; bufferRow++) {
      final wrapped = ta.wrappedLines(bufferRow, bufferRow + 1).first;
      // Grapheme index in the buffer line where this wrapped segment starts.
      var startColumn = 0;
      for (final segment in wrapped) {
        if (visualRow == targetRow) {
          ta
            ..row = bufferRow
            ..column = startColumn + _columnToIndex(segment, targetColumn);
          return;
        }
        startColumn += segment.length;
        visualRow++;
      }
    }
    // Below the last visual row → caret at the document end.
    ta.setCursorEndBuffer();
  }

  /// Width of the line-number gutter, mirroring the renderer's own sizing.
  int _gutterWidth(int lineCount) => lineCount.toString().length + 1;

  /// Maps a display column to a grapheme index within [text].
  ///
  /// The caret lands on the grapheme whose cell span contains [column], so a
  /// click on either cell of a 2-wide grapheme resolves to that grapheme. A
  /// column past the last grapheme lands at its end.
  int _columnToIndex(Characters text, int column) {
    if (column <= 0) return 0;
    var width = 0;
    var i = 0;
    for (final g in text) {
      width += widthChars(Characters(g));
      if (column < width) return i;
      i++;
    }
    return text.length;
  }

  UpdateResult _handleKey(KeyMsg msg) {
    final action = keyBinding.resolve(msg);

    if (action != null) {
      _executeAction(action);
      return const Handled();
    }

    // Character input (single grapheme, no modifiers)
    if (msg.char case final ch?) {
      textArea.insert(ch);
      return const Handled(); // handled
    }

    return const Declined(); // unhandled key
  }

  void _executeAction(TextAreaAction action) {
    final _ = switch (action) {
      TextAreaAction.up => textArea.moveCursorUp(),
      TextAreaAction.down => textArea.moveCursorDown(),
      TextAreaAction.left => textArea.moveCursorLeft(),
      TextAreaAction.right => textArea.moveCursorRight(),
      TextAreaAction.selectUp => textArea.moveCursorUp(isSelecting: true),
      TextAreaAction.selectDown => textArea.moveCursorDown(isSelecting: true),
      TextAreaAction.selectLeft => textArea.moveCursorLeft(isSelecting: true),
      TextAreaAction.selectRight => textArea.moveCursorRight(isSelecting: true),
      TextAreaAction.home => textArea.setCursorStart(),
      TextAreaAction.end => textArea.setCursorEnd(),
      TextAreaAction.docStart => textArea.setCursorStartBuffer(),
      TextAreaAction.docEnd => textArea.setCursorEndBuffer(),
      TextAreaAction.backspace => textArea.deleteCharBackward(),
      TextAreaAction.delete => textArea.deleteCharForward(),
      TextAreaAction.deleteWordLeft => textArea.deleteWordLeft(),
      TextAreaAction.deleteWordRight => textArea.deleteWordRight(),
      TextAreaAction.deleteToLineStart => textArea.deleteBeforeCursor(),
      TextAreaAction.deleteToLineEnd => textArea.deleteAfterCursor(),
      TextAreaAction.newline => textArea.insert('\n'),
      TextAreaAction.tab => textArea.insert(' ' * tabWidth),
    };
  }

  /// Calculates total visual height (all wrapped lines).
  int visualHeight() {
    var height = 0;
    for (final wrapped in textArea.wrappedLines(0)) {
      height += wrapped.length;
    }
    return height;
  }

  /// Returns the visual row of the cursor (0-indexed).
  int cursorVisualRow() {
    var visualRow = 0;
    var lineIdx = 0;
    for (final wrapped in textArea.wrappedLines(0)) {
      if (lineIdx == textArea.row) {
        return visualRow + currentLineInfo.rowOffset;
      }
      visualRow += wrapped.length;
      lineIdx++;
    }
    return visualRow + currentLineInfo.rowOffset;
  }

  /// Adjusts scroll to keep cursor visible within [visibleHeight] rows.
  void adjustScroll(int visibleHeight) {
    if (visibleHeight <= 0) return;

    final cursorRow = cursorVisualRow();

    if (cursorRow < _scrollOffset) {
      _scrollOffset = cursorRow;
    } else if (cursorRow >= _scrollOffset + visibleHeight) {
      _scrollOffset = cursorRow - visibleHeight + 1;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// Actions for text area key bindings.
enum TextAreaAction {
  /// Move cursor up one line.
  up,

  /// Move cursor down one line.
  down,

  /// Move cursor left one character.
  left,

  /// Move cursor right one character.
  right,

  /// Extend selection up one line.
  selectUp,

  /// Extend selection down one line.
  selectDown,

  /// Extend selection left one character.
  selectLeft,

  /// Extend selection right one character.
  selectRight,

  /// Move cursor to start of line.
  home,

  /// Move cursor to end of line.
  end,

  /// Move cursor to start of document.
  docStart,

  /// Move cursor to end of document.
  docEnd,

  /// Delete character before cursor.
  backspace,

  /// Delete character after cursor.
  delete,

  /// Delete word before cursor.
  deleteWordLeft,

  /// Delete word after cursor.
  deleteWordRight,

  /// Delete from cursor to start of line.
  deleteToLineStart,

  /// Delete from cursor to end of line.
  deleteToLineEnd,

  /// Insert newline.
  newline,

  /// Insert tab as spaces.
  ///
  /// Not bound by default — an editor opts in with
  /// `..map(['tab'], TextAreaAction.tab)` on a custom [TextAreaModel.keyBinding].
  tab,
}

/// Default key bindings for text area.
///
/// Tab and Shift+Tab are deliberately unbound: an unhandled key falls through
/// as [Declined], letting a parent use them for focus cycling. Map `tab` to
/// [TextAreaAction.tab] to opt an editor into space insertion instead.
final defaultTextAreaBindings = KeyBinding<TextAreaAction>()
  // Navigation
  ..map(['up'], TextAreaAction.up)
  ..map(['down'], TextAreaAction.down)
  ..map(['left'], TextAreaAction.left)
  ..map(['right'], TextAreaAction.right)
  // Selection
  ..map(['shift+up'], TextAreaAction.selectUp)
  ..map(['shift+down'], TextAreaAction.selectDown)
  ..map(['shift+left'], TextAreaAction.selectLeft)
  ..map(['shift+right'], TextAreaAction.selectRight)
  ..map(['home'], TextAreaAction.home)
  ..map(['end'], TextAreaAction.end)
  ..map(['ctrl+home'], TextAreaAction.docStart)
  ..map(['ctrl+end'], TextAreaAction.docEnd)
  // Readline
  ..map(['ctrl+a'], TextAreaAction.home)
  ..map(['ctrl+e'], TextAreaAction.end)
  ..map(['ctrl+p'], TextAreaAction.up)
  ..map(['ctrl+n'], TextAreaAction.down)
  ..map(['ctrl+b'], TextAreaAction.left)
  ..map(['ctrl+f'], TextAreaAction.right)
  // Deletion
  ..map(['backSpace'], TextAreaAction.backspace)
  ..map(['delete'], TextAreaAction.delete)
  ..map(['ctrl+backSpace'], TextAreaAction.deleteWordLeft)
  ..map(['ctrl+w'], TextAreaAction.deleteWordLeft)
  ..map(['ctrl+delete'], TextAreaAction.deleteWordRight)
  ..map(['ctrl+u'], TextAreaAction.deleteToLineStart)
  ..map(['ctrl+k'], TextAreaAction.deleteToLineEnd)
  // Input
  ..map(['enter'], TextAreaAction.newline);
