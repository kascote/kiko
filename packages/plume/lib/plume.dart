/// Plume — a Flutter-token, solver-free layout engine for cell grids (TUI).
///
/// The engine owns geometry only: it lays out a tree of nodes (constraints flow
/// down, sizes flow up) and emits draw intents against an injected surface, with
/// no dependency on any terminal backend or styling system.
library;

export 'src/geometry/box_constraints.dart';
export 'src/geometry/edge_insets.dart';
export 'src/geometry/offset.dart';
export 'src/geometry/rect.dart';
export 'src/geometry/size.dart';
export 'src/painting/clipping_surface.dart';
export 'src/painting/draw_intent.dart';
export 'src/painting/recording_surface.dart';
export 'src/painting/surface.dart';
export 'src/painting/text_measurer.dart';
export 'src/render/layout_context.dart';
export 'src/render/render_frame.dart';
export 'src/render/render_node.dart';
export 'src/render/single_child_node.dart';
export 'src/widgets/align.dart';
export 'src/widgets/alignment.dart';
export 'src/widgets/constrained_box.dart';
export 'src/widgets/container.dart';
export 'src/widgets/flex.dart';
export 'src/widgets/overlay.dart';
export 'src/widgets/padding.dart';
export 'src/widgets/sized_box.dart';
export 'src/widgets/stack.dart';
export 'src/widgets/text.dart';
