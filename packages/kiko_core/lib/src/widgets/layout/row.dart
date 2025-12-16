import '../../layout/layout.dart';
import 'flex_layout.dart';

/// A widget that arranges its children horizontally.
///
/// This is a convenience wrapper around [FlexLayout] with
/// [Direction.horizontal].
class Row extends FlexLayout {
  /// Creates a horizontal flex layout.
  Row({
    required super.children,
    super.margin,
    super.flex,
    super.spacing,
  }) : super(direction: Direction.horizontal);
}
