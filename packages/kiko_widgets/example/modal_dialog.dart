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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // While a modal is open it captures all input: route to it and swallow
  // anything that isn't a confirm/cancel result, so background keys ('q',
  // 'm') don't leak through underneath it.
  if (model.modal case final modal?) {
    return switch (modal.update(msg)) {
      ModalConfirmCmd(:final payload) => (
        model
          ..modal = null
          ..count += payload! as int
          ..lastAction = 'Confirmed! +$payload',
        null,
      ),
      ModalCancelCmd() => (
        model
          ..modal = null
          ..lastAction = 'Cancelled',
        null,
      ),
      _ => (model, null),
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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final base = Box(
    border: BorderType.rounded,
    borderStyle: theme.border.ink,
    padding: const EdgeInsets.all(1),
    topTitles: [Line(' Modal Dialog Demo — dims what is behind it ', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Line('Count: ${model.count}', style: Style(fg: theme.accent.color)),
        const SizedBox(height: 1),
        Line('Some colourful background content:'),
        Line('  Red', style: const Style(fg: Color.red)),
        Line('  Green', style: const Style(fg: Color.green)),
        Line('  Blue', style: const Style(fg: Color.blue)),
        const Expanded(child: SizedBox()),
        Line(
          model.lastAction.isEmpty ? '[m] open dialog   [q] quit' : 'Last: ${model.lastAction}   [m] again   [q] quit',
          style: theme.muted.ink,
        ),
      ],
    ),
  );

  final dialog = switch (model.modal) {
    final modal? => modalDialog(
      id: modal.id,
      theme: theme,
      topTitles: [Line(' Confirm ', style: Style(fg: theme.warning.color))],
      content: Column(
        mainAxis: MainAxisAlignment.center,
        children: [
          Center(child: Line('Add 10 to the counter?')),
          const SizedBox(height: 1),
          Center(child: Line('[Enter] OK   [Esc] Cancel', style: theme.muted.ink)),
        ],
      ).build(),
    ),
    null => null,
  };

  renderModalOverlay(frame, base: base.build(), width: 40, height: 7, dialog: dialog);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Modal Dialog Example').run(init: AppModel(), update: appUpdate, view: appView);
}
