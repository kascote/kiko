// Demonstrates customizing keybindings at every level.
//
// Shows how to:
// - Extend a widget's bindings with chords (emacs word motions on a TextInput)
// - Rebind printable keys where they are free (g/Ctrl+U on a ListView — a
//   list accepts no text, so plain letters are up for grabs)
// - Extend the FocusRouter's traversal bindings (Ctrl+N/P alongside Tab)
// - Create app-level keybindings that run only for input every widget
//   declined: '?' sets the message line while the list is focused, but types
//   into a focused field; Enter submits from a field, but confirms the
//   cursor row in the list
// - Click a widget to focus it; a click in a field also places the caret

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// CUSTOM KEYBINDINGS
// ═══════════════════════════════════════════════════════════

/// Emacs-style additions to the default readline bindings. Chords only, so
/// the field still accepts every printable character.
KeyBinding<TextInputAction> emacsTextInputBindings() => defaultTextInputBindings.copy()
  ..map(['alt+b'], TextInputAction.jumpWordLeft)
  ..map(['alt+f'], TextInputAction.jumpWordRight)
  ..map(['alt+d'], TextInputAction.deleteWordRight);

/// Vim-flavored additions to the default list bindings, which already have
/// j/k, G and Ctrl+D. A list accepts no text, so printable keys are free.
KeyBinding<ListViewAction> vimListBindings() => defaultListViewBindings.copy()
  ..map(['g'], ListViewAction.first)
  ..map(['ctrl+u'], ListViewAction.pageUp);

/// Focus-traversal keybindings: the router's Tab/Shift+Tab defaults extended
/// with Ctrl+N/Ctrl+P. Traversal keys belong to the router, which reserves
/// them before the focused widget can see them.
KeyBinding<FocusAction> focusBindings() => defaultFocusBindings()
  ..map(['ctrl+n'], const FocusNext())
  ..map(['ctrl+p'], const FocusPrevious());

/// App-level actions: keys that mean something only when no widget consumes
/// them, resolved after the router declines.
enum AppAction { quit, submit, clearAll, help }

/// App-level keybindings.
final appBindings = KeyBinding<AppAction>()
  ..map(['ctrl+q', 'escape'], AppAction.quit)
  ..map(['enter', 'ctrl+s'], AppAction.submit)
  ..map(['ctrl+l'], AppAction.clearAll)
  ..map(['?'], AppAction.help);

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

const _languages = [
  'Ada',
  'C',
  'Clojure',
  'Dart',
  'Elixir',
  'Erlang',
  'Go',
  'Haskell',
  'Java',
  'Kotlin',
  'Lua',
  'OCaml',
  'Prolog',
  'Python',
  'Ruby',
  'Rust',
  'Scala',
  'Swift',
  'Zig',
];

class AppModel with ThemeSwitcher {
  late final focus = FocusGroup<Component>([
    TextInputModel(
      placeholder: 'Default bindings',
    ),
    TextInputModel(
      placeholder: 'Emacs bindings (Alt+B/F/D)',
      keyBinding: emacsTextInputBindings(),
    ),
    ListViewModel<String, String>(
      items: _languages,
      keyBinding: vimListBindings(),
    ),
  ]);

  late final router = FocusRouter(focus, bindings: focusBindings());

  String message = '';

  TextInputModel get normal => focus.children[0] as TextInputModel;
  TextInputModel get emacs => focus.children[1] as TextInputModel;
  ListViewModel<String, String> get list => focus.children[2] as ListViewModel<String, String>;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  // Theme keys are app-owned; intercept them before any widget sees them.
  if (model.handleThemeSwitch(msg)) return (model, null);

  // One router call: traversal keys (here the extended set — Tab/Shift+Tab
  // plus Ctrl+N/P) cycle focus before the focused widget ever sees them, any
  // other key goes to the focused widget, a pointer goes to whichever widget
  // it's addressed to, and a down-click moves focus there.
  switch (model.router.route(msg, ctx)) {
    case Handled(cmd: ListActionCmd(:final id)) when id == model.list.id:
      // Enter (or a click) on the list confirms the cursor row — a
      // widget→app command the app intercepts. The same Enter falls through
      // to AppAction.submit below while a text field is focused instead.
      model.message = 'Picked: ${model.list.cursorItem}';
      return (model, null);
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic — fall through to fallback keys
  }

  // App-level bindings run only for input every widget declined. '?' shows
  // it live: the list has no binding for it and declines, so AppAction.help
  // fires while the list is focused — but a focused text field consumes '?'
  // as text and the app never sees it.
  if (msg case KeyMsg()) {
    final action = appBindings.resolve(msg);

    if (action != null) {
      return switch (action) {
        AppAction.quit => (model, const Quit()),
        AppAction.submit => (model..message = 'Submitted!', null),
        AppAction.help => (model..message = "'?' fell through to the app: the focused widget declined it", null),
        AppAction.clearAll => (
          model
            ..normal.clear()
            ..emacs.clear()
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
  frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));

  final ui = Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line('Custom Keybindings Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _field(model.normal, 'Default bindings', theme),
        _field(model.emacs, 'Emacs bindings', theme),
        Expanded(
          child: Container(
            border: BorderType.plain,
            borderStyle: resolver.border({if (model.list.focused) WidgetState.focused}),
            topTitles: [Line('Vim-flavored list')],
            child: ListView(
              model: model.list,
              theme: theme,
              itemBuilder: (item, index, _) => [Line(' $item')],
            ),
          ),
        ),
        Line(
          model.message.isNotEmpty ? model.message : 'Type in the fields, or press ? while the list is focused',
          style: model.message.isNotEmpty ? Style(fg: theme.success.color) : theme.muted.ink,
        ),
        Line('Emacs field adds: Alt+B/F (word left/right), Alt+D (delete word)', style: theme.muted.ink),
        Line('List adds: g (first), Ctrl+U (page up) | stock: j/k, G, Ctrl+D', style: theme.muted.ink),
        Line('Focus: Tab, Ctrl+N/P | App: Ctrl+L (clear), Enter (submit), ? (help)', style: theme.muted.ink),
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
