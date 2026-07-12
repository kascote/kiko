// Demonstrates customizing widget keybindings.
//
// Shows how to:
// - Add vim-style navigation (h/l for left/right)
// - Override default bindings
// - Create app-level keybindings
// - Click either field to place the caret there and move focus to it

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A pointer reaches whichever field it's actually addressed to; a
  // down-click also moves keyboard focus there (the app's call).
  if (msg case Routed(:final targetId)) {
    final i = model.focus.children.indexWhere((c) => c is TextInputModel && c.id == targetId);
    if (i < 0) return (model, null);
    if (msg case final PointerMsg pointer when pointer.isDown) model.focus.setIndex(i);
    return switch ((model.focus.children[i] as TextInputModel).update(msg)) {
      Handled(:final cmd) => (model, cmd),
      Declined() => (model, null),
    };
  }

  // Route to focused widget first (keyboard)
  final focused = model.focus.focused as TextInputModel;
  switch (focused.update(msg)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break;
  }

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
  final resolver = StyleResolver(theme);
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final ui = Box(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line('Custom Keybindings Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _field(model.normal, 'Normal bindings', theme),
        _field(model.vim, 'Vim bindings', theme),
        // Info
        Expanded(
          child: Column(
            crossAxis: CrossAxisAlignment.stretch,
            children: [
              Line(
                model.message.isNotEmpty ? model.message : 'Type in the fields above',
                style: model.message.isNotEmpty ? Style(fg: theme.success.color) : theme.muted.ink,
              ),
              const SizedBox(height: 1),
              Line(r'Vim field supports: h/l (←/→), w/b (word), 0/$ (home/end), x (del)', style: theme.muted.ink),
              Line('App bindings: Ctrl+N/P (cycle), Ctrl+L (clear), Enter (submit)', style: theme.muted.ink),
            ],
          ),
        ),
        // Help
        Row(
          children: [
            Expanded(
              child: Line('Tab/click to switch | Ctrl+Q/Esc quit', style: theme.muted.ink),
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
  await Application(title: 'Custom Keybindings Demo', mouseEvents: true).run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
