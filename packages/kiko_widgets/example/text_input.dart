import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// Mouse: click either field to place the caret there and move keyboard focus
// to it — a click is addressed to the field under it, not whichever field
// the keyboard currently has focused (kiko_widgets/CLAUDE.md → Widget mouse
// handling).

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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A pointer reaches whichever field it's actually addressed to — never
  // just whichever field the keyboard currently has focused. A down-click
  // also moves keyboard focus there (the app's call; a widget cannot see
  // its siblings).
  if (msg case Routed(:final targetId)) {
    final i = model.focus.children.indexWhere((c) => c is TextInputModel && c.id == targetId);
    if (i < 0) return (model, null);
    if (msg case final PointerMsg pointer when pointer.isDown) model.focus.setIndex(i);
    return switch ((model.focus.children[i] as TextInputModel).update(msg)) {
      Handled(:final cmd) => (model, cmd),
      Declined() => (model, null),
    };
  }

  // Route to focused input (keyboard)
  switch ((model.focus.focused as TextInputModel).update(msg)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break;
  }

  // Declined key - check for Tab cycling and global shortcuts
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
  final resolver = StyleResolver(theme);
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final ui = Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line('TextInput Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _field(model.username, 'Username', theme),
        _field(model.password, 'Password', theme),
        // Debug info
        Expanded(
          child: Column(
            crossAxis: CrossAxisAlignment.stretch,
            children: [
              for (final line in [
                'Username: "${model.username.value}"',
                'Password: "${model.password.value}" (${model.password.length} chars)',
                'Focused: ${model.focus.index == 0 ? "username" : "password"}',
              ])
                Line(line, style: Style(fg: theme.background.on)),
            ],
          ),
        ),
        // Help
        Row(
          children: [
            Expanded(
              child: Line('Tab/click to switch | Esc quit', style: theme.muted.ink),
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

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'TextInput Demo', mouseEvents: true).run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
