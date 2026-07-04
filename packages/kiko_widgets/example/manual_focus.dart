// Demonstrates manual focus management without FocusGroup.
//
// Shows how to track focus with a simple index and update
// each widget's `focused` property manually.
//
// Compare with text_input.dart which uses FocusGroup.

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final ui = box(
    border: BorderType.plain,
    borderStyle: theme.border,
    topTitles: [Line('Manual Focus Demo', style: theme.muted)],
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        _field(model.name, 'Name', theme),
        _field(model.email, 'Email', theme),
        _field(model.phone, 'Phone', theme),
        // Status
        plume.Expanded<PaintToken>(
          child: textNode(
            Text.raw(
              'Focus index: ${model.focusIndex}\n'
              'Focused field: ${['Name', 'Email', 'Phone'][model.focusIndex]}\n\n'
              'Name: "${model.name.value}"\n'
              'Email: "${model.email.value}"\n'
              'Phone: "${model.phone.value}"',
              style: Style(fg: theme.background.fg),
            ),
          ),
        ),
        // Help
        plume.Row<PaintToken>(
          children: [
            plume.Expanded<PaintToken>(
              child: lineNode(Line('Tab/Shift+Tab to cycle | Esc quit', style: theme.muted)),
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
  await Application(title: 'Manual Focus Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
