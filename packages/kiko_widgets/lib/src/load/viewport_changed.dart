import 'package:kiko/kiko.dart';

/// The viewport a windowed widget painted: how many rows it showed and, for a
/// table, how many columns.
///
/// The view reports one from paint through `BufferSurface.report`, addressed
/// to the widget's id. A part painted under a composite's scope reports the
/// scoped path — `combo/list` — so the router delivers it to the composite,
/// which forwards it by leaf. The owner's `update` compares the report to the
/// count it holds: an unchanged report is `Handled` with no command; a changed
/// one stores the count and returns the demand pass for the pages the viewport
/// now needs.
class ViewportChanged extends FrameReport {
  /// Creates a report that the widget registered under [id] painted [rows]
  /// rows and, when it windows columns too, [cols] columns.
  const ViewportChanged(super.id, {required this.rows, this.cols});

  /// The rows the viewport showed.
  final int rows;

  /// The columns the viewport showed, or null for a widget that windows rows
  /// only.
  final int? cols;
}
