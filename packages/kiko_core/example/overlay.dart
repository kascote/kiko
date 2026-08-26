import 'dart:io';

import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// Modal overlay.
//
// One frame, three passes: paint the base UI, dim everything already on the
// buffer with `Frame.dimBackdrop`, then paint a centered modal on top. Because
// a render pass only writes the cells it covers, the dimmed base survives
// everywhere the modal does not, and the modal — given a solid background —
// reads as bright and in front. `Stack`/`Positioned` order does the layering.
// ═══════════════════════════════════════════════════════════

class OverlayModel {
  final int count;
  final bool modalOpen;

  const OverlayModel({this.count = 0, this.modalOpen = false});

  OverlayModel copyWith({int? count, bool? modalOpen}) =>
      OverlayModel(count: count ?? this.count, modalOpen: modalOpen ?? this.modalOpen);
}

(OverlayModel, Cmd?) update(OverlayModel model, Msg msg, UpdateContext _) => switch (msg) {
  KeyMsg(key: 'q') => (model, const Quit()),
  KeyMsg(key: 'm') => (model.copyWith(modalOpen: !model.modalOpen), null),
  KeyMsg(key: 'escape') => (model.copyWith(modalOpen: false), null),
  // The base stays interactive only while the modal is closed — the modal
  // "captures" input, a common overlay expectation.
  KeyMsg(key: 'up') when !model.modalOpen => (model.copyWith(count: model.count + 1), null),
  KeyMsg(key: 'down') when !model.modalOpen => (model.copyWith(count: model.count - 1), null),
  _ => (model, null),
};

void view(OverlayModel model, Frame frame) {
  // Pass 1: the base UI.
  frame.render(_base(model));

  if (model.modalOpen) {
    frame
      // Pass 2: dim what was just painted.
      ..dimBackdrop()
      // Pass 3: the modal, centered, on top of the dimmed base.
      ..render(_modal());
  }
}

View _base(OverlayModel model) => Container(
  border: BorderType.plain,
  topTitles: [Line('Overlay demo')],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line(
          'm = open modal · ↑/↓ = change count · q = quit',
          style: const Style(fg: Color.darkGray),
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tile('Count', '${model.count}', Color.green)),
            Expanded(child: _tile('Status', model.modalOpen ? 'MODAL' : 'ready', Color.cyan)),
            Expanded(child: _tile('Colors', 'live', Color.magenta)),
          ],
        ),
      ),
    ],
  ),
);

View _tile(String title, String value, Color color) => Container(
  border: BorderType.rounded,
  borderStyle: Style(fg: color),
  topTitles: [Line(title, style: Style(fg: color))],
  child: Center(
    child: Line(value, style: const Style(addModifier: Modifier.bold)),
  ),
);

View _modal() => Center(
  child: Container(
    width: 40,
    height: 7,
    // A solid fill makes the modal opaque over the dimmed backdrop.
    ground: const Style(bg: Color.black),
    border: BorderType.double,
    borderStyle: const Style(fg: Color.yellow),
    topTitles: [
      Line(
        ' Confirm ',
        style: const Style(fg: Color.yellow, addModifier: Modifier.bold),
      ),
    ],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        const Expanded(child: SizedBox()),
        Center(child: Line('This modal sits above a dimmed base.')),
        const Expanded(child: SizedBox()),
        Center(
          child: Line('Esc / m to close', style: const Style(fg: Color.darkGray)),
        ),
      ],
    ),
  ),
);

Future<void> main() async {
  exit(
    await Application(title: 'Overlay demo').run(
      init: const OverlayModel(),
      update: update,
      view: view,
    ),
  );
}
