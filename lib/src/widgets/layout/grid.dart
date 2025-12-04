import 'package:meta/meta.dart';

import '../../layout/constraint.dart';
import '../../layout/rect.dart';
import '../frame.dart';
import 'column.dart';
import 'layout_child.dart';
import 'row.dart';

/// A widget that arranges children in a grid of rows and columns.
///
/// [Grid] composes nested [Row] and [Column] widgets internally, applying
/// uniform constraints to rows and columns.
///
/// Example:
/// ```dart
/// Grid(
///   rows: 3,
///   columns: 4,
///   rowConstraint: const ConstraintLength(5),
///   columnConstraint: const ConstraintLength(10),
///   cellBuilder: (row, col) => Text.raw('$row,$col'),
/// )
/// ```
@immutable
class Grid implements Widget {
  /// Number of rows in the grid.
  final int rows;

  /// Number of columns in the grid.
  final int columns;

  /// Constraint applied to each row.
  final Constraint rowConstraint;

  /// Constraint applied to each column.
  final Constraint columnConstraint;

  /// Builder function that creates a widget for each cell.
  ///
  /// Called with (row, column) indices, both 0-based.
  final Widget Function(int row, int column) cellBuilder;

  /// Creates a grid layout widget.
  const Grid({
    required this.rows,
    required this.columns,
    required this.rowConstraint,
    required this.columnConstraint,
    required this.cellBuilder,
  });

  @override
  void render(Rect area, Frame frame) {
    Column(
      children: List.generate(
        rows,
        (r) => ConstraintChild(
          rowConstraint,
          child: Row(
            children: List.generate(
              columns,
              (c) => ConstraintChild(columnConstraint, child: cellBuilder(r, c)),
            ),
          ),
        ),
      ),
    ).render(area, frame);
  }
}
