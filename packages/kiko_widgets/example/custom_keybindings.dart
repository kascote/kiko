// Demonstrates customizing widget keybindings.
//
// Shows how to:
// - Add vim-style navigation (h/l for left/right)
// - Override default bindings
// - Create app-level keybindings

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// CUSTOM KEYBINDINGS
// ═══════════════════════════════════════════════════════════

/// Vim-style text input bindings.
KeyBinding<TextInputAction> vimTextInputBindings() {
  return defaultTextInputBindings.copy()
    // Vim navigation
    ..map(['h'], TextInputAction.left)
    ..map(['l'], TextInputAction.right)
    ..map(['b'], TextInputAction.jumpWordLeft)
    ..map(['w'], TextInputAction.jumpWordRight)
    ..map(['0'], TextInputAction.home)
    ..map([r'$'], TextInputAction.end)
    // Vim delete
    ..map(['x'], TextInputAction.delete)
    ..map(['d', 'b'], TextInputAction.deleteWordLeft)
    ..map(['d', 'w'], TextInputAction.deleteWordRight);
}

/// App-level actions.
enum AppAction { quit, submit, nextField, prevField, clearAll }

/// App-level keybindings.
final appBindings = KeyBinding<AppAction>()
  ..map(['ctrl+q', 'escape'], AppAction.quit)
  ..map(['enter', 'ctrl+s'], AppAction.submit)
  ..map(['tab', 'ctrl+n'], AppAction.nextField)
  ..map(['shift+tab', 'ctrl+p'], AppAction.prevField)
  ..map(['ctrl+l'], AppAction.clearAll);

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  late final focus = FocusGroup<Focusable>([
    TextInputModel(
      placeholder: 'Normal bindings',
      // Uses default bindings
    ),
    TextInputModel(
      placeholder: r'Vim bindings (h/l/w/b/0/$)',
      keyBinding: vimTextInputBindings(),
    ),
  ]);

  String message = '';

  TextInputModel get normal => focus.children[0] as TextInputModel;
  TextInputModel get vim => focus.children[1] as TextInputModel;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Route to focused widget first
  final focused = model.focus.focused as TextInputModel;
  final cmd = focused.update(msg);
  if (cmd is! Unhandled) return (model, cmd);

  // Check app-level bindings
  if (msg case KeyMsg()) {
    final action = appBindings.resolve(msg);

    if (action != null) {
      return switch (action) {
        AppAction.quit => (model, const Quit()),
        AppAction.submit => (model..message = 'Submitted!', null),
        AppAction.nextField => (model..focus.cycle(1), null),
        AppAction.prevField => (model..focus.cycle(-1), null),
        AppAction.clearAll => (
          model
            ..normal.clear()
            ..vim.clear()
            ..message = 'Cleared!',
          null,
        ),
      };
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

  final ui =
      Block(
        child: Column(
          children: [
            inputField(model.normal, 'Normal bindings'),
            inputField(model.vim, 'Vim bindings'),
            // Info
            Expanded(
              child: Column(
                children: [
                  Fixed(
                    1,
                    child: Text.raw(
                      model.message.isNotEmpty ? model.message : 'Type in the fields above',
                      style: Style(
                        fg: model.message.isNotEmpty ? Color.green : Color.darkGray,
                      ),
                    ),
                  ),
                  Fixed(1, child: Text.raw('')),
                  Fixed(
                    1,
                    child: Text.raw(
                      r'Vim field supports: h/l (←/→), w/b (word), 0/$ (home/end), x (del)',
                      style: const Style(fg: Color.darkGray),
                    ),
                  ),
                  Fixed(
                    1,
                    child: Text.raw(
                      'App bindings: Ctrl+N/P (cycle), Ctrl+L (clear), Enter (submit)',
                      style: const Style(fg: Color.darkGray),
                    ),
                  ),
                ],
              ),
            ),
            // Help
            Fixed(
              1,
              child: Text.raw(
                'Tab to switch | Ctrl+Q/Esc to quit',
                alignment: Alignment.center,
                style: const Style(fg: Color.darkGray),
              ),
            ),
          ],
        ),
      ).titleTop(
        Line('Custom Keybindings Demo', style: const Style(fg: Color.darkGray)),
      );

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// EXTENSION
// ═══════════════════════════════════════════════════════════

extension on TextInputModel {
  void clear() {
    // Reset by creating new state - for demo purposes
    // In real code you'd expose a clear method on TextInputModel
    while (length > 0) {
      update(const KeyMsg('backSpace'));
    }
  }
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Custom Keybindings Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
