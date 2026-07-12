import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

// ═══════════════════════════════════════════════════════════
// Engine HUD.
//
// A sprite bounces around, advanced by `FrameTickMsg` using its `delta` so
// motion is frame-rate independent. The HUD surfaces what the render engine is
// doing — FPS, frame number, delta — and, most usefully, the cells the double
// buffer redrew last frame (`Frame.lastDiffCount`).
//
// That last number is the point. A small sprite moving should redraw only a
// handful of cells, not the whole screen. Press space to pause: nothing moves,
// so the diff drops to 0. If double-buffering ever regressed into full repaints,
// this number would sit at width×height every frame.
// ═══════════════════════════════════════════════════════════

const _spriteW = 8;
const _spriteH = 4;

// Fixed HUD width so the box does not resize as the readout digits change.
const _hudW = 38;

class HudModel {
  // Sprite position (top-left) and velocity, in cells and cells/second.
  double x = 2;
  double y = 2;
  double vx = 22;
  double vy = 11;

  // Viewport size, learned from the frame each render so update can bounce.
  int areaW = 0;
  int areaH = 0;

  bool paused = false;

  // Last frame's timing, for the readout.
  Duration delta = Duration.zero;
  int frameNumber = 0;

  void advance(Duration dt) {
    final seconds = dt.inMicroseconds / 1e6;
    x += vx * seconds;
    y += vy * seconds;

    final maxX = (areaW - _spriteW).toDouble();
    final maxY = (areaH - _spriteH).toDouble();
    if (maxX <= 0 || maxY <= 0) return;

    if (x < 0) {
      x = -x;
      vx = -vx;
    } else if (x > maxX) {
      x = maxX - (x - maxX);
      vx = -vx;
    }
    if (y < 0) {
      y = -y;
      vy = -vy;
    } else if (y > maxY) {
      y = maxY - (y - maxY);
      vy = -vy;
    }
  }
}

(HudModel, Cmd?) update(HudModel model, Msg msg, UpdateContext _) {
  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());
    case KeyMsg(key: 'space'):
      model.paused = !model.paused;
      return (model, null);
    case FrameTickMsg(:final delta, :final frameNumber):
      // While paused nothing in the model changes, so consecutive frames are
      // byte-identical and the buffer diff is empty — the HUD reads 0 redrawn.
      if (model.paused) return (model, null);
      model
        ..delta = delta
        ..frameNumber = frameNumber
        ..advance(delta);
      return (model, null);
    default:
      return (model, null);
  }
}

void view(HudModel model, Frame frame) {
  // Learn the viewport so the next tick can bounce against real bounds.
  model
    ..areaW = frame.area.width
    ..areaH = frame.area.height;

  final ui = Stack(
    fit: plume.StackFit.expand,
    children: [
      // A full-size spacer gives the stack the whole viewport to place into.
      const SizedBox(),
      // The sprite.
      Positioned(
        left: model.x.round(),
        top: model.y.round(),
        width: _spriteW,
        height: _spriteH,
        child: _sprite(model),
      ),
      // The HUD, pinned top-left at a fixed width.
      Positioned(left: 0, top: 0, width: _hudW, child: _hud(model, frame)),
      // Hint, pinned bottom.
      Positioned(left: 0, bottom: 0, child: _hint(model)),
    ],
  );

  frame.render(ui);
}

View _sprite(HudModel model) => Container(
  background: Style(bg: model.paused ? Color.darkGray : Color.magenta),
  child: const SizedBox(),
);

View _hud(HudModel model, Frame frame) {
  final ms = model.delta.inMicroseconds / 1000;
  final fps = ms > 0 ? 1000 / ms : 0;
  final cells = frame.lastDiffCount;
  final total = frame.area.width * frame.area.height;
  final pct = total > 0 ? (100 * cells / total) : 0;

  return Container(
    border: BorderType.double,
    borderStyle: const Style(fg: Color.cyan),
    topTitles: [Line('engine', style: const Style(fg: Color.cyan))],
    background: const Style(bg: Color.black),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _stat('fps', fps.toStringAsFixed(1).padLeft(6)),
        _stat('frame #', '${model.frameNumber}'.padLeft(6)),
        _stat('delta ms', ms.toStringAsFixed(2).padLeft(6)),
        _stat(
          'cells redrawn',
          '${'$cells'.padLeft(4)} /${'$total'.padLeft(5)} (${pct.toStringAsFixed(1).padLeft(5)}%)',
          accent: true,
        ),
        _stat('sprite', '(${'${model.x.round()}'.padLeft(3)},${'${model.y.round()}'.padLeft(3)} )'),
      ],
    ),
  );
}

View _stat(String label, String value, {bool accent = false}) => Line.fromTexts([
  Text('${label.padRight(13)} ', style: const Style(fg: Color.darkGray)),
  Text(
    value,
    style: Style(
      fg: accent ? Color.brightGreen : Color.white,
      addModifier: accent ? Modifier.bold : Modifier.empty,
    ),
  ),
]);

View _hint(HudModel model) => Line(
  model.paused ? '⏸ paused — cells redrawn should be 0 · space resumes · q quits' : '▶ space pauses · q quits',
  style: const Style(fg: Color.darkGray),
);

void main() async {
  await Application(title: 'Engine HUD').run(
    init: HudModel(),
    update: update,
    view: view,
  );
}
