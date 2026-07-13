import 'dart:io';

import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// Resize the terminal window (or drag its corner) and watch three things
// update: the live cell/pixel readout, the resize counter, and the ruler
// bar below it, which redraws to the new width on every frame.
//
// The counter is what makes coalescing visible — `ResizeMsg` is
// position-valued, so a fast, continuous drag that fires many resize events
// still only ever queues the latest one; the counter climbs by ones, not by
// however many events the terminal actually sent.
//
// The model never polls for its own size. `ctx.area` seeds it once at
// startup (`InitMsg`), and every change after that arrives as a `ResizeMsg`.
// Rendering itself needs none of this — `Terminal.draw` re-measures the
// terminal before every frame regardless — this example just reacts to the
// message for display, the way an app would recompute a scroll clamp or
// reflow content.
//
// q quits.
// ═══════════════════════════════════════════════════════════

/// Tracks the terminal's current size and how many resizes have arrived.
class ResizeModel {
  /// Current width, in cells.
  int width = 0;

  /// Current height, in cells.
  int height = 0;

  /// Current width, in pixels, or 0 if the terminal never reports pixels.
  int widthPixels = 0;

  /// Current height, in pixels, or 0 if the terminal never reports pixels.
  int heightPixels = 0;

  /// How many [ResizeMsg]s have landed since startup.
  int resizeCount = 0;
}

/// Handles key and resize messages for [ResizeModel].
(ResizeModel, Cmd?) update(ResizeModel model, Msg msg, UpdateContext ctx) {
  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());

    // Seeds the initial size once, before the first frame. A ResizeMsg only
    // arrives on a later change, so without this the readout would show
    // 0×0 until the window was actually resized.
    case InitMsg():
      model
        ..width = ctx.area.width
        ..height = ctx.area.height;
      return (model, null);

    case ResizeMsg(:final width, :final height, :final widthPixels, :final heightPixels):
      model
        ..width = width
        ..height = height
        ..widthPixels = widthPixels
        ..heightPixels = heightPixels
        ..resizeCount += 1;
      return (model, null);

    default:
      return (model, null);
  }
}

/// Renders the size readout, the resize counter, and a ruler bar sized from
/// the model's tracked width.
void view(ResizeModel model, Frame frame) {
  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line(
          'Resize the window — q quits',
          style: const Style(fg: Color.darkGray),
        ),
      ),
      const SizedBox(height: 1),
      _readout(model),
      const SizedBox(height: 1),
      _ruler(model),
      _breakpoint(model),
      const Expanded(child: SizedBox()),
    ],
  );

  frame.render(ui);
}

View _readout(ResizeModel model) => Container(
  border: BorderType.plain,
  topTitles: [Line('size')],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line('cells   : ${model.width}×${model.height}'),
      Line('pixels  : ${_pixelLabel(model)}'),
      Line('resizes : ${model.resizeCount}'),
    ],
  ),
);

String _pixelLabel(ResizeModel model) {
  if (model.widthPixels == 0 && model.heightPixels == 0) return 'pixels not reported';
  return '${model.widthPixels}×${model.heightPixels}';
}

/// A bar as wide as the tracked width, so it visibly grows and shrinks with
/// the window — the simplest thing that reflows.
View _ruler(ResizeModel model) => Line('─' * model.width, style: const Style(fg: Color.cyan));

/// A width breakpoint label, the kind of decision a responsive layout would
/// make from the same tracked width.
View _breakpoint(ResizeModel model) {
  final label = switch (model.width) {
    < 40 => 'narrow',
    < 80 => 'medium',
    _ => 'wide',
  };
  return Line('breakpoint: $label (${model.width} cells wide)', style: const Style(fg: Color.yellow));
}

Future<void> main() async {
  exit(
    await Application(title: 'Resize').run(
      init: ResizeModel(),
      update: update,
      view: view,
    ),
  );
}
