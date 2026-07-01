import 'package:meta/meta.dart';

/// A width and height measured in whole terminal cells.
///
/// Sizes flow *up* the layout tree: each node reports the [Size] it chose given
/// the constraints handed down to it. Both fields are cell counts; there are no
/// fractional cells.
@immutable
class Size {
  /// Creates a size [w] cells wide by [h] cells tall.
  const Size(this.w, this.h);

  /// A zero-area size (`0` × `0`).
  static const Size zero = Size(0, 0);

  /// The width in cells.
  final int w;

  /// The height in cells.
  final int h;

  /// A size whose width and height are the component-wise sum of this and
  /// [other].
  Size operator +(Size other) => Size(w + other.w, h + other.h);

  @override
  bool operator ==(Object other) => other is Size && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(w, h);

  @override
  String toString() => 'Size($w, $h)';
}
