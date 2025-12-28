// Demonstrates manual focus management without FocusGroup.
//
// Shows how to track focus with a simple index and update
// each widget's `focused` property manually.
//
// Compare with text_input.dart which uses FocusGroup.

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
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
  LayoutChild inputField(TextInputModel input, String label) => Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: input.focused ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextInput(input),
    ).titleTop(Line(label)),
  );

  final ui = Block(
    child: Column(
      children: [
        inputField(model.name, 'Name'),
        inputField(model.email, 'Email'),
        inputField(model.phone, 'Phone'),
        // Status
        Expanded(
          child: Text.raw(
            'Focus index: ${model.focusIndex}\n'
            'Focused field: ${['Name', 'Email', 'Phone'][model.focusIndex]}\n\n'
            'Name: "${model.name.value}"\n'
            'Email: "${model.email.value}"\n'
            'Phone: "${model.phone.value}"',
          ),
        ),
        // Help
        Fixed(
          1,
          child: Text.raw(
            'Tab/Shift+Tab to cycle | Esc to quit',
            alignment: Alignment.center,
            style: const Style(fg: Color.darkGray),
          ),
        ),
      ],
    ),
  ).titleTop(Line('Manual Focus Demo', style: const Style(fg: Color.darkGray)));

  frame.renderWidget(ui, frame.area);
}

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
