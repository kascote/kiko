import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

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

  final ui = box(
    border: BorderType.plain,
    borderStyle: theme.border,
    topTitles: [Line('TextArea Demo', style: theme.muted)],
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        _field(model.title, 'Title', theme),
        _field(model.author, 'Author', theme),
        // Editor panel
        plume.Expanded<PaintToken>(
          child: box(
            border: BorderType.plain,
            borderStyle: model.editor.focused ? theme.focus : theme.border,
            padding: const plume.EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Content')],
            child: textArea(model.editor, theme),
          ),
        ),
        // Status bar
        plume.Row<PaintToken>(
          children: [
            plume.Expanded<PaintToken>(
              child: lineNode(
                Line(
                  'Ln ${e.cursorRow + 1}, Col ${e.cursorCol + 1} | '
                  '${e.lineCount} lines | '
                  '${e.length} chars | '
                  'Focus: ${_focusName(model.focus.index)}',
                  style: theme.muted,
                ),
              ),
            ),
            plume.ConstrainedBox<PaintToken>(
              additionalConstraints: const plume.BoxConstraints(minW: 25, maxW: 25),
              child: lineNode(
                Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted, alignment: Alignment.right),
              ),
            ),
          ],
        ),
        // Help
        lineNode(
          Line(
            'Tab/Shift+Tab to switch | Esc quit',
            alignment: Alignment.center,
            style: theme.muted,
          ),
        ),
      ],
    ),
  );

  frame.renderNode(ui);
}

/// A bordered, titled field wrapping a fixed-height [textInput].
plume.RenderNode<PaintToken> _field(TextInputModel input, String label, Theme theme) => box(
  border: BorderType.plain,
  borderStyle: input.focused ? theme.focus : theme.border,
  padding: const plume.EdgeInsets.symmetric(horizontal: 1),
  topTitles: [Line(label)],
  child: plume.ConstrainedBox<PaintToken>(
    additionalConstraints: const plume.BoxConstraints(minH: 1, maxH: 1),
    child: textInput(input, theme),
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
