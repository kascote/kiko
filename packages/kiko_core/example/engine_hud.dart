import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

// ═══════════════════════════════════════════════════════════
// Engine HUD.
//
// A sprite bounces around, advanced by a one-shot `Tick` the app re-arms
// from every `TickMsg`, using `elapsed` so motion is rate independent. The
// HUD surfaces what the loop is doing — ticks per second, tick number, delta
// — and, most usefully, the cells the double buffer redrew last frame
// (`Frame.lastDiffCount`).
//
// That last number is the point. A small sprite moving should redraw only a
// handful of cells, not the whole screen. Press space to pause: the tick is
// not re-armed, nothing moves, and no frame is drawn at all — the diff stays
// at whatever the last moving frame cost. If double-buffering ever regressed
// into full repaints, this number would sit at width×height every frame.
// ═══════════════════════════════════════════════════════════

const _spriteW = 8;
const _spriteH = 4;

// Fixed HUD width so the box does not resize as the readout digits change.
const _hudW = 38;

// The animation's own id and step. No widget claims the id, so the ticks
// reach the app's update directly.
const _spriteId = 'sprite';
const _step = Duration(microseconds: 16667); // about 60 ticks a second

class HudModel {
  // Sprite position (top-left) and velocity, in cells and cells/second.
  double x = 2;
  double y = 2;
  double vx = 22;
  double vy = 11;

  bool paused = false;

  // The generation of the running tick chain: bumped on every resume, so a
  // tick armed before a pause is dropped when it lands, never re-armed.
  int chain = 0;

  // Last tick's timing, for the readout.
  Duration delta = Duration.zero;
  int tickNumber = 0;

  /// Moves the sprite by [dt] and bounces it off the edges of [area], the
  /// viewport the update context carries.
  void advance(Duration dt, Rect area) {
    final seconds = dt.inMicroseconds / 1e6;
    x += vx * seconds;
    y += vy * seconds;

    final maxX = (area.width - _spriteW).toDouble();
    final maxY = (area.height - _spriteH).toDouble();
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

/// Arms the next step of the sprite's tick chain.
Cmd _tick(HudModel model) => Tick(_step, id: _spriteId, key: model.chain);

(HudModel, Cmd?) update(HudModel model, Msg msg, UpdateContext ctx) {
  switch (msg) {
    case InitMsg():
      return (model, _tick(model));
    case KeyMsg(key: 'q'):
      return (model, const Quit());
    case KeyMsg(key: 'space'):
      model.paused = !model.paused;
      // Pausing stops the chain by not re-arming; resuming starts a fresh
      // one, so a tick still pending from before the pause is stale.
      if (model.paused) return (model, null);
      model.chain++;
      return (model, _tick(model));
    case TickMsg(id: _spriteId, :final key, :final elapsed):
      if (model.paused || key != model.chain) return (model, null);
      model
        ..delta = elapsed
        ..tickNumber += 1
        ..advance(elapsed, ctx.area);
      return (model, _tick(model));
    default:
      return (model, null);
  }
}

void view(HudModel model, Frame frame) {
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
  ground: Style(bg: model.paused ? Color.darkGray : Color.magenta),
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
    ground: const Style(bg: Color.black),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _stat('ticks/s', fps.toStringAsFixed(1).padLeft(6)),
        _stat('tick #', '${model.tickNumber}'.padLeft(6)),
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
  model.paused ? '⏸ paused — no ticks, no frames · space resumes · q quits' : '▶ space pauses · q quits',
  style: const Style(fg: Color.darkGray),
);

Future<void> main() async {
  exit(
    await Application(title: 'Engine HUD').run(
      init: HudModel(),
      update: update,
      view: view,
    ),
  );
}
