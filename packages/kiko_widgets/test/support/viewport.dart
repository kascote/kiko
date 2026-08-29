import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

/// Reports a painted viewport to a windowed widget's model, the way its view
/// does from paint.
extension ReportViewport on Component {
  /// Delivers `ViewportChanged(id, rows: rows, cols: cols)` through [update]
  /// and returns the verdict: the demand pass for the pages the viewport
  /// reveals, when any are missing.
  UpdateResult viewport({required int rows, int? cols}) => update(ViewportChanged(id, rows: rows, cols: cols));
}
