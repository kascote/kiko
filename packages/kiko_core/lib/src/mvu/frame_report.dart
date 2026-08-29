import 'addressed.dart';
import 'msg.dart';

/// A layout fact paint hands back to the model that owns it.
///
/// A node that learns something during paint that its model needs — how many
/// rows it showed, say — appends one through `BufferSurface.report` instead of
/// writing into the model. The frame keeps the last report per [id] and type,
/// `CompletedFrame.reports` carries them out of the draw, and the runtime
/// queues each one as a message once the frame commits. The owner's `update`
/// compares the report to what it holds and returns a command only when the
/// fact changed.
///
/// Extend it beside the model that consumes it; core carries reports and never
/// reads them. A report is [Addressed], so a focus router delivers it to its
/// owner by [id]. An app without a router matches on it in its own `update`.
abstract class FrameReport extends Msg implements Addressed {
  /// Creates a report for the widget registered under [id].
  const FrameReport(this.id);

  /// The stable id of the widget this report is for.
  @override
  final String id;
}
