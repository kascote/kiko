import 'dart:io';

import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// Modal overlay.
//
// One frame, two passes: paint the base UI, then paint a centered modal on
// top. While the modal is open the base is built through
// `StyleResolver.deEmphasised`, so its chrome and text read one step quieter.
// A render pass only writes the cells it covers, so the quiet base survives
// everywhere the modal does not, and the modal — given a solid background —
// reads as bright and in front.
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
  final resolver = StyleResolver(Theme.dark);
  // Pass 1: the base UI, quieted while the modal is open.
  frame
    ..ground(resolver.ground(resolver.tones.background))
    ..render(_base(model, model.modalOpen ? resolver.deEmphasised : resolver));

  // Pass 2: the modal, centered, on top of the quiet base.
  if (model.modalOpen) {
    frame.render(_modal(resolver));
  }
}

View _base(OverlayModel model, StyleResolver r) => Container(
  border: BorderType.plain,
  borderStyle: r.border(const {}),
  topTitles: [Line('Overlay demo')],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line(
          'm = open modal · ↑/↓ = change count · q = quit',
          style: r.ink(r.tones.muted),
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tile(r, 'Count', '${model.count}', r.tones.success)),
            Expanded(child: _tile(r, 'Status', model.modalOpen ? 'MODAL' : 'ready', r.tones.accent)),
            Expanded(child: _tile(r, 'Colors', 'live', r.tones.secondary)),
          ],
        ),
      ),
    ],
  ),
);

View _tile(StyleResolver r, String title, String value, Tone tone) => Container(
  border: BorderType.rounded,
  borderStyle: r.ink(tone),
  topTitles: [Line(title, style: r.ink(tone))],
  child: Center(
    child: Line(value, style: const Style(addModifier: Modifier.bold)),
  ),
);

View _modal(StyleResolver resolver) {
  final r = resolver.on(resolver.tones.surface);
  return Center(
    child: Container(
      width: 40,
      height: 7,
      // A solid ground makes the modal opaque over the quiet base.
      ground: r.ground(r.tones.surface),
      border: BorderType.double,
      borderStyle: r.ink(r.tones.warning),
      topTitles: [Line(' Confirm ', style: r.ink(r.tones.warning).incModifier(Modifier.bold))],
      child: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: SizedBox()),
          Center(child: Line('This modal sits above a quiet base.')),
          const Expanded(child: SizedBox()),
          Center(child: Line('Esc / m to close', style: r.ink(r.tones.muted))),
        ],
      ),
    ),
  );
}

Future<void> main() async {
  exit(
    await Application(title: 'Overlay demo').run(
      init: const OverlayModel(),
      update: update,
      view: view,
    ),
  );
}
