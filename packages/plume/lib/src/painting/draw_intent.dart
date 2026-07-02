import 'package:meta/meta.dart';

import '../geometry/rect.dart';

/// A single recorded paint operation.
///
/// A `RecordingSurface` turns each `Surface` call into one of these, giving
/// tests an inspectable, diff-friendly list — the paint golden. [T] is the
/// opaque paint token carried straight through from the widgets.
@immutable
sealed class DrawIntent<T> {
  const DrawIntent();
}

/// A run of text drawn at a cell position.
@immutable
class TextIntent<T> extends DrawIntent<T> {
  /// Records drawing [run] at cell ([x], [y]) with [token], optionally clipped
  /// to [clip].
  const TextIntent(this.x, this.y, this.run, this.token, {this.clip});

  /// The column the run starts at.
  final int x;

  /// The row the run is drawn on.
  final int y;

  /// The graphemes drawn.
  final String run;

  /// The opaque paint token for the run.
  final T token;

  /// The active clip the backend must honor, or `null` when the clip fully
  /// contained the run so no trimming is needed.
  final Rect? clip;

  @override
  bool operator ==(Object other) =>
      other is TextIntent<T> &&
      other.x == x &&
      other.y == y &&
      other.run == run &&
      other.token == token &&
      other.clip == clip;

  @override
  int get hashCode => Object.hash(x, y, run, token, clip);

  @override
  String toString() => 'drawText($x, $y, "$run", $token${_clipSuffix(clip)})';
}

/// A filled rectangle.
@immutable
class FillIntent<T> extends DrawIntent<T> {
  /// Records filling [rect] with [token], optionally clipped to [clip].
  const FillIntent(this.rect, this.token, {this.clip});

  /// The filled region.
  final Rect rect;

  /// The opaque paint token for the fill.
  final T token;

  /// The active clip the backend must honor, or `null` when the clip fully
  /// contained the fill.
  final Rect? clip;

  @override
  bool operator ==(Object other) =>
      other is FillIntent<T> && other.rect == rect && other.token == token && other.clip == clip;

  @override
  int get hashCode => Object.hash(rect, token, clip);

  @override
  String toString() => 'fillRect($rect, $token${_clipSuffix(clip)})';
}

/// A border drawn around a rectangle.
@immutable
class BorderIntent<T> extends DrawIntent<T> {
  /// Records drawing a border around [rect] with [token], optionally clipped to
  /// [clip].
  const BorderIntent(this.rect, this.token, {this.clip});

  /// The bordered region.
  final Rect rect;

  /// The opaque paint token for the border.
  final T token;

  /// The active clip the backend must honor, or `null` when the clip fully
  /// contained the border. The border is always recorded around the original
  /// [rect]; the clip drops the perimeter cells that fall outside it rather
  /// than re-bordering a shrunken rect (which would fabricate edges at the clip
  /// line).
  final Rect? clip;

  @override
  bool operator ==(Object other) =>
      other is BorderIntent<T> && other.rect == rect && other.token == token && other.clip == clip;

  @override
  int get hashCode => Object.hash(rect, token, clip);

  @override
  String toString() => 'drawBorder($rect, $token${_clipSuffix(clip)})';
}

/// Renders the trailing `, clip: ...` a draw intent shows only when it carries
/// a clip, so an unclipped intent's string is unchanged.
String _clipSuffix(Rect? clip) => clip == null ? '' : ', clip: $clip';
