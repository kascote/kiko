/// Where a single child sits inside its parent's extra space.
enum Alignment {
  /// Top-left corner.
  topLeft,

  /// Top edge, centered horizontally.
  topCenter,

  /// Top-right corner.
  topRight,

  /// Left edge, centered vertically.
  centerLeft,

  /// Dead center.
  center,

  /// Right edge, centered vertically.
  centerRight,

  /// Bottom-left corner.
  bottomLeft,

  /// Bottom edge, centered horizontally.
  bottomCenter,

  /// Bottom-right corner.
  bottomRight;

  /// The child's x-offset given [free] cells of horizontal slack.
  int alignX(int free) => switch (this) {
    Alignment.topLeft || Alignment.centerLeft || Alignment.bottomLeft => 0,
    Alignment.topCenter || Alignment.center || Alignment.bottomCenter => free ~/ 2,
    Alignment.topRight || Alignment.centerRight || Alignment.bottomRight => free,
  };

  /// The child's y-offset given [free] cells of vertical slack.
  int alignY(int free) => switch (this) {
    Alignment.topLeft || Alignment.topCenter || Alignment.topRight => 0,
    Alignment.centerLeft || Alignment.center || Alignment.centerRight => free ~/ 2,
    Alignment.bottomLeft || Alignment.bottomCenter || Alignment.bottomRight => free,
  };
}
