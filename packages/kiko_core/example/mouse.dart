import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

// ═══════════════════════════════════════════════════════════
// Interactive mouse playground.
//
// Exercises the routing layer end to end: swatches and a floating panel stamp a
// stable id on their subtree with `Tagged`, and a mouse event arrives at
// `update` already resolved to that id.
//
// Nothing here hit-tests. `PointerMsg.targetId` names the widget, `local` gives
// the cursor in that widget's own cells, and pressing the panel hands it the
// pointer until the button comes up — so the drag survives a cursor that
// outruns it. `PointerLeaveMsg` says when hover ends, `PointerCancelMsg` when a
// drag was abandoned rather than finished.
// ═══════════════════════════════════════════════════════════

const _cols = 6;
const _rows = 3;

const _palette = <Color>[
  Color.red, Color.green, Color.yellow, Color.blue, Color.magenta, Color.cyan, //
  Color.brightRed, Color.brightGreen, Color.brightYellow, Color.brightBlue, Color.brightMagenta, Color.brightCyan, //
  Color.gray, Color.darkGray, Color.white, Color.red, Color.green, Color.blue, //
];

class MouseModel {
  String? selectedId;
  String? hoverId;

  /// Where the selected swatch was painted, read off the hit map that resolved
  /// the click.
  Rect? selectedRect;

  // Floating panel position and drag bookkeeping.
  int panelX = 4;
  int panelY = 2;
  bool dragging = false;
  int grabDX = 0; // cursor offset within the panel when the drag began
  int grabDY = 0;

  int mouseX = 0;
  int mouseY = 0;
}

(MouseModel, Cmd?) update(MouseModel model, Msg msg, UpdateContext _) {
  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());

    // The pointer left whatever it was over. Nothing else has to notice.
    case PointerLeaveMsg(:final targetId):
      if (model.hoverId == targetId) model.hoverId = null;
      return (model, null);

    // The drag was abandoned — the cursor left the window, or focus went
    // elsewhere. End it, and do not commit where the panel happened to be.
    case PointerCancelMsg():
      model.dragging = false;
      return (model, null);

    case final PointerMsg m:
      model
        ..mouseX = m.global.x
        ..mouseY = m.global.y;

      if (m.isMove) {
        model.hoverId = m.targetId;
        return (model, null);
      }

      // Button down: grab the panel, or select a swatch. `local` is already the
      // grab offset — the cursor counted from the panel's own top-left cell.
      if (m.isDown) {
        if (m.targetId == 'panel') {
          model
            ..dragging = true
            ..grabDX = m.local.x
            ..grabDY = m.local.y;
        } else if (m.targetId case final id? when id.startsWith('swatch-')) {
          model
            ..selectedId = id
            ..selectedRect = m.targetRect;
        }
        return (model, null);
      }

      // Drag: the press captured the panel, so every drag still addresses it
      // even when the cursor has run off it. Keep the grab point under the
      // cursor.
      if (m.isDrag && model.dragging) {
        model
          ..panelX = (m.global.x - model.grabDX).clamp(0, 1 << 20)
          ..panelY = (m.global.y - model.grabDY).clamp(0, 1 << 20);
        return (model, null);
      }

      // Button up: end the drag.
      if (m.isUp) model.dragging = false;
      return (model, null);

    default:
      return (model, null);
  }
}

void view(MouseModel model, Frame frame) {
  final base = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line(
          'Mouse playground — click a swatch, drag the panel · q quits',
          style: const Style(fg: Color.darkGray),
        ),
      ),
      const SizedBox(height: 1),
      _swatchGrid(model),
      const SizedBox(height: 1),
      _readout(model),
      const Expanded(child: SizedBox()),
    ],
  );

  final ui = Stack(
    fit: plume.StackFit.expand,
    children: [
      base,
      Positioned(
        left: model.panelX,
        top: model.panelY,
        width: 26,
        height: 5,
        child: _panel(model),
      ),
    ],
  );

  frame.render(ui);
}

View _swatchGrid(MouseModel model) {
  final rows = <View>[];
  for (var r = 0; r < _rows; r++) {
    final cells = <View>[];
    for (var c = 0; c < _cols; c++) {
      final i = r * _cols + c;
      cells.add(Expanded(child: _swatch(model, i)));
    }
    rows.add(
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
        child: Row(crossAxis: CrossAxisAlignment.stretch, children: cells),
      ),
    );
  }
  return Column(crossAxis: CrossAxisAlignment.stretch, children: rows);
}

View _swatch(MouseModel model, int i) {
  final id = 'swatch-$i';
  final selected = model.selectedId == id;
  final hovered = model.hoverId == id;
  final label = selected
      ? '◉'
      : hovered
      ? '◌'
      : '';
  final swatch = Container(
    background: PaintToken(Style(bg: _palette[i])),
    border: hovered || selected ? PaintToken(Style(fg: selected ? Color.white : Color.gray)) : null,
    child: Center(
      child: Line(
        label,
        style: const Style(fg: Color.black, bg: Color.reset),
      ),
    ),
  );
  // Stamp the stable id so the hit map can resolve a click here.
  return Tagged(id, swatch);
}

View _panel(MouseModel model) => Tagged(
  'panel',
  Box(
    border: BorderType.double,
    borderStyle: Style(fg: model.dragging ? Color.yellow : Color.cyan),
    topTitles: [Line('drag me', style: const Style(fg: Color.cyan))],
    child: Center(
      child: Line(
        'at (${model.panelX}, ${model.panelY})',
        style: const Style(fg: Color.darkGray),
      ),
    ),
  ),
);

View _readout(MouseModel model) => Box(
  border: BorderType.plain,
  topTitles: [Line('hit-test readout')],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line('cursor       : (${model.mouseX}, ${model.mouseY})'),
      Line('hover  id    : ${model.hoverId ?? '—'}'),
      Line.fromTexts([
        const Text('selected id  : '),
        Text(model.selectedId ?? '—', style: const Style(fg: Color.green)),
      ]),
      Line('selected rect: ${_rectLabel(model.selectedRect)}'),
    ],
  ),
);

/// Formats the rect `HitMap.rectOf` reported for the selected swatch. Returns
/// `—` before anything is selected.
String _rectLabel(Rect? rect) {
  if (rect == null) return '—';
  return '(${rect.x}, ${rect.y}) ${rect.width}×${rect.height}';
}

void main() async {
  await Application(title: 'Mouse playground', mouseEvents: true).run(
    init: MouseModel(),
    update: update,
    view: view,
  );
}
