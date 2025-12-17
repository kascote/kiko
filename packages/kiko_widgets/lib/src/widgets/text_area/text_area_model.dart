import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

import 'selection.dart';
import 'textarea.dart';

/// Model for a multi-line text area with word wrapping.
///
/// Wraps [TextArea] and adds MVU integration (update method), focus state,
/// and configuration options.
class TextAreaModel {
  /// The underlying text area buffer.
  final TextArea textArea;

  /// Whether this text area has focus.
  bool focused;

  /// Placeholder text shown when empty.
  final String placeholder;

  /// Number of spaces inserted for tab.
  final int tabWidth;

  /// Style for selected text.
  final Style selectionStyle;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Style for line numbers.
  final Style lineNumberStyle;

  /// Vertical scroll offset in visual rows.
  int scrollOffset = 0;

  /// Creates a TextAreaModel.
  ///
  /// The wrap width is set dynamically by the widget based on render area.
  TextAreaModel({
    String initial = '',
    this.placeholder = '',
    this.focused = false,
    this.tabWidth = 4,
    Style? selectionStyle,
    this.showLineNumbers = false,
    Style? lineNumberStyle,
    int maxCharacters = 0,
    int maxLines = 0,
    int maxColumns = 0,
  }) : selectionStyle = selectionStyle ?? const Style(fg: Color.black, bg: Color.white),
       lineNumberStyle = lineNumberStyle ?? const Style(fg: Color.darkGray),
       textArea = TextArea(
         maxCharacters: maxCharacters,
         maxLines: maxLines,
         maxColumns: maxColumns,
       ) {
    if (initial.isNotEmpty) {
      textArea.initBuffer(initial);
    }
  }

  /// The text content as a string.
  String get value => textArea.content.string;

  /// Current cursor row in buffer.
  int get row => textArea.row;

  /// Current cursor column in buffer.
  int get column => textArea.column;

  /// Number of lines in buffer.
  int get lineCount => textArea.lineCount;

  /// Total character count.
  int get length => textArea.length();

  /// The selected block.
  SelectedBlock get selectedBlock => textArea.selectedBlock;

  /// Returns line info for current cursor position.
  LineInfo get currentLineInfo => textArea.lineInfo();

  /// Updates model based on message. Returns command if needed.
  Cmd? update(Msg msg) {
    if (msg case KeyMsg(key: final key)) {
      return _handleKey(key);
    }
    if (msg case PasteMsg(text: final text)) {
      textArea.insert(text);
      return null;
    }
    return null;
  }

  Cmd? _handleKey(evt.KeyEvent key) {
    final action = _defaultBindings[key];

    if (action != null) {
      _executeAction(action, key.modifiers);
      return null;
    }

    // Character input (no Ctrl)
    if (key case evt.KeyEvent(
      code: evt.KeyCode(char: final c),
      modifiers: final mods,
    ) when c.isNotEmpty && !mods.has(evt.KeyModifiers.ctrl)) {
      textArea.insert(c);
    }

    return null;
  }

  void _executeAction(_TextAreaAction action, evt.KeyModifiers mods) {
    final isSelecting = mods.has(evt.KeyModifiers.shift);

    switch (action) {
      case _TextAreaAction.up:
        textArea.moveCursorUp(isSelecting: isSelecting);
      case _TextAreaAction.down:
        textArea.moveCursorDown(isSelecting: isSelecting);
      case _TextAreaAction.left:
        textArea.moveCursorLeft(isSelecting: isSelecting);
      case _TextAreaAction.right:
        textArea.moveCursorRight(isSelecting: isSelecting);
      case _TextAreaAction.home:
        textArea.setCursorStart();
      case _TextAreaAction.end:
        textArea.setCursorEnd();
      case _TextAreaAction.docStart:
        textArea.setCursorStartBuffer();
      case _TextAreaAction.docEnd:
        textArea.setCursorEndBuffer();
      case _TextAreaAction.backspace:
        textArea.deleteCharBackward();
      case _TextAreaAction.delete:
        textArea.deleteCharForward();
      case _TextAreaAction.deleteWordLeft:
        textArea.deleteWordLeft();
      case _TextAreaAction.deleteWordRight:
        textArea.deleteWordRight();
      case _TextAreaAction.deleteToLineStart:
        textArea.deleteBeforeCursor();
      case _TextAreaAction.deleteToLineEnd:
        textArea.deleteAfterCursor();
      case _TextAreaAction.newline:
        textArea.insert('\n');
      case _TextAreaAction.tab:
        textArea.insert(' ' * tabWidth);
    }
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

    if (cursorRow < scrollOffset) {
      scrollOffset = cursorRow;
    } else if (cursorRow >= scrollOffset + visibleHeight) {
      scrollOffset = cursorRow - visibleHeight + 1;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

enum _TextAreaAction {
  up,
  down,
  left,
  right,
  home,
  end,
  docStart,
  docEnd,
  backspace,
  delete,
  deleteWordLeft,
  deleteWordRight,
  deleteToLineStart,
  deleteToLineEnd,
  newline,
  tab,
}

class _KeyBindings {
  final Map<evt.KeyEvent, _TextAreaAction> _bindings = {};

  void bind(String spec, _TextAreaAction action) {
    _bindings[evt.KeyEvent.fromString(spec)] = action;
  }

  _TextAreaAction? operator [](evt.KeyEvent key) => _bindings[key];
}

final _defaultBindings = _KeyBindings()
  // Navigation
  ..bind('up', _TextAreaAction.up)
  ..bind('down', _TextAreaAction.down)
  ..bind('left', _TextAreaAction.left)
  ..bind('right', _TextAreaAction.right)
  ..bind('shift+up', _TextAreaAction.up)
  ..bind('shift+down', _TextAreaAction.down)
  ..bind('shift+left', _TextAreaAction.left)
  ..bind('shift+right', _TextAreaAction.right)
  ..bind('home', _TextAreaAction.home)
  ..bind('end', _TextAreaAction.end)
  ..bind('ctrl+home', _TextAreaAction.docStart)
  ..bind('ctrl+end', _TextAreaAction.docEnd)
  // Readline
  ..bind('ctrl+a', _TextAreaAction.home)
  ..bind('ctrl+e', _TextAreaAction.end)
  ..bind('ctrl+p', _TextAreaAction.up)
  ..bind('ctrl+n', _TextAreaAction.down)
  ..bind('ctrl+b', _TextAreaAction.left)
  ..bind('ctrl+f', _TextAreaAction.right)
  // Deletion
  ..bind('backSpace', _TextAreaAction.backspace)
  ..bind('delete', _TextAreaAction.delete)
  ..bind('ctrl+backSpace', _TextAreaAction.deleteWordLeft)
  ..bind('ctrl+w', _TextAreaAction.deleteWordLeft)
  ..bind('ctrl+delete', _TextAreaAction.deleteWordRight)
  ..bind('ctrl+u', _TextAreaAction.deleteToLineStart)
  ..bind('ctrl+k', _TextAreaAction.deleteToLineEnd)
  // Input
  ..bind('enter', _TextAreaAction.newline)
  ..bind('tab', _TextAreaAction.tab);
