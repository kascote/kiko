import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final base = box(
    border: BorderType.rounded,
    borderStyle: theme.border,
    padding: const plume.EdgeInsets.all(1),
    topTitles: [Line(' Modal Dialog Demo — dims what is behind it ', style: theme.muted)],
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        lineNode(Line('Count: ${model.count}', style: Style(fg: theme.accent.fg))),
        plume.SizedBox<PaintToken>(height: 1),
        lineNode(Line('Some colourful background content:')),
        lineNode(Line('  Red', style: const Style(fg: Color.red))),
        lineNode(Line('  Green', style: const Style(fg: Color.green))),
        lineNode(Line('  Blue', style: const Style(fg: Color.blue))),
        plume.Expanded<PaintToken>(child: plume.SizedBox<PaintToken>()),
        lineNode(
          Line(
            model.lastAction.isEmpty
                ? '[m] open dialog   [q] quit'
                : 'Last: ${model.lastAction}   [m] again   [q] quit',
            style: theme.muted,
          ),
        ),
      ],
    ),
  );

  final dialog = switch (model.modal) {
    final modal? => modalDialog(
      id: modal.id,
      theme: theme,
      topTitles: [Line(' Confirm ', style: Style(fg: theme.warning.fg))],
      content: plume.Column<PaintToken>(
        mainAxisAlignment: plume.MainAxisAlignment.center,
        children: [
          lineNode(Line('Add 10 to the counter?', alignment: Alignment.center)),
          plume.SizedBox<PaintToken>(height: 1),
          lineNode(Line('[Enter] OK   [Esc] Cancel', alignment: Alignment.center, style: theme.muted)),
        ],
      ),
    ),
    null => null,
  };

  renderModalOverlay(frame, base: base, width: 40, height: 7, dialog: dialog);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Modal Dialog Example').run(init: AppModel(), update: appUpdate, view: appView);
}
