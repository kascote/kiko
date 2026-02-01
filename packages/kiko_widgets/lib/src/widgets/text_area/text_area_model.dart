import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import 'selection.dart';
import 'textarea.dart';

// ═══════════════════════════════════════════════════════════
// STYLE
// ═══════════════════════════════════════════════════════════

/// Styles for TextArea widget.
@immutable
class TextAreaStyle {
  /// Style for text content.
  final Style? text;

  /// Style for placeholder text.
  final Style? placeholder;

  /// Style for selected text.
  final Style? selection;

  /// Style for line numbers.
  final Style? lineNumber;

  /// Creates a TextAreaStyle.
  const TextAreaStyle({
    this.text,
    this.placeholder,
    this.selection,
    this.lineNumber,
  });

  /// Default style with sensible defaults.
  static const defaultStyle = TextAreaStyle(
    selection: Style(fg: Color.black, bg: Color.white),
    lineNumber: Style(fg: Color.darkGray),
    placeholder: Style(fg: Color.darkGray),
  );

  /// Merges [other] on top of this, non-null values override.
  TextAreaStyle merge(TextAreaStyle? other) {
    if (other == null) return this;
    return TextAreaStyle(
      text: other.text ?? text,
      placeholder: other.placeholder ?? placeholder,
      selection: other.selection ?? selection,
      lineNumber: other.lineNumber ?? lineNumber,
    );
  }

  /// Creates a copy with the given fields replaced.
  TextAreaStyle copyWith({
    Style? text,
    Style? placeholder,
    Style? selection,
    Style? lineNumber,
  }) {
    return TextAreaStyle(
      text: text ?? this.text,
      placeholder: placeholder ?? this.placeholder,
      selection: selection ?? this.selection,
      lineNumber: lineNumber ?? this.lineNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextAreaStyle &&
        other.text == text &&
        other.placeholder == placeholder &&
        other.selection == selection &&
        other.lineNumber == lineNumber;
  }

  @override
  int get hashCode => Object.hash(text, placeholder, selection, lineNumber);
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for a multi-line text area with word wrapping.
///
/// Wraps [TextAreaComponent] and adds MVU integration (update method), focus state,
/// and configuration options. Returns [Unhandled] for keys it doesn't handle.
///
/// Note: Tab is consumed (inserts spaces for indentation), not passed to parent.
class TextAreaModel implements Focusable {
  /// The underlying text area buffer.
  final TextAreaComponent textArea;

  /// Whether the text area is focused.
  @override
  bool focused;

  /// Placeholder text shown when empty.
  final String placeholder;

  /// Number of spaces inserted for tab.
  final int tabWidth;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Styles for text, placeholder, selection, and line numbers.
  final TextAreaStyle style;

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
    String initial = '',
    this.placeholder = '',
    this.focused = false,
    this.tabWidth = 4,
    this.showLineNumbers = false,
    TextAreaStyle? style,
    int maxCharacters = 0,
    int maxLines = 0,
    int maxColumns = 0,
    KeyBinding<TextAreaAction>? keyBinding,
  }) : style = TextAreaStyle.defaultStyle.merge(style),
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
  /// Returns [Unhandled] for keys it doesn't handle.
  /// Returns `null` for handled keys, non-key messages, or when not focused.
  Cmd? update(Msg msg) {
    if (!focused) return null;

    if (msg case KeyMsg()) {
      return _handleKey(msg);
    }
    if (msg case PasteMsg(text: final text)) {
      textArea.insert(text);
      return null;
    }
    return null; // ignore other messages
  }

  Cmd? _handleKey(KeyMsg msg) {
    final action = keyBinding.resolve(msg);

    if (action != null) {
      _executeAction(action);
      return null;
    }

    // Character input (single grapheme, no modifiers)
    if (msg.key.characters.length == 1) {
      textArea.insert(msg.key);
      return null; // handled
    }

    return const Unhandled(); // unhandled key
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
      TextAreaAction.shiftTab => null, // consumed, no-op
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

  /// Insert tab (as spaces).
  tab,

  /// Shift+tab (consumed, no-op by default).
  shiftTab,
}

/// Default key bindings for text area.
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
  ..map(['enter'], TextAreaAction.newline)
  ..map(['tab'], TextAreaAction.tab)
  ..map(['shift+tab'], TextAreaAction.shiftTab);
