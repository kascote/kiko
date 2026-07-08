import 'package:kiko/kiko.dart';

import 'modal_model.dart';

/// Frames [content] as a dialog: a bordered, backgrounded box tagged with
/// [id] so a click inside it resolves back through [Frame.hitId].
///
/// This is the plume-native replacement for the old `Modal`'s chrome — it
/// carries no behaviour of its own. Pass [ModalModel]'s id for the static
/// confirm/cancel case, or any other widget model's id to frame a fully
/// custom inner MVU the same way.
Node modalDialog({
  required String id,
  required Node content,
  required Theme theme,
  BorderType border = BorderType.rounded,
  Style? borderStyle,
  Style? background,
  List<Line> topTitles = const <Line>[],
}) {
  return Box(
    border: border,
    borderStyle: borderStyle ?? StyleResolver(theme).border(const {}),
    background: background ?? theme.surface.fill,
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: topTitles,
    child: NodeView(content),
  ).build()..tag = id;
}

/// Centres [dialog] at a fixed [width]/[height] within [area], as a floating
/// layer with nothing else composited under it.
///
/// [area] is the full viewport — pass [Frame.area]. Sizing is fixed rather
/// than constraint-based because a dialog's whole point is a stable size
/// regardless of what's behind it.
Node centeredOverlay({
  required Node dialog,
  required Rect area,
  required int width,
  required int height,
}) {
  final left = ((area.width - width) / 2).round().clamp(0, area.width);
  final top = ((area.height - height) / 2).round().clamp(0, area.height);
  return Stack(
    fit: StackFit.expand,
    children: <View>[
      Positioned(left: left, top: top, width: width, height: height, child: NodeView(dialog)),
    ],
  ).build();
}

/// Renders [base], then — when [dialog] is non-null — dims the painted
/// backdrop and layers [dialog] centred over it at [width]x[height].
///
/// This is the two-pass render the old `Modal.render()` did procedurally
/// (`dimBackdrop` then paint on top): [Frame.dimBackdrop] operates on the
/// already-painted buffer, so it must run *between* two [Frame.render] calls
/// rather than inside one composed tree. Pass `dim: false` to skip the
/// backdrop dim entirely.
void renderModalOverlay(
  Frame frame, {
  required Node base,
  required int width,
  required int height,
  Node? dialog,
  bool dim = true,
  double dimFactor = 0.3,
}) {
  frame.render(NodeView(base));
  if (dialog == null) return;
  if (dim) frame.dimBackdrop(factor: dimFactor);
  frame.render(NodeView(centeredOverlay(dialog: dialog, area: frame.area, width: width, height: height)));
}
