import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final username = TextInputModel(placeholder: 'Enter username', maxLength: 20, focused: true);
  final password = TextInputModel(placeholder: 'Enter password', obscureText: true);
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

  // Delegate to text input (for now, just username - no focus yet)
  final cmd = model.username.update(msg);
  return (model, cmd);
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
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TextInput(model.username),
          ).titleTop(Line('Username')),
        ),
        // Password input
        Fixed(
          3,
          child: Block(
            borders: Borders.all,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TextInput(model.password),
          ).titleTop(Line('Password')),
        ),
        // Debug info
        Expanded(
          child: Text.raw(
            'Username: "${model.username.value}"\n'
            'Password: "${model.password.value}" (${model.password.length} chars)',
          ),
        ),
        // Help
        Fixed(
          1,
          child: Text.raw(
            'Esc/Ctrl+Q to quit',
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
