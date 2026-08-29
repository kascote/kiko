import 'package:kiko/kiko.dart';

/// Delivers a frame's reports to the model that owns them, the way the
/// runtime queues them after the commit.
extension DeliverReports on Frame {
  /// Hands every report on this frame to [owner]'s `update`, in paint order.
  void deliverReports(Component owner) => reports.forEach(owner.update);
}
