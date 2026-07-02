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
  /// Records drawing [run] at cell ([x], [y]) with [style], optionally clipped
  /// to [clip].
  const TextIntent(this.x, this.y, this.run, this.style, {this.clip});

  /// The column the run starts at.
  final int x;

  /// The row the run is drawn on.
  final int y;

  /// The graphemes drawn.
  final String run;

  /// The opaque style token for the run.
  final S style;

  /// The active clip the backend must honor, or `null` when the clip fully
  /// contained the run so no trimming is needed.
  final Rect? clip;

  @override
  bool operator ==(Object other) =>
      other is TextIntent<S> &&
      other.x == x &&
      other.y == y &&
      other.run == run &&
      other.style == style &&
      other.clip == clip;

  @override
  int get hashCode => Object.hash(x, y, run, style, clip);

  @override
  String toString() => 'drawText($x, $y, "$run", $style${_clipSuffix(clip)})';
}

/// A filled rectangle.
@immutable
class FillIntent<S> extends DrawIntent<S> {
  /// Records filling [rect] with [style], optionally clipped to [clip].
  const FillIntent(this.rect, this.style, {this.clip});

  /// The filled region.
  final Rect rect;

  /// The opaque style token for the fill.
  final S style;

  /// The active clip the backend must honor, or `null` when the clip fully
  /// contained the fill.
  final Rect? clip;

  @override
  bool operator ==(Object other) =>
      other is FillIntent<S> && other.rect == rect && other.style == style && other.clip == clip;

  @override
  int get hashCode => Object.hash(rect, style, clip);

  @override
  String toString() => 'fillRect($rect, $style${_clipSuffix(clip)})';
}

/// A border drawn around a rectangle.
@immutable
class BorderIntent<S> extends DrawIntent<S> {
  /// Records drawing a border around [rect] with [style], optionally clipped to
  /// [clip].
  const BorderIntent(this.rect, this.style, {this.clip});

  /// The bordered region.
  final Rect rect;

  /// The opaque style token for the border.
  final S style;

  /// The active clip the backend must honor, or `null` when the clip fully
  /// contained the border. The border is always recorded around the original
  /// [rect]; the clip drops the perimeter cells that fall outside it rather
  /// than re-bordering a shrunken rect (which would fabricate edges at the clip
  /// line).
  final Rect? clip;

  @override
  bool operator ==(Object other) =>
      other is BorderIntent<S> && other.rect == rect && other.style == style && other.clip == clip;

  @override
  int get hashCode => Object.hash(rect, style, clip);

  @override
  String toString() => 'drawBorder($rect, $style${_clipSuffix(clip)})';
}

/// Renders the trailing `, clip: ...` a draw intent shows only when it carries
/// a clip, so an unclipped intent's string is unchanged.
String _clipSuffix(Rect? clip) => clip == null ? '' : ', clip: $clip';
