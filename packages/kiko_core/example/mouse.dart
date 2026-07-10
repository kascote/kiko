import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

// ═══════════════════════════════════════════════════════════
// Interactive mouse playground, and a demonstration of pointer capture.
//
// Swatches and a floating panel stamp a stable id on their subtree with
// `Tagged`, and a mouse event arrives at `update` already resolved to that id.
// Nothing here hit-tests: `PointerMsg.targetId` names the widget and `local`
// gives the cursor in that widget's own cells.
//
// Drag the panel as fast as you can. The cursor outruns it — a terminal reports
// far fewer positions than a mouse produces — and the drag does not stall,
// because the press handed the panel the pointer and every drag that follows is
// addressed to it however far away the cursor has got. That is capture, and it
// is the observable difference.
//
// Two more things the router says that the event stream cannot. `PointerLeaveMsg`
// tells a widget the pointer is gone, since no event will ever address it again.
// `PointerCancelMsg` tells the panel its drag was abandoned rather than finished
// — drag it off the terminal window and release, or click away to another app —
// and the panel snaps back to where the press found it. An `up` ends the
// interaction; a `cancel` ends it and means do not commit it.
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

  /// Where the selected swatch was painted, as the routed click reported it.
  Rect? selectedRect;

  // Floating panel position, and what a drag of it needs to remember.
  int panelX = 4;
  int panelY = 2;
  bool dragging = false;
  int grabDX = 0; // cursor offset within the panel when the drag began
  int grabDY = 0;
  int homeX = 4; // where to put the panel back if the drag is cancelled
  int homeY = 2;

  int mouseX = 0;
  int mouseY = 0;
  String lastWheel = '—';
}

(MouseModel, Cmd?) update(MouseModel model, Msg msg, UpdateContext _) {
  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());

    // The pointer left whatever it was over. Nothing else has to notice.
    case PointerLeaveMsg(:final targetId):
      if (model.hoverId == targetId) model.hoverId = null;
      return (model, null);

    // The drag was abandoned rather than finished — the cursor left the window,
    // or the terminal lost focus. Put the panel back where the press found it.
    case PointerCancelMsg():
      if (model.dragging) {
        model
          ..dragging = false
          ..panelX = model.homeX
          ..panelY = model.homeY;
      }
      return (model, null);

    case final PointerMsg m:
      model
        ..mouseX = m.global.x
        ..mouseY = m.global.y;

      // Hover follows the pointer, except while a gesture holds it: the router
      // suspends hover for the length of a drag and says so with `captured`.
      if (!m.captured) model.hoverId = m.targetId;

      // The wheel is no part of a button gesture, so it addresses whatever sits
      // under the cursor — even the swatch a captured panel is being dragged
      // across.
      if (m.isWheel) {
        model.lastWheel = '${m.action.name} over ${m.targetId ?? 'background'}';
        return (model, null);
      }

      // Button down: grab the panel, or select a swatch. `local` is already the
      // grab offset — the cursor counted from the panel's own top-left cell —
      // and the router keeps no such offset for us.
      if (m.isDown) {
        if (m.targetId == 'panel') {
          model
            ..dragging = true
            ..grabDX = m.local.x
            ..grabDY = m.local.y
            ..homeX = model.panelX
            ..homeY = model.panelY;
        } else if (m.targetId case final id? when id.startsWith('swatch-')) {
          model
            ..selectedId = id
            ..selectedRect = m.targetRect;
        }
        return (model, null);
      }

      // Drag: the press captured the panel, so every drag still addresses it
      // even when the cursor has run off it. Keep the grabbed cell under the
      // cursor.
      if (m.isDrag && model.dragging) {
        model
          ..panelX = (m.global.x - model.grabDX).clamp(0, 1 << 20)
          ..panelY = (m.global.y - model.grabDY).clamp(0, 1 << 20);
        return (model, null);
      }

      // Button up: the drag is over, and where the panel landed is where it
      // stays.
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
          'Mouse playground — click a swatch, drag the panel fast, scroll anywhere · q quits',
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
    background: Style(bg: _palette[i]),
    border: hovered || selected ? BorderType.plain : BorderType.none,
    borderStyle: Style(fg: selected ? Color.white : Color.gray),
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
  topTitles: [Line('routed event readout')],
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
      Line('last wheel   : ${model.lastWheel}'),
    ],
  ),
);

/// Formats the rect the routed click reported as `PointerMsg.targetRect`.
/// Returns `—` before anything is selected.
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
