import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  // Pane 1: Basic button group (horizontal)
  final basicGroup = ButtonGroupModel(
    buttons: [
      ButtonModel(id: 'ok', label: Line('OK    ')),
      ButtonModel(id: 'cancel', label: Line('Cancel')),
    ],
    focused: true,
  );

  // Pane 2: Styled buttons
  final styledGroup = ButtonGroupModel(
    buttons: [
      ButtonModel(
        id: 'save',
        label: Line('Save  '),
        styles: const ButtonStyles(
          normal: Style(fg: Color.white, bg: Color.green),
          focus: Style(fg: Color.black, bg: Color.green, addModifier: Modifier.bold),
        ),
      ),
      ButtonModel(
        id: 'delete',
        label: Line('Delete'),
        styles: const ButtonStyles(
          normal: Style(fg: Color.white, bg: Color.red),
          focus: Style(fg: Color.black, bg: Color.red, addModifier: Modifier.bold),
        ),
      ),
      ButtonModel(
        id: 'edit',
        label: Line('Edit  '),
        styles: const ButtonStyles(
          normal: Style(fg: Color.white, bg: Color.blue),
          focus: Style(fg: Color.black, bg: Color.blue, addModifier: Modifier.bold),
        ),
      ),
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

void appView(AppModel model, Frame frame) {
  final ui = Column(
    children: [
      // Top row: Basic + Styled
      Expanded(
        child: Row(
          children: [
            // Pane 1: Basic buttons (horizontal layout)
            Expanded(
              child: _buildPane(
                '1. Basic (horizontal)',
                model.basicGroup,
                model.focusedPane == 0,
                _buildHorizontalButtons(model.basicGroup, gap: 2),
              ),
            ),
            // Pane 2: Styled buttons (horizontal layout)
            Expanded(
              child: _buildPane(
                '2. Styled',
                model.styledGroup,
                model.focusedPane == 1,
                _buildHorizontalButtons(model.styledGroup),
              ),
            ),
          ],
        ),
      ),
      // Bottom row: Vertical + States
      Expanded(
        child: Row(
          children: [
            // Pane 3: Vertical layout
            Expanded(
              child: _buildPane(
                '3. Vertical (wrap)',
                model.verticalGroup,
                model.focusedPane == 2,
                _buildVerticalButtons(model.verticalGroup),
              ),
            ),
            // Pane 4: States
            Expanded(
              child: _buildPane(
                '4. States',
                model.statesGroup,
                model.focusedPane == 3,
                _buildHorizontalButtons(model.statesGroup, gap: 2),
              ),
            ),
          ],
        ),
      ),
      // Status bar
      Fixed(
        1,
        child: Row(
          children: [
            Expanded(
              child: Text.raw(
                model.lastPress.isEmpty ? 'Press Enter to activate' : model.lastPress,
                style: const Style(fg: Color.yellow),
              ),
            ),
            Fixed(
              40,
              child: Text.raw(
                'Tab: switch pane | Esc: quit',
                style: const Style(fg: Color.darkGray),
                alignment: Alignment.right,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  frame.renderWidget(ui, frame.area);
}

Widget _buildPane(String title, ButtonGroupModel group, bool focused, Widget buttons) {
  return Block(
    borders: Borders.all,
    borderStyle: focused ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
    padding: const EdgeInsets.all(1),
    child: Column(
      children: [
        Fixed(
          1,
          child: Line(title, style: Style(fg: focused ? Color.green : Color.darkGray)),
        ),
        Fixed(1, child: const Span('')), // Spacer
        Expanded(child: buttons),
      ],
    ),
  );
}

/// Build horizontal button layout with custom gap.
Widget _buildHorizontalButtons(ButtonGroupModel group, {int gap = 1}) {
  final children = <LayoutChild>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0 && gap > 0) {
      children.add(Fixed(gap, child: Text.raw('')));
    }
    final button = group.buttons[i];
    children.add(Fixed(button.width, child: Button(button)));
  }
  return Row(children: children);
}

/// Build vertical button layout with gap.
Widget _buildVerticalButtons(ButtonGroupModel group, {int gap = 1}) {
  final children = <LayoutChild>[];
  for (var i = 0; i < group.buttons.length; i++) {
    if (i > 0 && gap > 0) {
      children.add(Fixed(gap, child: Text.raw('')));
    }
    children.add(Fixed(1, child: Button(group.buttons[i])));
  }
  return Column(children: children);
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
