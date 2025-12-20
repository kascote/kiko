import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  late final focus = FocusGroup<Focusable>([
    TextInputModel(placeholder: 'Enter title', maxLength: 50),
    TextInputModel(placeholder: 'Enter author'),
    TextAreaModel(
      placeholder: 'Start typing content...',
      showLineNumbers: true,
      maxLines: 100,
    ),
  ]);

  TextInputModel get title => focus.children[0] as TextInputModel;
  TextInputModel get author => focus.children[1] as TextInputModel;
  TextAreaModel get editor => focus.children[2] as TextAreaModel;

  /// Route update to focused item.
  Cmd? updateFocused(Msg msg) {
    return switch (focus.index) {
      0 => title.update(msg),
      1 => author.update(msg),
      2 => editor.update(msg),
      _ => null,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Route to focused input
  final cmd = model.updateFocused(msg);
  if (cmd is! Unhandled) return (model, cmd);

  // Unhandled key - check for Tab cycling and global shortcuts
  if (msg case KeyMsg(key: final key)) {
    // Tab cycling (TextArea handles Tab for indentation, so only Shift+Tab bubbles from it)
    if (key.code.name == evt.KeyCodeName.tab) {
      model.focus.cycle(key.modifiers.has(evt.KeyModifiers.shift) ? -1 : 1);
      return (model, null);
    }

    // Quit shortcuts
    if (key == evt.KeyEvent.fromString('ctrl+q') || key.code.name == evt.KeyCodeName.escape) {
      return (model, const Quit());
    }
  }

  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final e = model.editor;

  // Title input
  final titleInput = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.title.focused ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextInput(model.title),
    ).titleTop(Line('Title')),
  );

  // Author input
  final authorInput = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.author.focused ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextInput(model.author),
    ).titleTop(Line('Author')),
  );

  // Editor panel with border
  final editorPanel = Expanded(
    child: Block(
      borders: Borders.all,
      borderStyle: model.editor.focused ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextAreaWidget(e),
    ).titleTop(Line('Content')),
  );

  // Status bar
  final statusBar = Fixed(
    1,
    child: Text.raw(
      'Ln ${e.row + 1}, Col ${e.column + 1} | '
      '${e.lineCount} lines | '
      '${e.length} chars | '
      'Focus: ${_focusName(model.focus.index)}',
      style: const Style(fg: Color.darkGray),
    ),
  );

  // Help bar
  final helpBar = Fixed(
    1,
    child: Text.raw(
      'Tab/Shift+Tab to switch | Esc/Ctrl+Q quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
    ),
  );

  final ui = Row(
    children: [
      Expanded(child: const Block()), // left spacer
      Percent(
        70,
        child: Column(
          children: [
            Expanded(child: const Block()), // top spacer
            Percent(
              80,
              child: Column(
                children: [
                  titleInput,
                  authorInput,
                  editorPanel,
                  statusBar,
                  helpBar,
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

String _focusName(int index) => switch (index) {
  0 => 'title',
  1 => 'author',
  2 => 'content',
  _ => 'unknown',
};

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
