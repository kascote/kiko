// Demonstrates manual focus management without FocusGroup.
//
// Shows how to track focus with a simple index and update
// each widget's `focused` property manually.
//
// Compare with text_input.dart which uses FocusGroup.

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  final name = TextInputModel(placeholder: 'Name');
  final email = TextInputModel(placeholder: 'Email');
  final phone = TextInputModel(placeholder: 'Phone');

  int focusIndex = 0;

  AppModel() {
    // Initialize focus state
    _updateFocusState();
  }

  List<TextInputModel> get fields => [name, email, phone];

  TextInputModel get focused => fields[focusIndex];

  void setFocus(int index) {
    focusIndex = index % fields.length;
    if (focusIndex < 0) focusIndex += fields.length;
    _updateFocusState();
  }

  void cycleFocus(int delta) => setFocus(focusIndex + delta);

  void _updateFocusState() {
    for (var i = 0; i < fields.length; i++) {
      fields[i].focused = i == focusIndex;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Route to focused widget
  final cmd = model.focused.update(msg);
  if (cmd is! Unhandled) return (model, cmd);

  // Handle Tab / Shift+Tab
  if (msg case KeyMsg(:final key)) {
    if (key == 'tab') {
      model.cycleFocus(1);
      return (model, null);
    }
    if (key == 'shift+tab') {
      model.cycleFocus(-1);
      return (model, null);
    }
    if (key == 'escape' || key == 'ctrl+q') {
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

  final ui = Box(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line('Manual Focus Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _field(model.name, 'Name', theme),
        _field(model.email, 'Email', theme),
        _field(model.phone, 'Phone', theme),
        // Status
        Expanded(
          child: Column(
            crossAxis: CrossAxisAlignment.stretch,
            children: [
              for (final line in [
                'Focus index: ${model.focusIndex}',
                'Focused field: ${['Name', 'Email', 'Phone'][model.focusIndex]}',
                '',
                'Name: "${model.name.value}"',
                'Email: "${model.email.value}"',
                'Phone: "${model.phone.value}"',
              ])
                Line(line, style: Style(fg: theme.background.on)),
            ],
          ),
        ),
        // Help
        Row(
          children: [
            Expanded(
              child: Line('Tab/Shift+Tab to cycle | Esc quit', style: theme.muted.ink),
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

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Manual Focus Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
