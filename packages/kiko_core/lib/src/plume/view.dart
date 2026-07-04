import 'aliases.dart';

/// An immutable description of a piece of UI.
///
/// A view is the thing you compose: text, containers, and widgets are all
/// views, so they nest inside one another through a single vocabulary. Each
/// view knows how to turn itself into the render object that lays it out and
/// paints it.
///
/// [build] inflates the view into a fresh plume [Node] on every call — nothing
/// is cached or shared between frames. The render tree is rebuilt from the views
/// each frame.
// ignore: one_member_abstracts
abstract interface class View {
  /// Inflates this view into a fresh plume [Node] ready for layout and paint.
  Node build();
}
