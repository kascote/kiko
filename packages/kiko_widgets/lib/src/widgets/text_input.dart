import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart' as evt;
import 'package:termunicode/termunicode.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for a single-line text input.
///
/// Holds both state (text, cursor, scroll) and config (placeholder, maxLength).
/// Use [update] to handle messages. Returns [Unhandled] for keys it doesn't handle.
class TextInputModel implements Focusable {
  Characters _text;
  int _cursor;
  int _scrollOffset;

  /// Whether the input is focused.
  @override
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

  /// Transforms or filters input before insertion.
  ///
  /// Receives input as grapheme clusters, returns sanitized output.
  /// Return empty to reject. Can lowercase, strip chars, validate, etc.
  final Characters Function(Characters input)? inputFilter;

  /// Creates a TextInputModel.
  TextInputModel({
    String initial = '',
    this.placeholder = '',
    this.maxLength,
    this.obscureText = false,
    this.obscureChar = '•',
    this.inputFilter,
    this.focused = false,
  }) : _text = Characters(initial),
       _cursor = initial.characters.length,
       _scrollOffset = 0;

  /// The text as a String.
  String get value => _text.string;

  /// Length in grapheme clusters.
  int get length => _text.length;

  /// Cursor position (index into grapheme sequence).
  ///
  /// Exposed for testing. Production code should use messages to move cursor.
  @visibleForTesting
  int get cursor => _cursor;
  @visibleForTesting
  set cursor(int value) => _cursor = value;

  /// Updates the model based on the message.
  ///
  /// Returns [Unhandled] for keys it doesn't handle (e.g., Tab).
  /// Returns `null` for handled keys, non-key messages, or when not focused.
  Cmd? update(Msg msg) {
    if (!focused) return null;

    if (msg case KeyMsg(key: final key)) {
      return _handleKey(key);
    }
    return null; // ignore non-KeyMsg
  }

  Cmd? _handleKey(evt.KeyEvent key) {
    // Tab → let parent handle (focus cycling)
    if (key.code.name == evt.KeyCodeName.tab) {
      return const Unhandled();
    }

    final action = _defaultBindings[key];

    if (action != null) {
      final _ = switch (action) {
        _TextInputAction.home => _cursor = 0,
        _TextInputAction.end => _cursor = length,
        _TextInputAction.left => _cursor > 0 ? _cursor-- : null,
        _TextInputAction.right => _cursor < length ? _cursor++ : null,
        _TextInputAction.jumpWordLeft => _cursor = _findWordBoundaryLeft(_text, _cursor),
        _TextInputAction.jumpWordRight => _cursor = _findWordBoundaryRight(_text, _cursor),
        _TextInputAction.backspace => _deleteBeforeCursor(),
        _TextInputAction.delete => _deleteAfterCursor(),
        _TextInputAction.deleteWordLeft => _deleteWordLeft(),
        _TextInputAction.deleteWordRight => _deleteWordRight(),
        _TextInputAction.deleteToLineStart => _deleteToLineStart(),
        _TextInputAction.deleteToLineEnd => _deleteToLineEnd(),
      };
      return null;
    }

    // Character input (no Ctrl)
    if (key case evt.KeyEvent(
      code: evt.KeyCode(char: final c),
      modifiers: final mods,
    ) when c.isNotEmpty && !mods.has(evt.KeyModifiers.ctrl)) {
      _insertAt(c);
      return null;
    }

    return const Unhandled(); // unhandled key
  }

  void _insertAt(String input) {
    // Apply input filter
    var filtered = Characters(input);
    if (inputFilter != null) {
      filtered = inputFilter!(filtered);
      if (filtered.isEmpty) return;
    }

    // Check maxLength
    if (maxLength != null && length + filtered.length > maxLength!) {
      return;
    }
    final before = _text.take(_cursor);
    final after = _text.skip(_cursor);
    _text = Characters('${before.string}${filtered.string}${after.string}');
    _cursor += filtered.length;
  }

  void _deleteBeforeCursor() {
    if (_cursor <= 0) return;
    final before = _text.take(_cursor - 1);
    final after = _text.skip(_cursor);
    _text = Characters('${before.string}${after.string}');
    _cursor--;
  }

  void _deleteAfterCursor() {
    if (_cursor >= length) return;
    final before = _text.take(_cursor);
    final after = _text.skip(_cursor + 1);
    _text = Characters('${before.string}${after.string}');
  }

  void _deleteWordLeft() {
    final boundary = _findWordBoundaryLeft(_text, _cursor);
    if (boundary == _cursor) return;
    final before = _text.take(boundary);
    final after = _text.skip(_cursor);
    _text = Characters('${before.string}${after.string}');
    _cursor = boundary;
  }

  void _deleteWordRight() {
    final boundary = _findWordBoundaryRight(_text, _cursor);
    if (boundary == _cursor) return;
    final before = _text.take(_cursor);
    final after = _text.skip(boundary);
    _text = Characters('${before.string}${after.string}');
  }

  void _deleteToLineStart() {
    if (_cursor <= 0) return;
    _text = _text.skip(_cursor);
    _cursor = 0;
  }

  void _deleteToLineEnd() {
    if (_cursor >= length) return;
    _text = _text.take(_cursor);
  }

  /// Adjusts scroll offset to keep cursor visible within given width.
  ///
  /// Call this during rendering to ensure cursor remains in view.
  /// Returns display info needed for rendering.
  ({Characters displayText, int cursorDisplayPos, int scrollOffset}) adjustScroll(int visibleWidth) {
    final displayText = obscureText ? Characters(obscureChar * length) : _text;
    final cursorDisplayPos = _widthUpTo(displayText, _cursor);

    if (cursorDisplayPos < _scrollOffset) {
      _scrollOffset = cursorDisplayPos;
    } else if (cursorDisplayPos >= _scrollOffset + visibleWidth) {
      _scrollOffset = cursorDisplayPos - visibleWidth + 1;
    }

    return (
      displayText: displayText,
      cursorDisplayPos: cursorDisplayPos,
      scrollOffset: _scrollOffset,
    );
  }

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

    final showPlaceholder = m.length == 0 && m.placeholder.isNotEmpty;

    if (showPlaceholder) {
      Span(m.placeholder).render(renderArea, frame);
      if (m.focused) {
        frame.cursorPosition = Position(renderArea.x, y);
      }
      return;
    }

    final (:displayText, :cursorDisplayPos, :scrollOffset) = m.adjustScroll(visibleWidth);

    Line(displayText.string).renderWithOffset(renderArea, frame, scrollOffset);

    if (m.focused) {
      final cursorX = renderArea.x + (cursorDisplayPos - scrollOffset);
      frame.cursorPosition = Position(cursorX, y);
    }
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
