import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// Mouse: a down-press arms whichever button it lands on, in any pane — focus
// follows the click, since ButtonGroupModel only forwards the keyboard and
// mouse routing bypasses it (kiko_widgets/CLAUDE.md → Widget mouse
// handling). The release fires the same ButtonPressCmd Enter does, but only
// when it lands back inside; hover tracks whichever button is under the
// cursor.

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  // Pane 1: Basic button group (horizontal)
  final basicGroup = ButtonGroupModel(
    buttons: [
      ButtonModel(id: 'ok', label: Line('OK    ')),
      ButtonModel(id: 'cancel', label: Line('Cancel')),
    ],
    focused: true,
  );

  // Pane 2: Styled buttons (custom overrides)
  final styledGroup = ButtonGroupModel(
    buttons: [
      ButtonModel(id: 'save', label: Line('Save  ')),
      ButtonModel(id: 'delete', label: Line('Delete')),
      ButtonModel(id: 'edit', label: Line('Edit  ')),
    ],
  );

  // Pane 3: Vertical layout with wrap
  final verticalGroup = ButtonGroupModel(
    buttons: [
      ButtonModel(id: 'new', label: Line('New File')),
      ButtonModel(id: 'open', label: Line('Open    ')),
      ButtonModel(id: 'save-as', label: Line('Save As ')),
      ButtonModel(id: 'export', label: Line('Export  ')),
    ],
    wrapNavigation: true,
  );

  // Pane 4: Special states (disabled, async loading simulation)
  final submitButton = ButtonModel(id: 'submit', label: Line('Submit  '));

  late final statesGroup = ButtonGroupModel(
    buttons: [
      ButtonModel(id: 'active', label: Line('Active  ')),
      ButtonModel(id: 'disabled', label: Line('Disabled'), disabled: true),
      submitButton,
    ],
  );

  // Track focus between panes
  int focusedPane = 0;
  static const paneCount = 4;

  // Last button press info
  String lastPress = '';

  List<ButtonGroupModel> get allGroups => [
    basicGroup,
    styledGroup,
    verticalGroup,
    statesGroup,
  ];

  ButtonGroupModel get currentGroup => allGroups[focusedPane];

  void nextPane() {
    currentGroup.focused = false;
    focusedPane = (focusedPane + 1) % paneCount;
    currentGroup.focused = true;
  }

  void prevPane() {
    currentGroup.focused = false;
    focusedPane = (focusedPane - 1 + paneCount) % paneCount;
    currentGroup.focused = true;
  }

  /// Every button across all panes, keyed by id. `ButtonGroupModel` only
  /// forwards the keyboard, so a click bypasses it and targets this map
  /// directly.
  late final Map<String, ButtonModel> buttonsById = {
    for (final g in allGroups)
      for (final b in g.buttons) b.id: b,
  };

  /// Moves keyboard focus to the pane + button owning [id] — one app-side
  /// line, since a widget cannot see its siblings.
  void focusButton(String id) {
    final pane = allGroups.indexWhere((g) => g.buttons.any((b) => b.id == id));
    if (pane < 0) return;
    if (pane != focusedPane) {
      currentGroup.focused = false;
      focusedPane = pane;
      currentGroup.focused = true;
    }
    currentGroup.focusButton(id);
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Custom message for async completion.
class SubmitComplete extends Msg {
  const SubmitComplete();
}

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  // Handle theme switching
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Handle async completion
  if (msg case SubmitComplete()) {
    model.submitButton.loading = false;
    model.lastPress = 'Submit completed!';
    return (model, null);
  }

  // A pointer is addressed to one specific button — ButtonGroupModel never
  // forwards pointer traffic, so mouse routing bypasses it and dispatches
  // straight to the owning ButtonModel. A down-click also focuses that
  // button's pane (the app's call).
  UpdateResult result;
  if (msg case Routed(:final targetId)) {
    final button = model.buttonsById[targetId];
    if (button == null) return (model, null);
    if (msg case final PointerMsg pointer when pointer.isDown) model.focusButton(targetId!);
    result = button.update(msg);
  } else {
    // Route to current pane's button group (keyboard)
    result = model.currentGroup.update(msg);
  }

  // Handle button press
  if (result case Handled(cmd: ButtonPressCmd(:final id))) {
    if (id == 'submit' && !model.submitButton.loading) {
      // Simulate async action
      model.submitButton.loading = true;
      model.lastPress = 'Submitting...';
      return (
        model,
        Task(
          () => Future<void>.delayed(const Duration(seconds: 2)),
          onSuccess: (_) => const SubmitComplete(),
        ),
      );
    }
    model.lastPress = 'Pressed: $id';
    return (model, null);
  }

  switch (result) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break;
  }

  // Handle pane switching and quit
  if (msg case KeyMsg(:final key)) {
    if (key == 'tab') {
      model.nextPane();
      return (model, null);
    }
    if (key == 'shift+tab') {
      model.prevPane();
      return (model, null);
    }
    if (key == 'ctrl+q' || key == 'escape') {
      return (model, const Quit());
    }
  }

  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

