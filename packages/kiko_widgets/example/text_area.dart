import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
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
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Route to focused input
  final cmd = model.updateFocused(msg);
  if (cmd is! Unhandled) return (model, cmd);

  // Unhandled key - check for Tab cycling and global shortcuts
  if (msg case KeyMsg(:final key)) {
    // Tab cycling (TextArea handles Tab for indentation, so only Shift+Tab bubbles from it)
    if (key == 'tab') {
      model.focus.cycle(1);
      return (model, null);
    }
    if (key == 'shift+tab') {
      model.focus.cycle(-1);
      return (model, null);
    }

    // Quit shortcuts
    if (key == 'ctrl+q' || key == 'escape') {
      return (model, const Quit());
    }
  }

  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final theme = model.theme;
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final e = model.editor;

  // Title input
  final titleInput = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.title.focused ? theme.focus : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextInput(model.title, theme: theme),
    ).titleTop(Line('Title')),
  );

  // Author input
  final authorInput = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.author.focused ? theme.focus : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextInput(model.author, theme: theme),
    ).titleTop(Line('Author')),
  );

  // Editor panel with border
  final editorPanel = Expanded(
    child: Block(
      borders: Borders.all,
      borderStyle: model.editor.focused ? theme.focus : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextArea(e, theme: theme),
    ).titleTop(Line('Content')),
  );

  // Status bar
  final statusBar = Fixed(
    1,
    child: Row(
      children: [
        Expanded(
          child: Text.raw(
            'Ln ${e.cursorRow + 1}, Col ${e.cursorCol + 1} | '
            '${e.lineCount} lines | '
            '${e.length} chars | '
            'Focus: ${_focusName(model.focus.index)}',
            style: theme.muted,
          ),
        ),
        Fixed(25, child: themeIndicator(model)),
      ],
    ),
  );

  // Help bar
  final helpBar = Fixed(
    1,
    child: Text.raw(
      'Tab/Shift+Tab to switch | Esc quit',
      alignment: Alignment.center,
      style: theme.muted,
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
