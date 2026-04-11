import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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

  final ui = Block(
    child: Column(
      children: [
        // Username input
        Fixed(
          3,
          child: Block(
            borders: Borders.all,
            borderStyle: model.username.focused ? theme.focus : theme.border,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TextInput(model.username, theme: theme),
          ).titleTop(Line('Username')),
        ),
        // Password input
        Fixed(
          3,
          child: Block(
            borders: Borders.all,
            borderStyle: model.password.focused ? theme.focus : theme.border,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TextInput(model.password, theme: theme),
          ).titleTop(Line('Password')),
        ),
        // Debug info
        Expanded(
          child: Text.raw(
            'Username: "${model.username.value}"\n'
            'Password: "${model.password.value}" (${model.password.length} chars)\n'
            'Focused: ${model.focus.index == 0 ? "username" : "password"}',
            style: Style(fg: theme.background.fg),
          ),
        ),
        // Help
        Fixed(
          1,
          child: Row(
            children: [
              Expanded(child: Text.raw('Tab to switch | Esc quit', style: theme.muted)),
              Fixed(25, child: themeIndicator(model)),
            ],
          ),
        ),
      ],
    ),
  ).titleTop(Line('TextInput Demo', style: theme.muted));

  frame.renderWidget(ui, frame.area);
}

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
