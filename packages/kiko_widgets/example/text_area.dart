import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// Mouse: click any field to place the caret there and move keyboard focus to
// it — 2D-aware in the editor (row + column), not just column like the two
// single-line fields above it. FocusRouter owns the wiring: it click-focuses
// the pressed field, routes pointers by target id, sends other keys to the
// focused field, and reserves Tab/Shift+Tab for focus cycling — a channel the
// editor keeps free by leaving both keys unbound in its own defaults.

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  late final focus = FocusGroup<Component>([
    TextInputModel(placeholder: 'Enter title', maxLength: 50),
    TextInputModel(placeholder: 'Enter author'),
    TextAreaModel(
      placeholder: 'Start typing content...',
      showLineNumbers: true,
      maxLines: 100,
    ),
  ]);

  late final router = FocusRouter(focus);

  TextInputModel get title => focus.children[0] as TextInputModel;
  TextInputModel get author => focus.children[1] as TextInputModel;
  TextAreaModel get editor => focus.children[2] as TextAreaModel;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  // Theme keys are app-owned; intercept them before any widget sees them.
  if (model.handleThemeSwitch(msg)) return (model, null);

  // One router call replaces the hand-rolled glue: Tab/Shift+Tab cycle focus
  // before any field sees them (the editor deliberately leaves both unbound,
  // so nothing fights the traversal channel), any other key goes to the
  // focused field, a pointer goes to whichever field it's addressed to, and
  // a down-click moves keyboard focus there.
  switch (model.router.route(msg, ctx)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic — fall through to fallback keys
  }

  // Fallback keys run only for input every widget declined, so a quit key
  // can never fire while a field is consuming keystrokes.
  if (msg case KeyMsg(key: 'ctrl+q' || 'escape')) return (model, const Quit());

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

Future<void> main() async {
  exit(
    await Application(title: 'TextArea Demo', mouseEvents: true, keyboardEnhancement: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
