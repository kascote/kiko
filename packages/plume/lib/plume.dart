/// Plume — a Flutter-style, solver-free layout engine for cell grids (TUI).
///
/// The engine owns geometry only: it lays out a tree of nodes (constraints flow
/// down, sizes flow up) and emits draw intents against an injected surface, with
/// no dependency on any terminal backend or styling system.
library;

export 'src/geometry/box_constraints.dart';
export 'src/geometry/offset.dart';
export 'src/geometry/rect.dart';
export 'src/geometry/size.dart';
export 'src/painting/surface.dart';
export 'src/render/render_node.dart';
export 'src/widgets/sized_box.dart';
