import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  int count = 0;
  ModalModel? modal;
  String lastAction = '';
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Reads one of the modal's own events: a confirm applies the payload, a
/// cancel just closes it. Both close the modal and set the status line, the
/// same handling whether the cancel came from Escape or from a barrier press.
Cmd? onModalEvent(AppModel model, WidgetEvent event) {
  switch (event) {
    case ModalConfirmEvent(:final payload):
      model
        ..modal = null
        ..count += payload! as int
        ..lastAction = 'Confirmed! +$payload';
    case ModalCancelEvent():
      model
        ..modal = null
        ..lastAction = 'Cancelled';
  }
  return null;
}

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // While a modal is open, it owns every message addressed to it: it
  // decides whether a press outside the dialog dismisses it, and it absorbs
  // any key it does not bind, so background keys ('q', 'm') never leak
  // through underneath it.
  if (model.modal case final modal?) {
    return switch (modal.update(msg)) {
      Handled(:final events, :final cmd) => (model, Batch([cmd, for (final e in events) onModalEvent(model, e)])),
      Declined() => (model, null),
    };
  }

  return switch (msg) {
    KeyMsg(key: 'q') || KeyMsg(key: 'ctrl+q') => (model, const Quit()),
    KeyMsg(key: 'm') => (model..modal = ModalModel(id: 'confirm-add', confirmPayload: 10), null),
    _ => (model, null),
  };
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));

  final base = Container(
    border: BorderType.rounded,
    borderStyle: resolver.border(const {}),
    padding: const EdgeInsets.all(1),
    topTitles: [Line(' Modal Dialog Demo — dims what is behind it ', style: resolver.ink(t.muted))],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Line('Count: ${model.count}', style: resolver.ink(t.accent)),
        const SizedBox(height: 1),
        Line('Some colourful background content:'),
        Line('  Red', style: const Style(fg: Color.red)),
        Line('  Green', style: const Style(fg: Color.green)),
        Line('  Blue', style: const Style(fg: Color.blue)),
        const Expanded(child: SizedBox()),
        Line(
          model.lastAction.isEmpty
              ? '[m] open dialog   click outside or [Esc] to cancel   [q] quit'
              : 'Last: ${model.lastAction}   [m] again   [q] quit',
          style: resolver.ink(t.muted),
        ),
      ],
    ),
  );

  final dialog = switch (model.modal) {
    final modal? => modalDialog(
      id: modal.id,
      theme: theme,
      topTitles: [Line(' Confirm ', style: resolver.ink(t.warning))],
      content: Column(
        mainAxis: MainAxisAlignment.center,
        children: [
          Center(child: Line('Add 10 to the counter?')),
          const SizedBox(height: 1),
          Center(child: Line('[Enter] OK   [Esc]/click outside Cancel', style: resolver.ink(t.muted))),
        ],
      ).build(),
    ),
    null => null,
  };

  renderModalOverlay(frame, base: base.build(), width: 40, height: 7, dialog: dialog, id: model.modal?.id);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(
      title: 'Modal Dialog Example',
      mouseEvents: true,
    ).run(init: AppModel(), update: appUpdate, view: appView),
  );
}
