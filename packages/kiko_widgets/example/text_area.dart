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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
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
  final resolver = StyleResolver(theme);
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final e = model.editor;

  final ui = Box(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line('TextArea Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _field(model.title, 'Title', theme),
        _field(model.author, 'Author', theme),
        // Editor panel
        Expanded(
          child: Box(
            border: BorderType.plain,
            borderStyle: resolver.border({if (model.editor.focused) WidgetState.focused}),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Content')],
            child: TextArea(model: model.editor, theme: theme),
          ),
        ),
        // Status bar
        Row(
          children: [
            Expanded(
              child: Line(
                'Ln ${e.cursorRow + 1}, Col ${e.cursorCol + 1} | '
                '${e.lineCount} lines | '
                '${e.length} chars | '
                'Focus: ${_focusName(model.focus.index)}',
                style: theme.muted.ink,
              ),
            ),
            ConstrainedBox(
              additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
              child: Align(
                alignment: Alignment.centerRight,
                child: Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted.ink),
              ),
            ),
          ],
        ),
        // Help
        Center(
          child: Line(
            'Tab/Shift+Tab to switch | Esc quit',
            style: theme.muted.ink,
          ),
        ),
      ],
    ),
  );

  frame.render(ui);
}

/// A bordered, titled field wrapping a fixed-height [TextInput].
View _field(TextInputModel input, String label, Theme theme) => Box(
  border: BorderType.plain,
  borderStyle: StyleResolver(theme).border({if (input.focused) WidgetState.focused}),
  padding: const EdgeInsets.symmetric(horizontal: 1),
  topTitles: [Line(label)],
  child: ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
    child: TextInput(model: input, theme: theme),
  ),
);

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
