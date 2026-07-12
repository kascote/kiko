import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// Mouse: click any field to place the caret there and move keyboard focus to
// it — 2D-aware in the editor (row + column), not just column like the two
// single-line fields above it.

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

  /// The three fields' ids, in focus order — lets a click resolve straight
  /// to an index without checking each field's type by hand.
  List<String> get fieldIds => [title.id, author.id, editor.id];

  /// Routes [msg] to the field at [index].
  UpdateResult updateAt(int index, Msg msg) {
    return switch (index) {
      0 => title.update(msg),
      1 => author.update(msg),
      2 => editor.update(msg),
      _ => const Declined(),
    };
  }

  /// Route update to focused item.
  UpdateResult updateFocused(Msg msg) => updateAt(focus.index, msg);
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A pointer reaches whichever field it's actually addressed to; a
  // down-click also moves keyboard focus there (the app's call).
  if (msg case Routed(:final targetId)) {
    final i = model.fieldIds.indexWhere((id) => id == targetId);
    if (i < 0) return (model, null);
    if (msg case final PointerMsg pointer when pointer.isDown) model.focus.setIndex(i);
    return switch (model.updateAt(i, msg)) {
      Handled(:final cmd) => (model, cmd),
      Declined() => (model, null),
    };
  }

  // Route to focused input (keyboard)
  switch (model.updateFocused(msg)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break;
  }

  // Declined key - check for Tab cycling and global shortcuts
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

  final ui = Container(
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
          child: Container(
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
            'Tab/Shift+Tab/click to switch | Esc quit',
            style: theme.muted.ink,
          ),
        ),
      ],
    ),
  );

  frame.render(ui);
}

/// A bordered, titled field wrapping a fixed-height [TextInput].
View _field(TextInputModel input, String label, Theme theme) => Container(
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
  await Application(title: 'TextArea Demo', mouseEvents: true).run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
