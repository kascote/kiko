/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

export 'src/backend/backend.dart';
export 'src/buffer.dart';
export 'src/cell.dart';
export 'src/colors.dart';
export 'src/key_binding.dart';
export 'src/layout/margin.dart';
export 'src/layout/position.dart';
export 'src/layout/rect.dart';
export 'src/layout/size.dart';
export 'src/layout/spacing.dart';
export 'src/mvu/auto_id.dart';
export 'src/mvu/cmd.dart';
export 'src/mvu/focus.dart';
// RawPointerMsg is the un-routed form a mouse event takes in the queue. The
// router replaces it with a PointerMsg before update runs, so nothing outside
// the runtime can hold one.
export 'src/mvu/msg.dart' hide RawPointerMsg;
export 'src/mvu/mvu_runtime.dart';
// isWheelAction is the router's own termparser-facing helper, marked
// @internal; PointerMsg.isWheel is the public surface for the same question.
export 'src/mvu/pointer_msg.dart' hide isWheelAction;
export 'src/mvu/update_context.dart';
export 'src/plume/aliases.dart';
export 'src/plume/box.dart';
export 'src/plume/buffer_surface.dart';
export 'src/plume/containers.dart';
export 'src/plume/node_view.dart';
export 'src/plume/paint_line.dart';
export 'src/plume/paint_token.dart';
export 'src/plume/tagged.dart';
export 'src/plume/term_unicode_measurer.dart';
export 'src/plume/view.dart';
export 'src/plume/viewport.dart';
export 'src/style.dart';
export 'src/style_resolver.dart';
export 'src/terminal/application.dart';
export 'src/terminal/terminal.dart';
export 'src/text/line.dart';
export 'src/text/styled_char.dart';
export 'src/text/text.dart';
export 'src/theme.dart';
export 'src/tone.dart';
export 'src/widget_state.dart';
export 'src/widgets/border_type.dart';
export 'src/widgets/frame.dart';
export 'src/widgets/hit_map.dart';
