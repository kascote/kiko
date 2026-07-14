import 'dart:io';

import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// Mouse: click either field to place the caret there and move keyboard focus
// to it — a click is addressed to the field under it, not whichever field
// the keyboard currently has focused. FocusRouter owns that wiring: it
// click-focuses the pressed field, routes pointers by target id, sends other
// keys to the focused field, and reserves Tab/Shift+Tab for focus cycling.

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  late final focus = FocusGroup<Component>([
    TextInputModel(
      placeholder: 'Enter username',
      maxLength: 20,
      fillChar: '_',
      inputFilter: (c) => Characters(c.where((g) => g.trim().isNotEmpty).join()),
    ),
    TextInputModel(placeholder: 'Enter password', obscureText: true, maxLength: 50),
  ]);

  late final router = FocusRouter(focus);

  TextInputModel get username => focus.children[0] as TextInputModel;
  TextInputModel get password => focus.children[1] as TextInputModel;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  // Theme keys are app-owned; intercept them before any widget sees them.
  if (model.handleThemeSwitch(msg)) return (model, null);

  // One router call replaces the hand-rolled glue: Tab/Shift+Tab cycle focus
  // (reserved before the field ever sees them), any other key goes to the
  // focused field, a pointer goes to whichever field it's addressed to, and
  // a down-click moves keyboard focus there first.
  switch (model.router.route(msg, ctx)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic — fall through to fallback keys
  }

  // Fallback keys run only for input every widget declined, so a quit key
  // can never fire while a focused field is consuming keystrokes.
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

Future<void> main() async {
  exit(
    await Application(title: 'TextInput Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
