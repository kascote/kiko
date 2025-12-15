import 'package:characters/characters.dart';
import 'package:termparser/termparser_events.dart' as evt;
import 'package:termunicode/termunicode.dart';

import '../../layout/position.dart';
import '../../layout/rect.dart';
import '../../text/line.dart';
import '../../text/span.dart';
import '../../widgets/frame.dart';
import '../cmd.dart';
import '../msg.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for a single-line text input.
///
/// Holds both state (text, cursor, scroll) and config (placeholder, maxLength).
/// Use [update] to handle messages.
class TextInputModel {
  /// The text content as grapheme clusters.
  Characters text;

  /// Cursor position (index into grapheme sequence).
  int cursor;

  /// Horizontal scroll offset for rendering.
  int scrollOffset;

  /// Whether this input has focus (receives keyboard input).
  bool focused;

  // ─────────────────────────────────────────────
  // Config (set at initialization)
  // ─────────────────────────────────────────────

  /// Placeholder text shown when input is empty.
  final String placeholder;

  /// Maximum length in grapheme clusters. Null means unlimited.
  final int? maxLength;

  /// Whether to obscure text (for passwords).
  final bool obscureText;

  /// Character used to obscure text when [obscureText] is true.
  final String obscureChar;

  /// Creates a TextInputModel.
  TextInputModel({
    String initial = '',
    this.placeholder = '',
    this.maxLength,
    this.obscureText = false,
    this.obscureChar = '•',
    this.focused = false,
  }) : text = Characters(initial),
       cursor = initial.characters.length,
       scrollOffset = 0;

  /// The text as a String.
  String get value => text.string;

  /// Length in grapheme clusters.
  int get length => text.length;

  /// Updates the model based on the message.
  ///
  /// Returns a command if any side effect is needed.
  Cmd? update(Msg msg) {
    if (msg case KeyMsg(key: final key)) {
      return _handleKey(key);
    }
    return null;
  }

  Cmd? _handleKey(evt.KeyEvent key) {
    final action = _defaultBindings[key];

    if (action != null) {
      switch (action) {
        case _TextInputAction.home:
          cursor = 0;
        case _TextInputAction.end:
          cursor = length;
        case _TextInputAction.left:
          if (cursor > 0) cursor--;
        case _TextInputAction.right:
          if (cursor < length) cursor++;
        case _TextInputAction.jumpWordLeft:
          cursor = _findWordBoundaryLeft(text, cursor);
        case _TextInputAction.jumpWordRight:
          cursor = _findWordBoundaryRight(text, cursor);
        case _TextInputAction.backspace:
          _deleteBeforeCursor();
        case _TextInputAction.delete:
          _deleteAfterCursor();
        case _TextInputAction.deleteWordLeft:
          _deleteWordLeft();
        case _TextInputAction.deleteWordRight:
          _deleteWordRight();
        case _TextInputAction.deleteToLineStart:
          _deleteToLineStart();
        case _TextInputAction.deleteToLineEnd:
          _deleteToLineEnd();
      }
      return null;
    }

    // Character input (no Ctrl)
    if (key case evt.KeyEvent(
      code: evt.KeyCode(char: final c),
      modifiers: final mods,
    ) when c.isNotEmpty && !mods.has(evt.KeyModifiers.ctrl)) {
      _insertAt(c);
    }

    return null;
  }

  void _insertAt(String input) {
    // Check maxLength
    if (maxLength != null && length + input.characters.length > maxLength!) {
      return;
    }
    final before = text.take(cursor);
    final after = text.skip(cursor);
    text = Characters('${before.string}$input${after.string}');
    cursor += input.characters.length;
  }

  void _deleteBeforeCursor() {
    if (cursor <= 0) return;
    final before = text.take(cursor - 1);
    final after = text.skip(cursor);
    text = Characters('${before.string}${after.string}');
    cursor--;
  }

  void _deleteAfterCursor() {
    if (cursor >= length) return;
    final before = text.take(cursor);
    final after = text.skip(cursor + 1);
    text = Characters('${before.string}${after.string}');
  }

  void _deleteWordLeft() {
    final boundary = _findWordBoundaryLeft(text, cursor);
    if (boundary == cursor) return;
    final before = text.take(boundary);
    final after = text.skip(cursor);
    text = Characters('${before.string}${after.string}');
    cursor = boundary;
  }

  void _deleteWordRight() {
    final boundary = _findWordBoundaryRight(text, cursor);
    if (boundary == cursor) return;
    final before = text.take(cursor);
    final after = text.skip(boundary);
    text = Characters('${before.string}${after.string}');
  }

  void _deleteToLineStart() {
    if (cursor <= 0) return;
    text = text.skip(cursor);
    cursor = 0;
  }

  void _deleteToLineEnd() {
    if (cursor >= length) return;
    text = text.take(cursor);
  }
}

