import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// The viewport a windowed widget painted: how many rows it showed and, for a
/// table, how many columns.
///
/// The view reports one from paint through `BufferSurface.report`, addressed
/// to the widget's id, only when the count differs from the one the model
/// holds. A part painted under a composite's scope reports the scoped path —
/// `combo/list` — so the router delivers it to the composite, which forwards
/// it by leaf. The owner's `update` stores the count and returns the demand
/// pass for the pages the viewport now needs; it keeps a compare against the
/// count it holds as a guard, answering `Handled` with no command.
@immutable
class ViewportChanged extends FrameReport {
  /// Creates a report that the widget registered under [id] painted [rows]
  /// rows and, when it windows columns too, [cols] columns.
  const ViewportChanged(super.id, {required this.rows, this.cols});

  /// The rows the viewport showed.
  final int rows;

  /// The columns the viewport showed, or null for a widget that windows rows
  /// only.
  final int? cols;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ViewportChanged && other.id == id && other.rows == rows && other.cols == cols;

  @override
  int get hashCode => Object.hash(id, rows, cols);

  @override
  String toString() => 'ViewportChanged($id, rows: $rows, cols: $cols)';
}
