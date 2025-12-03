import 'package:meta/meta.dart';

import '../../layout/rect.dart';
import '../frame.dart';

/// A widget that defers child creation until the allocated area is known.
///
/// When building a widget tree, child areas aren't computed yet - they're only
/// determined at render time when the layout splits the parent area. This widget
/// lets you make decisions about which widget to create based on the actual
/// allocated space for this specific child slot.
///
/// Without [LayoutBuilder], you'd need to create a custom [Widget] class:
/// ```dart
/// class MyResponsiveWidget implements Widget {
///   @override
///   void render(Rect area, Frame frame) {
///     final child = area.width > 50 ? FullLayout() : CompactLayout();
///     child.render(area, frame);
///   }
/// }
/// ```
///
/// With [LayoutBuilder], you can inline this decision in the widget tree:
/// ```dart
/// Column(
///   children: [
///     Fixed(3, child: Header()),
///     Expanded(
///       child: LayoutBuilder(
///         builder: (rect) => rect.width > 50 ? FullLayout() : CompactLayout(),
///       ),
///     ),
///   ],
/// )
/// ```
///
/// The [builder] receives the allocated [Rect] for this child slot (not the
/// parent's area), enabling size-dependent widget construction without
/// boilerplate.
@immutable
class LayoutBuilder implements Widget {
  /// The builder function that receives the allocated [Rect] and returns
  /// a widget to render.
  final Widget Function(Rect area) builder;

  /// Creates a layout builder widget.
  const LayoutBuilder({required this.builder});

  @override
  void render(Rect area, Frame frame) {
    builder(area).render(area, frame);
  }
}
