import 'package:meta/meta.dart';

import 'colors.dart';
import 'style.dart';

/// A Buffer Cell
@immutable
class Cell {
  final String _char;

  /// Foreground color of the cell
  final Color fg;

  /// Background color of the cell
  final Color bg;

  /// Underline color of the cell
  final Color underline;

  /// [Modifier] of the cell
  final Modifier modifier;

  /// Whether the cell should be skipped when render
  ///
  /// This is helpful when it is necessary to prevent the buffer from
  /// overwriting a cell that is covered by an image from some terminal
  /// graphics protocol (Sixel / iTerm / Kitty ...
  final bool skip;

  /// Create a new cell with the given value
  const Cell({
    String char = ' ',
    this.fg = Color.reset,
    this.bg = Color.reset,
    this.underline = Color.reset,
    this.modifier = Modifier.empty,
    this.skip = false,
  }) : _char = char;

  /// Create an empty cell with default values
  factory Cell.empty() => const Cell();

  /// The string to be drawn in the cell. Only the first character is use.
  /// This accepts unicode grapheme clusters which might take up more than one
  /// cell in the terminal.
  String get symbol => _char;

  /// Set the style of the cell
  Cell setStyle(Style style) {
    return copyWith(
      fg: style.fg ?? fg,
      bg: style.bg ?? bg,
      underline: style.underline ?? underline,
      modifier: (modifier | style.addModifier) - style.subModifier,
    );
  }

  /// Helper function to update the char and style
  Cell setCell({String? char, Style style = const Style()}) {
    return copyWith(
      char: char,
      fg: style.fg ?? fg,
      bg: style.bg ?? bg,
      underline: style.underline ?? underline,
      modifier: (modifier | style.addModifier) - style.subModifier,
    );
  }

  /// Appends a symbol to the cell.
  ///
  /// This is particularly useful for adding zero-width characters to the cell.
  Cell appendSymbol({String char = ' ', Style style = const Style()}) {
    return setCell(char: '$_char$char', style: style);
  }

  /// Get the properties of the cell as a [Style]
  Style style() {
    return Style(
      fg: fg,
      bg: bg,
      underline: underline,
      addModifier: modifier,
    );
  }

  /// Reset the cell to the default values
  Cell reset() => Cell.empty();

  /// Copy the cell with the given properties
  Cell copyWith({
    String? char,
    Color? fg,
    Color? bg,
    Color? underline,
    Modifier? modifier,
    bool? skip,
  }) {
    return Cell(
      char: char ?? _char,
      fg: fg ?? this.fg,
      bg: bg ?? this.bg,
      underline: underline ?? this.underline,
      modifier: modifier ?? this.modifier,
      skip: skip ?? this.skip,
    );
  }

  @override
  String toString() {
    return 'Cell($_char, fg: $fg, bg: $bg, underline: $underline, modifier: $modifier, skip: $skip)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Cell &&
        other._char == _char &&
        other.fg == fg &&
        other.bg == bg &&
        other.underline == underline &&
        other.modifier == modifier &&
        other.skip == skip;
  }

  // coverage:ignore-start
  @override
  int get hashCode {
    return Object.hash(Cell, _char, fg, bg, underline, modifier, skip);
  }
  // coverage:ignore-end
}
