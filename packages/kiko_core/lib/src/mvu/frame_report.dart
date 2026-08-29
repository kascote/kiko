import 'addressed.dart';
import 'msg.dart';

/// A layout fact paint hands back to the model that owns it.
///
/// A node that learns something during paint that its model needs — how many
/// rows it showed, say — appends one through `BufferSurface.report` instead of
/// writing into the model. The frame keeps the last report per [id] and type,
/// `CompletedFrame.reports` carries them out of the draw, and the runtime
/// queues each one as a message once the frame commits. The owner's `update`
/// stores the fact and returns the command it calls for.
///
/// Paint reports a fact only when it differs from the fact the model already
/// holds. The view has both — the value it just measured and the model it
/// paints from — so that compare lives in paint. Once the report lands the
/// model holds the fact and the next paint has nothing to say, so a frame
/// caused by a report settles. The runtime queues every report a frame
/// carries and keeps no memory between frames.
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
