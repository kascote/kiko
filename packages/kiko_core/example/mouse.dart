import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:termparser/termparser_events.dart' show MouseButtonAction;

// ═══════════════════════════════════════════════════════════
// Interactive mouse playground.
//
// Exercises the tag-based hit-test seam end to end: swatches and a floating
// panel stamp a stable id on their subtree, and a mouse event resolves back to
// that id through `Frame.hitId`.
//
// The wrinkle worth seeing: `hitId` lives on the Frame, which only the *view*
// receives, but mouse events are handled in *update*. So the view stashes the
// last frame on the model, and update hit-tests against it — i.e. against what
// is currently on screen. `Frame.rectOf` then anchors a marker to the selected
// swatch's painted rect.
// ═══════════════════════════════════════════════════════════

const _cols = 6;
const _rows = 3;

const _palette = <Color>[
  Color.red, Color.green, Color.yellow, Color.blue, Color.magenta, Color.cyan, //
  Color.brightRed, Color.brightGreen, Color.brightYellow, Color.brightBlue, Color.brightMagenta, Color.brightCyan, //
  Color.gray, Color.darkGray, Color.white, Color.red, Color.green, Color.blue, //
];

class MouseModel {
  /// The frame from the last render, consulted by update to hit-test.
  Frame? lastFrame;

  String? selectedId;
  String? hoverId;

  // Floating panel position and drag bookkeeping.
  int panelX = 4;
  int panelY = 2;
  bool dragging = false;
  int grabDX = 0; // cursor offset within the panel when the drag began
  int grabDY = 0;

  int mouseX = 0;
  int mouseY = 0;
}

(MouseModel, Cmd?) update(MouseModel model, Msg msg) {
  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());

    case final MouseMsg m:
      model
        ..mouseX = m.x
        ..mouseY = m.y;
      final frame = model.lastFrame;
      final hit = frame?.hitId(m.x, m.y);

      if (m.isMove) {
        model.hoverId = hit;
        return (model, null);
      }

      // Button down: grab the panel, or select a swatch.
      if (m.mouse.button.action == MouseButtonAction.down) {
        if (hit == 'panel') {
          model
            ..dragging = true
            ..grabDX = m.x - model.panelX
            ..grabDY = m.y - model.panelY;
        } else if (hit != null && hit.startsWith('swatch-')) {
          model.selectedId = hit;
        }
        return (model, null);
      }

      // Drag: move the panel, keeping the same grab point under the cursor.
      if (m.isDrag && model.dragging) {
        model
          ..panelX = (m.x - model.grabDX).clamp(0, 1 << 20)
          ..panelY = (m.y - model.grabDY).clamp(0, 1 << 20);
        return (model, null);
      }

      // Button up: end the drag.
      if (m.mouse.button.action == MouseButtonAction.up) {
        model.dragging = false;
      }
      return (model, null);

    default:
      return (model, null);
  }
}

void view(MouseModel model, Frame frame) {
  // `hitId`/`rectOf` answer "what is on screen now" — they read the node roots a
  // frame collects while painting. This frame has not painted yet, so the
  // readout queries the previous (already-painted) frame, while update hit-tests
  // against whichever frame most recently finished. Hand off at the end.
  final onScreen = model.lastFrame;
  final selectedRect = _rectLabel(model.selectedId, onScreen);

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
      _readout(model, selectedRect),
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
  // This frame is now painted; hand it to update as the on-screen state.
  model.lastFrame = frame;
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
  // Stamp the stable id so hitId can resolve a click here.
  return _tagged(swatch, id);
}

View _panel(MouseModel model) => _tagged(
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
  'panel',
);

View _readout(MouseModel model, String selectedRect) => Box(
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
      Line('selected rect: $selectedRect'),
    ],
  ),
);

/// Demonstrates `Frame.rectOf`: locate the selected swatch by id on the last
/// painted frame. Returns `—` before anything is selected or painted.
String _rectLabel(String? id, Frame? onScreen) {
  final rect = id == null ? null : onScreen?.rectOf(id);
  if (rect == null) return '—';
  return '(${rect.x}, ${rect.y}) ${rect.width}×${rect.height}';
}

/// Wraps a view so its built node carries [id] for `hitId` / `rectOf`.
View _tagged(View view, String id) => NodeView(view.build()..tag = id);

void main() async {
  await Application(title: 'Mouse playground', mouseEvents: true).run(
    init: MouseModel(),
    update: update,
    view: view,
  );
}
