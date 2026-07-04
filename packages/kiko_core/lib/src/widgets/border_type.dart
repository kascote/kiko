/// The type of border to display around a block.
enum BorderType {
  /// No border
  none,

  /// Custom defined border
  custom,

  /// A plain, simple border.
  ///
  /// This is the default
  ///
  /// # Example
  ///
  /// ```plain
  /// ┌───────┐
  /// │       │
  /// └───────┘
  /// ```
  plain,

  /// A plain border with rounded corners.
  ///
  /// # Example
  ///
  /// ```plain
  /// ╭───────╮
  /// │       │
  /// ╰───────╯
  /// ```
  rounded,

  /// A doubled border.
  ///
  /// Note this uses one character that draws two lines.
  ///
  /// # Example
  ///
  /// ```plain
  /// ╔═══════╗
  /// ║       ║
  /// ╚═══════╝
  /// ```
  double,

  /// A thick border.
  ///
  /// # Example
  ///
  /// ```plain
  /// ┏━━━━━━━┓
  /// ┃       ┃
  /// ┗━━━━━━━┛
  /// ```
  thick,

  /// A border with a single line on the inside of a half block.
  ///
  /// # Example
  ///
  /// ```plain
  /// ▗▄▄▄▄▄▄▄▖
  /// ▐       ▌
  /// ▐       ▌
  /// ▝▀▀▀▀▀▀▀▘
  quadrantInside,

  /// A border with a single line on the outside of a half block.
  ///
  /// # Example
  ///
  /// ```plain
  /// ▛▀▀▀▀▀▀▀▜
  /// ▌       ▐
  /// ▌       ▐
  /// ▙▄▄▄▄▄▄▄▟
  quadrantOutside,
}

/// A set of border characters to use when rendering a block.
typedef BorderSet = ({
  String topLeft,
  String topRight,
  String bottomLeft,
  String bottomRight,
  String left,
  String right,
  String top,
  String bottom,
});

const _quadrantTopLeft = '▘';
const _quadrantTopRight = '▝';
const _quadrantBottomLeft = '▖';
const _quadrantBottomRight = '▗';
const _quadrantTopHalf = '▀';
const _quadrantBottomHalf = '▄';
const _quadrantLeftHalf = '▌';
const _quadrantRightHalf = '▐';
const _quadrantTopLeftBottomLeftBottomRight = '▙';
const _quadrantTopLeftTopRightBottomLeft = '▛';
const _quadrantTopLeftTopRightBottomRight = '▜';
const _quadrantTopRightBottomLeftBottomRight = '▟';

/// Utility functions for [BorderType].
extension BorderTypeUtils on BorderType {
  /// Returns the symbols to use for the given [BorderType].
  BorderSet symbols(BorderType type) => switch (type) {
    BorderType.none => (
      top: ' ',
      bottom: ' ',
      left: ' ',
      right: ' ',
      topLeft: ' ',
      topRight: ' ',
      bottomLeft: ' ',
      bottomRight: ' ',
    ),
    BorderType.plain => (
      top: '─',
      bottom: '─',
      left: '│',
      right: '│',
      topLeft: '┌',
      topRight: '┐',
      bottomLeft: '└',
      bottomRight: '┘',
    ),
    BorderType.rounded => (
      top: '─',
      bottom: '─',
      left: '│',
      right: '│',
      topLeft: '╭',
      topRight: '╮',
      bottomLeft: '╰',
      bottomRight: '╯',
    ),
    BorderType.double => (
      top: '═',
      bottom: '═',
      left: '║',
      right: '║',
      topLeft: '╔',
      topRight: '╗',
      bottomLeft: '╚',
      bottomRight: '╝',
    ),
    BorderType.thick => (
      top: '━',
      bottom: '━',
      left: '┃',
      right: '┃',
      topLeft: '┏',
      topRight: '┓',
      bottomLeft: '┗',
      bottomRight: '┛',
    ),
    BorderType.quadrantInside => (
      topRight: _quadrantBottomLeft,
      topLeft: _quadrantBottomRight,
      bottomRight: _quadrantTopLeft,
      bottomLeft: _quadrantTopRight,
      left: _quadrantRightHalf,
      right: _quadrantLeftHalf,
      top: _quadrantBottomHalf,
      bottom: _quadrantTopHalf,
    ),
    BorderType.quadrantOutside => (
      topLeft: _quadrantTopLeftTopRightBottomLeft,
      topRight: _quadrantTopLeftTopRightBottomRight,
      bottomLeft: _quadrantTopLeftBottomLeftBottomRight,
      bottomRight: _quadrantTopRightBottomLeftBottomRight,
      left: _quadrantLeftHalf,
      right: _quadrantRightHalf,
      top: _quadrantTopHalf,
      bottom: _quadrantBottomHalf,
    ),
    _ => throw ArgumentError('Invalid border type: $type'),
  };
}