// ═══════════════════════════════════════════════════════════
// WIDGET
// ═══════════════════════════════════════════════════════════

/// A single-line text input widget.
///
/// Renders the state from [TextInputModel]. The model holds all state
/// and config; this widget is stateless and just renders.
class TextInput extends Widget {
  /// The model containing state and config.
  final TextInputModel model;

  /// Creates a TextInput widget.
  TextInput(this.model);

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final renderArea = area.intersection(frame.buffer.area);
    if (renderArea.isEmpty) return;

    final visibleWidth = renderArea.width;
    final y = renderArea.y;
    final m = model;

    // Determine what to display
    final displayText = m.obscureText ? Characters(m.obscureChar * m.length) : m.text;
    final showPlaceholder = m.length == 0 && m.placeholder.isNotEmpty;

    if (showPlaceholder) {
      Span(m.placeholder).render(renderArea, frame);
      if (m.focused) {
        frame.cursorPosition = Position(renderArea.x, y);
      }
      return;
    }

    // Calculate cursor display position (width in columns from start)
    final cursorDisplayPos = _widthUpTo(displayText, m.cursor);

    // Adjust scroll to keep cursor visible
    if (cursorDisplayPos < m.scrollOffset) {
      m.scrollOffset = cursorDisplayPos;
    } else if (cursorDisplayPos >= m.scrollOffset + visibleWidth) {
      m.scrollOffset = cursorDisplayPos - visibleWidth + 1;
    }

    // Render with horizontal scroll offset
    Line(displayText.string).renderWithOffset(renderArea, frame, m.scrollOffset);

    // Cursor position in terminal coords (only if focused)
    if (m.focused) {
      final cursorX = renderArea.x + (cursorDisplayPos - m.scrollOffset);
      frame.cursorPosition = Position(cursorX, y);
    }
  }

  /// Returns display width from start up to [index] graphemes.
  int _widthUpTo(Characters text, int index) {
    var width = 0;
    var i = 0;
    for (final g in text) {
      if (i >= index) break;
      width += widthChars(Characters(g));
      i++;
    }
    return width;
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// Actions for text input key bindings.
enum _TextInputAction {
  home,
  end,
  left,
  right,
  backspace,
  delete,
  deleteWordLeft,
  deleteWordRight,
  jumpWordLeft,
  jumpWordRight,
  deleteToLineStart,
  deleteToLineEnd,
}

/// Maps KeyEvents to actions.
class _KeyBindings {
  final Map<evt.KeyEvent, _TextInputAction> _bindings = {};

  void bind(String spec, _TextInputAction action) {
    _bindings[evt.KeyEvent.fromString(spec)] = action;
  }

  _TextInputAction? operator [](evt.KeyEvent key) => _bindings[key];
}

/// Default key bindings for text input.
final _defaultBindings = _KeyBindings()
  // Readline
  ..bind('ctrl+a', _TextInputAction.home)
  ..bind('ctrl+e', _TextInputAction.end)
  ..bind('ctrl+w', _TextInputAction.deleteWordLeft)
  ..bind('ctrl+backSpace', _TextInputAction.deleteWordLeft)
  ..bind('ctrl+delete', _TextInputAction.deleteWordRight)
  ..bind('ctrl+left', _TextInputAction.jumpWordLeft)
  ..bind('ctrl+right', _TextInputAction.jumpWordRight)
  ..bind('ctrl+u', _TextInputAction.deleteToLineStart)
  ..bind('ctrl+k', _TextInputAction.deleteToLineEnd)
  // Basic
  ..bind('backSpace', _TextInputAction.backspace)
  ..bind('delete', _TextInputAction.delete)
  ..bind('left', _TextInputAction.left)
  ..bind('right', _TextInputAction.right)
  ..bind('home', _TextInputAction.home)
  ..bind('end', _TextInputAction.end);

// ═══════════════════════════════════════════════════════════
// WORD BOUNDARY HELPERS
// ═══════════════════════════════════════════════════════════

int _findWordBoundaryLeft(Characters text, int cursor) {
  if (cursor <= 0) return 0;

  final chars = text.toList();
  var pos = cursor;

  // Skip whitespace before cursor
  while (pos > 0 && _isWhitespace(chars[pos - 1])) {
    pos--;
  }

  // Move to start of word
  while (pos > 0 && !_isWhitespace(chars[pos - 1])) {
    pos--;
  }

  return pos;
}

int _findWordBoundaryRight(Characters text, int cursor) {
  final length = text.length;
  if (cursor >= length) return length;

  final chars = text.toList();
  var pos = cursor;

  // Skip current word (non-whitespace)
  while (pos < length && !_isWhitespace(chars[pos])) {
    pos++;
  }

  // Skip whitespace
  while (pos < length && _isWhitespace(chars[pos])) {
    pos++;
  }

  return pos;
}

bool _isWhitespace(String grapheme) => grapheme.trim().isEmpty;
