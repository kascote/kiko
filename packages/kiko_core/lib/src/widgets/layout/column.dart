import '../../layout/layout.dart';
import 'flex_layout.dart';

/// A widget that arranges its children vertically.
///
/// This is a convenience wrapper around [FlexLayout] with
/// [Direction.vertical].
class Column extends FlexLayout {
  /// Creates a vertical flex layout.
  Column({
    required super.children,
    super.margin,
    super.flex,
    super.spacing,
  }) : super(direction: Direction.vertical);
}
