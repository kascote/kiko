// Demonstrates customizing keybindings at every level.
//
// Shows how to:
// - Add vim-style navigation to one widget (h/l for left/right)
// - Extend the FocusRouter's traversal bindings (Ctrl+N/P alongside Tab)
// - Create app-level keybindings for keys no widget consumes
// - Click either field to place the caret there and move focus to it

import 'dart:io';

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

/// Focus-traversal keybindings: the router's Tab/Shift+Tab defaults extended
/// with Ctrl+N/Ctrl+P. Traversal keys belong to the router, which reserves
/// them before the focused field can see them.
KeyBinding<FocusAction> focusBindings() => defaultFocusBindings()
  ..map(['ctrl+n'], const FocusNext())
  ..map(['ctrl+p'], const FocusPrevious());

/// App-level actions: keys that mean something only when no widget consumes
/// them, resolved after the router declines.
enum AppAction { quit, submit, clearAll }

/// App-level keybindings.
final appBindings = KeyBinding<AppAction>()
  ..map(['ctrl+q', 'escape'], AppAction.quit)
  ..map(['enter', 'ctrl+s'], AppAction.submit)
  ..map(['ctrl+l'], AppAction.clearAll);

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  late final focus = FocusGroup<Component>([
    TextInputModel(
      placeholder: 'Normal bindings',
      // Uses default bindings
    ),
    TextInputModel(
      placeholder: r'Vim bindings (h/l/w/b/0/$)',
      keyBinding: vimTextInputBindings(),
    ),
  ]);

  late final router = FocusRouter(focus, bindings: focusBindings());

  String message = '';

  TextInputModel get normal => focus.children[0] as TextInputModel;
  TextInputModel get vim => focus.children[1] as TextInputModel;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  // Theme keys are app-owned; intercept them before any widget sees them.
  if (model.handleThemeSwitch(msg)) return (model, null);

  // One router call replaces the hand-rolled glue: traversal keys (here the
  // extended set — Tab/Shift+Tab plus Ctrl+N/P) cycle focus before the field
  // ever sees them, any other key goes to the focused field, a pointer goes
  // to whichever field it's addressed to, and a down-click moves focus there.
  switch (model.router.route(msg, ctx)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic — fall through to fallback keys
  }

  // App-level bindings run only for input every widget declined — the vim
  // field can consume plain letters as motions without ever shadowing these.
  if (msg case KeyMsg()) {
    final action = appBindings.resolve(msg);

    if (action != null) {
      return switch (action) {
        AppAction.quit => (model, const Quit()),
        AppAction.submit => (model..message = 'Submitted!', null),
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

  final ui = Container(
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
              Line('Focus: Ctrl+N/P (cycle) | App: Ctrl+L (clear), Enter (submit)', style: theme.muted.ink),
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

Future<void> main() async {
  exit(
    await Application(title: 'Custom Keybindings Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
