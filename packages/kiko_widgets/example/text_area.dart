import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final editor = TextAreaModel(
    placeholder: 'Start typing...',
    focused: true,
    showLineNumbers: true,
    maxLines: 100,
  );
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Quit on Ctrl+Q or Escape
  if (msg case KeyMsg(
    key: evt.KeyEvent(code: evt.KeyCode(char: 'q'), modifiers: final mods),
  ) when mods.has(evt.KeyModifiers.ctrl)) {
    return (model, const Quit());
  }
  if (msg case KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(name: evt.KeyCodeName.escape)))) {
    return (model, const Quit());
  }

  // Delegate to text area
  final cmd = model.editor.update(msg);
  return (model, cmd);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final e = model.editor;

  // Editor panel with border
  final editorPanel = Block(
    borders: Borders.all,
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: TextAreaWidget(e),
  ).titleTop(Line('Editor'));

  // Status and help bars
  final statusBar = Text.raw(
    'Ln ${e.row + 1}, Col ${e.column + 1} | '
    '${e.lineCount} lines | '
    '${e.length} chars',
    style: const Style(fg: Color.darkGray),
  );

  final helpBar = Text.raw(
    'Esc/Ctrl+Q quit | Shift+Arrow select | Ctrl+A/E home/end',
    alignment: Alignment.center,
    style: const Style(fg: Color.darkGray),
  );

  final ui = Row(
    children: [
      Expanded(child: const Block()), // left spacer
      Percent(
        60,
        child: Column(
          children: [
            Expanded(child: const Block()), // top spacer
            Percent(
              70,
              child: Column(
                children: [
                  Expanded(child: editorPanel),
                  Fixed(1, child: statusBar),
                  Fixed(1, child: helpBar),
                ],
              ),
            ),
            Expanded(child: const Block()), // bottom spacer
          ],
        ),
      ),
      Expanded(child: const Block()), // right spacer
    ],
  );

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'TextArea Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
