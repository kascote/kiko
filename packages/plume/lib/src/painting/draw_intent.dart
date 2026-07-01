import 'package:meta/meta.dart';

import '../geometry/rect.dart';

/// A single recorded paint operation.
///
/// A `RecordingSurface` turns each `Surface` call into one of these, giving
/// tests an inspectable, diff-friendly list — the paint golden. [S] is the
/// opaque style token carried straight through from the widgets.
@immutable
sealed class DrawIntent<S> {
  const DrawIntent();
}

/// A run of text drawn at a cell position.
@immutable
class TextIntent<S> extends DrawIntent<S> {
  /// Records drawing [run] at cell ([x], [y]) with [style].
  const TextIntent(this.x, this.y, this.run, this.style);

  /// The column the run starts at.
  final int x;

  /// The row the run is drawn on.
  final int y;

  /// The graphemes drawn.
  final String run;

  /// The opaque style token for the run.
  final S style;

  @override
  bool operator ==(Object other) =>
      other is TextIntent<S> && other.x == x && other.y == y && other.run == run && other.style == style;

  @override
  int get hashCode => Object.hash(x, y, run, style);

  @override
  String toString() => 'drawText($x, $y, "$run", $style)';
}

/// A filled rectangle.
@immutable
class FillIntent<S> extends DrawIntent<S> {
  /// Records filling [rect] with [style].
  const FillIntent(this.rect, this.style);

  /// The filled region.
  final Rect rect;

  /// The opaque style token for the fill.
  final S style;

  @override
  bool operator ==(Object other) => other is FillIntent<S> && other.rect == rect && other.style == style;

  @override
  int get hashCode => Object.hash(rect, style);

  @override
  String toString() => 'fillRect($rect, $style)';
}

/// A border drawn around a rectangle.
@immutable
class BorderIntent<S> extends DrawIntent<S> {
  /// Records drawing a border around [rect] with [style].
  const BorderIntent(this.rect, this.style);

  /// The bordered region.
  final Rect rect;

  /// The opaque style token for the border.
  final S style;

  @override
  bool operator ==(Object other) => other is BorderIntent<S> && other.rect == rect && other.style == style;

  @override
  int get hashCode => Object.hash(rect, style);

  @override
  String toString() => 'drawBorder($rect, $style)';
}
