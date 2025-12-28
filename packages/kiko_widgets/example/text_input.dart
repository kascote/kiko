import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  late final focus = FocusGroup<Focusable>([
    TextInputModel(
      placeholder: 'Enter username',
      maxLength: 20,
      fillChar: '_',
      style: const TextInputStyle(fill: Style(fg: Color.darkGray)),
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
  final ui = Block(
    child: Column(
      children: [
        // Username input
        Fixed(
          3,
          child: Block(
            borders: Borders.all,
            borderStyle: model.username.focused ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TextInput(model.username),
          ).titleTop(Line('Username')),
        ),
        // Password input
        Fixed(
          3,
          child: Block(
            borders: Borders.all,
            borderStyle: model.password.focused ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TextInput(model.password),
          ).titleTop(Line('Password')),
        ),
        // Debug info
        Expanded(
          child: Text.raw(
            'Username: "${model.username.value}"\n'
            'Password: "${model.password.value}" (${model.password.length} chars)\n'
            'Focused: ${model.focus.index == 0 ? "username" : "password"}',
          ),
        ),
        // Help
        Fixed(
          1,
          child: Text.raw(
            'Tab to switch fields | Esc/Ctrl+Q to quit',
            alignment: Alignment.center,
            style: const Style(fg: Color.darkGray),
          ),
        ),
      ],
    ),
  ).titleTop(Line('TextInput Demo', style: const Style(fg: Color.darkGray)));

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
