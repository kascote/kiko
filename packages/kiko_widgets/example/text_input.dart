import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  late final focus = FocusGroup<Focusable>([
    TextInputModel(
      placeholder: 'Enter username',
      maxLength: 20,
      fillChar: '_',
      inputFilter: (c) => Characters(c.where((g) => g.trim().isNotEmpty).join()),
    ),
    TextInputModel(placeholder: 'Enter password', obscureText: true, maxLength: 50),
  ]);

  TextInputModel get username => focus.children[0] as TextInputModel;
  TextInputModel get password => focus.children[1] as TextInputModel;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Route to focused input
  final cmd = (model.focus.focused as TextInputModel).update(msg);
  if (cmd is! Unhandled) return (model, cmd);

  // Unhandled key - check for Tab cycling and global shortcuts
  if (msg case KeyMsg(:final key)) {
    // Tab cycling
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

  final ui = box(
    border: BorderType.plain,
    borderStyle: theme.border,
    topTitles: [Line('TextInput Demo', style: theme.muted)],
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        _field(model.username, 'Username', theme),
        _field(model.password, 'Password', theme),
        // Debug info
        plume.Expanded<PaintToken>(
          child: textNode(
            Text.raw(
              'Username: "${model.username.value}"\n'
              'Password: "${model.password.value}" (${model.password.length} chars)\n'
              'Focused: ${model.focus.index == 0 ? "username" : "password"}',
              style: Style(fg: theme.background.fg),
            ),
          ),
        ),
        // Help
        plume.Row<PaintToken>(
          children: [
            plume.Expanded<PaintToken>(
              child: lineNode(Line('Tab to switch | Esc quit', style: theme.muted)),
            ),
            plume.ConstrainedBox<PaintToken>(
              additionalConstraints: const plume.BoxConstraints(minW: 25, maxW: 25),
              child: lineNode(
                Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted, alignment: Alignment.right),
              ),
            ),
          ],
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

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'TextInput Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
