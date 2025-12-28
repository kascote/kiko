import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

// ═══════════════════════════════════════════════════════════
// STYLE
// ═══════════════════════════════════════════════════════════

/// Styles for [TextInput] widget.
@immutable
class TextInputStyle {
  /// Style for user-entered text.
  final Style? text;

  /// Style for obscured text (password dots).
  final Style? obscured;

  /// Style for placeholder text.
  final Style? placeholder;

  /// Style for fill characters.
  final Style? fill;

  /// Creates a TextInputStyle.
  const TextInputStyle({this.text, this.obscured, this.placeholder, this.fill});

  /// Default style (no colors, inherits terminal defaults).
  static const defaultStyle = TextInputStyle();

  /// Merges [other] on top of this, non-null values override.
  TextInputStyle merge(TextInputStyle? other) {
    if (other == null) return this;
    return TextInputStyle(
      text: other.text ?? text,
      obscured: other.obscured ?? obscured,
      placeholder: other.placeholder ?? placeholder,
      fill: other.fill ?? fill,
    );
  }

  /// Creates a copy with the given fields replaced.
  TextInputStyle copyWith({
    Style? text,
    Style? obscured,
    Style? placeholder,
    Style? fill,
  }) {
    return TextInputStyle(
      text: text ?? this.text,
      obscured: obscured ?? this.obscured,
      placeholder: placeholder ?? this.placeholder,
      fill: fill ?? this.fill,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextInputStyle &&
        other.text == text &&
        other.obscured == obscured &&
        other.placeholder == placeholder &&
        other.fill == fill;
  }

  @override
  int get hashCode => Object.hash(text, obscured, placeholder, fill);
}

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

  /// Character used to fill remaining input area for visual width feedback.
  final String? fillChar;

  /// Styles for text, placeholder, and fill.
  final TextInputStyle style;

  /// Transforms or filters input before insertion.
  ///
  /// Receives input as grapheme clusters, returns sanitized output.
  /// Return empty to reject. Can lowercase, strip chars, validate, etc.
  final Characters Function(Characters input)? inputFilter;

  /// Key bindings for text input actions.
  late final KeyBinding<TextInputAction> keyBinding;

  /// Creates a TextInputModel.
  ///
  /// Pass a custom [keyBinding] to override default key bindings.
  TextInputModel({
    String initial = '',
    this.placeholder = '',
    this.maxLength,
    this.obscureText = false,
    this.obscureChar = '•',
    this.fillChar,
    this.inputFilter,
    this.focused = false,
    TextInputStyle? style,
    KeyBinding<TextInputAction>? keyBinding,
  }) : _text = Characters(initial),
       _cursor = initial.characters.length,
       _scrollOffset = 0,
       style = style ?? TextInputStyle.defaultStyle {
    this.keyBinding = keyBinding ?? defaultTextInputBindings.copy();
  }

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

