import '../render/render_node.dart';
import 'stack.dart';

/// Composites a base tree with floating layers painted on top of it.
///
/// The base is the main UI, sized to fill the viewport. Each overlay — a modal,
/// menu, or tooltip — is an extra layer painted after the base, so the last
/// entry sits on top. An overlay is placed like any [Stack] child: wrap it in a
/// [Positioned] to anchor it (and let clicks outside it fall through), or leave
/// it non-positioned to fill the viewport as a blocking layer. Hit testing walks
/// the layers front-to-back before the base, so a click lands on the top-most
/// layer under it. This is the real paint-order model that replaces ad-hoc
/// redraw ordering.
class Overlay<S> extends Stack<S> {
  /// Composites [base] under the given [overlays], the last painted on top.
  Overlay({required RenderNode<S> base, List<RenderNode<S>>? overlays})
    : super(children: <RenderNode<S>>[base, ...?overlays], fit: StackFit.expand);
}