/// Per-button style overrides for the styled pane.
const _styledOverrides = <String, Map<WidgetState, Style>>{
  'save': {
    WidgetState.focused: Style(fg: Color.black, bg: Color.green, addModifier: Modifier.bold),
  },
  'delete': {
    WidgetState.focused: Style(fg: Color.black, bg: Color.red, addModifier: Modifier.bold),
  },
  'edit': {
    WidgetState.focused: Style(fg: Color.black, bg: Color.blue, addModifier: Modifier.bold),
  },
};

void appView(AppModel model, Frame frame) {
  final theme = model.theme;

  // Fill background
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      // Top row: Basic + Styled
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            // Pane 1: Basic buttons (theme-derived styles)
            Expanded(
              child: _buildPane(
                theme,
                '1. Basic (themed)',
                model.focusedPane == 0,
                _buildHorizontalButtons(model.basicGroup, gap: 2, theme: theme),
              ),
            ),
            // Pane 2: Styled buttons (overrides demo)
            Expanded(
              child: _buildPane(
                theme,
                '2. Styled',
                model.focusedPane == 1,
                _buildStyledButtons(model.styledGroup, theme: theme),
              ),
            ),
          ],
        ),
      ),
      // Bottom row: Vertical + States
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            // Pane 3: Vertical layout (theme-derived)
            Expanded(
              child: _buildPane(
                theme,
                '3. Vertical (wrap)',
                model.focusedPane == 2,
                _buildVerticalButtons(model.verticalGroup, theme: theme),
              ),
            ),
            // Pane 4: States (theme-derived)
            Expanded(
              child: _buildPane(
                theme,
                '4. States',
                model.focusedPane == 3,
                _buildHorizontalButtons(model.statesGroup, gap: 2, theme: theme),
              ),
            ),
          ],
        ),
      ),
      // Status bar
      Row(
        children: [
          Expanded(
            child: Line(
              model.lastPress.isEmpty ? 'Press Enter to activate' : model.lastPress,
              style: Style(fg: theme.accent.color),
            ),
          ),
          ConstrainedBox(
            additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
            child: Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted.ink),
          ),
          ConstrainedBox(
            additionalConstraints: const BoxConstraints(minW: 30, maxW: 30),
            child: Align(
              alignment: Alignment.centerRight,
              child: Line('Tab: pane | click/hover buttons | Esc: quit', style: theme.muted.ink),
            ),
          ),
        ],
      ),
    ],
  );

  frame.render(ui);
}

View _buildPane(
  Theme theme,
  String title,
  bool focused,
  View buttons,
) {
  final borderStyle = StyleResolver(theme).border({if (focused) WidgetState.focused});
  final titleStyle = focused ? theme.focus.ink : theme.muted.ink;
  return Container(
    border: BorderType.plain,
    borderStyle: borderStyle,
    padding: const EdgeInsets.all(1),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Line(title, style: titleStyle),
        const SizedBox(height: 1), // Spacer
        Expanded(child: buttons),
      ],
    ),
  );
}

/// Build horizontal button layout with custom gap.
View _buildHorizontalButtons(
  ButtonGroupModel group, {
  required Theme theme,
  int gap = 1,
}) {
  final children = <View>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0 && gap > 0) {
      children.add(SizedBox(width: gap, height: 1));
    }
    children.add(Button(model: group.buttons[i], theme: theme));
  }
  return Row(children: children);
}

/// Build styled buttons with per-button overrides.
View _buildStyledButtons(
  ButtonGroupModel group, {
  required Theme theme,
}) {
  final children = <View>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0) {
      children.add(const SizedBox(width: 1, height: 1));
    }
    final btnModel = group.buttons[i];
    children.add(
      Button(model: btnModel, theme: theme, styleOverrides: _styledOverrides[btnModel.id]),
    );
  }
  return Row(children: children);
}

/// Build vertical button layout with gap.
View _buildVerticalButtons(
  ButtonGroupModel group, {
  required Theme theme,
  int gap = 1,
}) {
  final children = <View>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0 && gap > 0) {
      children.add(SizedBox(height: gap));
    }
    children.add(Button(model: group.buttons[i], theme: theme));
  }
  return Column(children: children);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Button Demo', mouseEvents: true).run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