    if (msg case KeyMsg()) {
      return _handleKey(msg);
    }
    return null; // ignore non-KeyMsg
  }

  Cmd? _handleKey(KeyMsg msg) {
    // Tab → let parent handle (focus cycling)
    if (msg.key == 'tab') {
      return const Unhandled();
    }

    final action = keyBinding.resolve(msg);

    if (action != null) {
      final _ = switch (action) {
        TextInputAction.home => _cursor = 0,
        TextInputAction.end => _cursor = length,
        TextInputAction.left => _cursor > 0 ? _cursor-- : null,
        TextInputAction.right => _cursor < length ? _cursor++ : null,
        TextInputAction.jumpWordLeft => _cursor = _findWordBoundaryLeft(_text, _cursor),
        TextInputAction.jumpWordRight => _cursor = _findWordBoundaryRight(_text, _cursor),
        TextInputAction.backspace => _deleteBeforeCursor(),
        TextInputAction.delete => _deleteAfterCursor(),
        TextInputAction.deleteWordLeft => _deleteWordLeft(),
        TextInputAction.deleteWordRight => _deleteWordRight(),
        TextInputAction.deleteToLineStart => _deleteToLineStart(),
        TextInputAction.deleteToLineEnd => _deleteToLineEnd(),
      };
      return null;
    }

    // Character input (single grapheme, no modifiers)
    if (msg.key.characters.length == 1) {
      _insertAt(msg.key);
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

    int usedWidth;

    if (showPlaceholder) {
      Span(m.placeholder, style: m.style.placeholder).render(renderArea, frame);
      usedWidth = widthString(m.placeholder).clamp(0, visibleWidth);
      if (m.focused) {
        frame.cursorPosition = Position(renderArea.x, y);
      }
    } else {
      final (:displayText, :cursorDisplayPos, :scrollOffset) = m.adjustScroll(visibleWidth);

      final textStyle = m.obscureText ? m.style.obscured : m.style.text;
      Line(displayText.string, style: textStyle).renderWithOffset(renderArea, frame, scrollOffset);

      final totalTextWidth = widthChars(displayText);
      usedWidth = (totalTextWidth - scrollOffset).clamp(0, visibleWidth);

      if (m.focused) {
        final cursorX = renderArea.x + (cursorDisplayPos - scrollOffset);
        frame.cursorPosition = Position(cursorX, y);
      }
    }

    // Fill remaining space with fillChar
    if (m.fillChar case final fillChar?) {
      // If maxLength is set, fill up to maxLength; otherwise fill visible width
      final targetWidth = m.maxLength != null ? m.maxLength!.clamp(0, visibleWidth) : visibleWidth;
      final remainingWidth = targetWidth - usedWidth;
      if (remainingWidth > 0) {
        final charWidth = widthString(fillChar);
        if (charWidth > 0) {
          final fillCount = remainingWidth ~/ charWidth;
          if (fillCount > 0) {
            final fillText = fillChar * fillCount;
            final fillArea = Rect.create(
              x: renderArea.x + usedWidth,
              y: y,
              width: remainingWidth,
              height: 1,
            );
            Span(fillText, style: m.style.fill).render(fillArea, frame);
          }
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// Actions for text input key bindings.
enum TextInputAction {
  /// Move cursor to start of line.
  home,

  /// Move cursor to end of line.
  end,

  /// Move cursor left one character.
  left,

  /// Move cursor right one character.
  right,

  /// Delete character before cursor.
  backspace,

  /// Delete character after cursor.
  delete,

  /// Delete word before cursor.
  deleteWordLeft,

  /// Delete word after cursor.
  deleteWordRight,

  /// Jump cursor to previous word boundary.
  jumpWordLeft,

  /// Jump cursor to next word boundary.
  jumpWordRight,

  /// Delete from cursor to start of line.
  deleteToLineStart,

  /// Delete from cursor to end of line.
  deleteToLineEnd,
}

/// Default key bindings for text input.
final defaultTextInputBindings = KeyBinding<TextInputAction>()
  // Readline
  ..map(['ctrl+a'], TextInputAction.home)
  ..map(['ctrl+e'], TextInputAction.end)
  ..map(['ctrl+w'], TextInputAction.deleteWordLeft)
  ..map(['ctrl+backSpace'], TextInputAction.deleteWordLeft)
  ..map(['ctrl+delete'], TextInputAction.deleteWordRight)
  ..map(['ctrl+left'], TextInputAction.jumpWordLeft)
  ..map(['ctrl+right'], TextInputAction.jumpWordRight)
  ..map(['ctrl+u'], TextInputAction.deleteToLineStart)
  ..map(['ctrl+k'], TextInputAction.deleteToLineEnd)
  // Basic
  ..map(['backSpace'], TextInputAction.backspace)
  ..map(['delete'], TextInputAction.delete)
  ..map(['left'], TextInputAction.left)
  ..map(['right'], TextInputAction.right)
  ..map(['home'], TextInputAction.home)
  ..map(['end'], TextInputAction.end);

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
