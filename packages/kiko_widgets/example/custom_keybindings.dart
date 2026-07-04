// Demonstrates customizing widget keybindings.
//
// Shows how to:
// - Add vim-style navigation (h/l for left/right)
// - Override default bindings
// - Create app-level keybindings

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

import 'shared/theme_switcher.dart';

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

class AppModel with ThemeSwitcher {
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
  if (model.handleThemeSwitch(msg)) return (model, null);

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
  final theme = model.theme;
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final ui = box(
    border: BorderType.plain,
    borderStyle: theme.border,
    topTitles: [Line('Custom Keybindings Demo', style: theme.muted)],
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        _field(model.normal, 'Normal bindings', theme),
        _field(model.vim, 'Vim bindings', theme),
        // Info
        plume.Expanded<PaintToken>(
          child: plume.Column<PaintToken>(
            crossAxisAlignment: plume.CrossAxisAlignment.stretch,
            children: [
              lineNode(
                Line(
                  model.message.isNotEmpty ? model.message : 'Type in the fields above',
                  style: model.message.isNotEmpty ? Style(fg: theme.success.fg) : theme.muted,
                ),
              ),
              plume.SizedBox<PaintToken>(height: 1),
              lineNode(
                Line(r'Vim field supports: h/l (←/→), w/b (word), 0/$ (home/end), x (del)', style: theme.muted),
              ),
              lineNode(Line('App bindings: Ctrl+N/P (cycle), Ctrl+L (clear), Enter (submit)', style: theme.muted)),
            ],
          ),
        ),
        // Help
        plume.Row<PaintToken>(
          children: [
            plume.Expanded<PaintToken>(
              child: lineNode(Line('Tab to switch | Ctrl+Q/Esc quit', style: theme.muted)),
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
