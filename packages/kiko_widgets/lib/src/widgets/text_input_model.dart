import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';
import 'package:termunicode/termunicode.dart';

// ═══════════════════════════════════════════════════════════
// STYLE
// ═══════════════════════════════════════════════════════════

/// Region-based styles for the text input's plume view.
///
/// These control specific regions of the input (placeholder, fill, obscured
/// text). State-based styling (focused, disabled) is handled by
/// [StyleResolver] in the view.
@immutable
class TextInputStyle {
  /// Style for placeholder text.
  final Style? placeholder;

  /// Style for fill characters.
  final Style? fill;

  /// Style for obscured text (password dots).
  final Style? obscured;

  /// Creates a TextInputStyle.
  const TextInputStyle({this.placeholder, this.fill, this.obscured});

  /// Creates region styles derived from [theme].
  factory TextInputStyle.fromTheme(Theme theme) => TextInputStyle(
    placeholder: theme.muted.ink,
    fill: theme.muted.ink,
  );

  /// Merges [other] on top of this, non-null values override.
  TextInputStyle merge(TextInputStyle? other) {
    if (other == null) return this;
    return TextInputStyle(
      placeholder: other.placeholder ?? placeholder,
      fill: other.fill ?? fill,
      obscured: other.obscured ?? obscured,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextInputStyle &&
        other.placeholder == placeholder &&
        other.fill == fill &&
        other.obscured == obscured;
  }

  @override
  int get hashCode => Object.hash(placeholder, fill, obscured);
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for a single-line text input.
///
/// Holds both state (text, cursor, scroll) and config (placeholder, maxLength).
/// Use [update] to handle messages. Returns [Declined] for keys it doesn't handle.
class TextInputModel implements Focusable {
  Characters _text;
  int _cursor;
  int _scrollOffset;

  /// Stable identity for this input.
  ///
  /// A plume view stamps it on the field so a click resolves back through
  /// [HitMap.hitId]; pass an explicit id when addressing must survive a restart.
  final String id;

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

  /// Region styles for placeholder, fill, and obscured text.
  final TextInputStyle? style;

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
    String? id,
    String initial = '',
    this.placeholder = '',
    this.maxLength,
    this.obscureText = false,
    this.obscureChar = '•',
    this.fillChar,
    this.inputFilter,
    this.focused = false,
    this.style,
    KeyBinding<TextInputAction>? keyBinding,
  }) : id = id ?? autoId('textinput'),
       _text = Characters(initial),
       _cursor = initial.characters.length,
       _scrollOffset = 0 {
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

  /// The cursor's display column: the rendered width of the text before it.
  ///
  /// Counts obscure characters when [obscureText] is set, so the column lines up
  /// with what is drawn. A view adds this to the field's left edge to place the
  /// terminal cursor.
  int get cursorColumn {
    final displayText = obscureText ? Characters(obscureChar * length) : _text;
    return _widthUpTo(displayText, _cursor);
  }

  /// Updates the model based on the message.
  ///
  /// The pointer branch sits above the focus gate, so a click places the caret
  /// whether or not the input is focused (the app focuses it). A button-down
  /// maps the clicked column to a grapheme and moves the caret there; a wheel is
  /// declined so a scrollable ancestor gets it, and any other pointer traffic is
  /// declined too. The keyboard path stays behind the gate.
  ///
  /// Returns [Declined] for keys it doesn't handle (e.g., Tab), for pointers it
  /// doesn't consume, and when not focused. Returns [Handled] for handled keys,
  /// a click that moves the caret, and other non-key messages.
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      // Nothing to scroll vertically — decline so a scrollable ancestor gets
      // the wheel.
      if (pointer.isWheel) return const Declined();
      if (pointer.isDown) {
        // local.x is a display column; add the horizontal scroll to reach the
        // absolute text column, then map it to a grapheme. A caret move is
        // internal state, so the click is consumed with no widget→app command.
        _cursor = _columnToIndex(pointer.local.x + _scrollOffset);
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
    return const Handled(); // ignore non-KeyMsg
  }

  UpdateResult _handleKey(KeyMsg msg) {
    // Tab → let parent handle (focus cycling)
    if (msg.key == 'tab') {
      return const Declined();
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
      return const Handled();
    }

    // Character input (single grapheme, no modifiers)
    if (msg.char case final ch?) {
      _insertAt(ch);
      return const Handled();
    }

    return const Declined(); // unhandled key
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

  /// Maps a display column to a grapheme index — the inverse of [_widthUpTo].
  ///
  /// Walks the rendered graphemes (obscure characters when [obscureText] is set)
  /// summing cell width; the caret lands on the grapheme whose cell span
  /// contains [column], so a click on either cell of a 2-wide grapheme resolves
  /// to that grapheme. A column past the last grapheme lands at [length].
  int _columnToIndex(int column) {
    if (column <= 0) return 0;
    final displayText = obscureText ? Characters(obscureChar * length) : _text;
    var width = 0;
    var i = 0;
    for (final g in displayText) {
      width += widthChars(Characters(g));
      if (column < width) return i;
      i++;
    }
    return length;
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
