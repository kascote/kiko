import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

import 'shared/theme_switcher.dart';

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
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Custom message for async completion.
class SubmitComplete extends Msg {
  const SubmitComplete();
}

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Handle theme switching
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Handle async completion
  if (msg case SubmitComplete()) {
    model.submitButton.loading = false;
    model.lastPress = 'Submit completed!';
    return (model, null);
  }

  // Route to current pane's button group
  final cmd = model.currentGroup.update(msg);

  // Handle button press
  if (cmd case ButtonPressCmd(:final id)) {
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

  if (cmd is! Unhandled) return (model, cmd);

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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final ui = plume.Column<PaintToken>(
    crossAxisAlignment: plume.CrossAxisAlignment.stretch,
    children: [
      // Top row: Basic + Styled
      plume.Expanded<PaintToken>(
        child: plume.Row<PaintToken>(
          crossAxisAlignment: plume.CrossAxisAlignment.stretch,
          children: [
            // Pane 1: Basic buttons (theme-derived styles)
            plume.Expanded<PaintToken>(
              child: _buildPane(
                theme,
                '1. Basic (themed)',
                model.focusedPane == 0,
                _buildHorizontalButtons(model.basicGroup, gap: 2, theme: theme),
              ),
            ),
            // Pane 2: Styled buttons (overrides demo)
            plume.Expanded<PaintToken>(
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
      plume.Expanded<PaintToken>(
        child: plume.Row<PaintToken>(
          crossAxisAlignment: plume.CrossAxisAlignment.stretch,
          children: [
            // Pane 3: Vertical layout (theme-derived)
            plume.Expanded<PaintToken>(
              child: _buildPane(
                theme,
                '3. Vertical (wrap)',
                model.focusedPane == 2,
                _buildVerticalButtons(model.verticalGroup, theme: theme),
              ),
            ),
            // Pane 4: States (theme-derived)
            plume.Expanded<PaintToken>(
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
      plume.Row<PaintToken>(
        children: [
          plume.Expanded<PaintToken>(
            child: lineNode(
              Line(
                model.lastPress.isEmpty ? 'Press Enter to activate' : model.lastPress,
                style: Style(fg: theme.accent.fg),
              ),
            ),
          ),
          plume.ConstrainedBox<PaintToken>(
            additionalConstraints: const plume.BoxConstraints(minW: 25, maxW: 25),
            child: lineNode(Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted)),
          ),
          plume.ConstrainedBox<PaintToken>(
            additionalConstraints: const plume.BoxConstraints(minW: 30, maxW: 30),
            child: lineNode(
              Line('Tab: pane | Esc: quit', style: theme.muted, alignment: Alignment.right),
            ),
          ),
        ],
      ),
    ],
  );

  frame.renderNode(ui);
}

plume.RenderNode<PaintToken> _buildPane(
  Theme theme,
  String title,
  bool focused,
  plume.RenderNode<PaintToken> buttons,
) {
  final borderStyle = focused ? theme.focus : theme.border;
  final titleStyle = focused ? theme.focus : theme.muted;
  return box(
    border: BorderType.plain,
    borderStyle: borderStyle,
    padding: const plume.EdgeInsets.all(1),
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        lineNode(Line(title, style: titleStyle)),
        plume.SizedBox<PaintToken>(height: 1), // Spacer
        plume.Expanded<PaintToken>(child: buttons),
      ],
    ),
  );
}

/// Build horizontal button layout with custom gap.
plume.RenderNode<PaintToken> _buildHorizontalButtons(
  ButtonGroupModel group, {
  required Theme theme,
  int gap = 1,
}) {
  final children = <plume.RenderNode<PaintToken>>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0 && gap > 0) {
      children.add(plume.SizedBox<PaintToken>(width: gap, height: 1));
    }
    children.add(button(group.buttons[i], theme));
  }
  return plume.Row<PaintToken>(children: children);
}

/// Build styled buttons with per-button overrides.
plume.RenderNode<PaintToken> _buildStyledButtons(
  ButtonGroupModel group, {
  required Theme theme,
}) {
  final children = <plume.RenderNode<PaintToken>>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0) {
      children.add(plume.SizedBox<PaintToken>(width: 1, height: 1));
    }
    final btnModel = group.buttons[i];
    children.add(
      button(btnModel, theme, styleOverrides: _styledOverrides[btnModel.id]),
    );
  }
  return plume.Row<PaintToken>(children: children);
}

/// Build vertical button layout with gap.
plume.RenderNode<PaintToken> _buildVerticalButtons(
  ButtonGroupModel group, {
  required Theme theme,
  int gap = 1,
}) {
  final children = <plume.RenderNode<PaintToken>>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0 && gap > 0) {
      children.add(plume.SizedBox<PaintToken>(height: gap));
    }
    children.add(button(group.buttons[i], theme));
  }
  return plume.Column<PaintToken>(children: children);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Button Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
