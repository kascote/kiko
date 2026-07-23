/// A discrete part of a widget's painted surface — a row, a header, an expand
/// indicator — that the widget marked while painting and the framework resolves
/// under a pointer.
///
/// `Region` is an empty marker. The framework carries it opaquely, the way it
/// carries `Msg` and `Cmd`: it never enumerates the concrete kinds. Each widget
/// package defines its own sealed hierarchy of regions next to its model and
/// switches over its own types; the framework only ferries whichever instance a
/// widget marked under the pointer, delivering it on `PointerMsg.region`.
///
/// A view marks a region by painting its part with the region as the plume mark
/// key (`RenderNode.markRegion`); the framework then resolves the innermost
/// marked region under the pointer, within the target widget's own subtree, so
/// a model switches over the part it landed on instead of re-deriving which part
/// a coordinate falls on. Concrete regions are plain value classes with
/// structural equality, like the widgets' typed load keys.
abstract interface class Region {}
