// Simple ListView example with string items.
//
// Shows:
// - Basic list setup with DataView.fromList()
// - Cursor navigation (arrows, j/k, pageUp/pageDown)
// - Item rendering via itemBuilder
// - Confirm action (Enter)

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

const fruits = [
  'Apple',
  'Apricot',
  'Avocado',
  'Banana',
  'Blackberry',
  'Blueberry',
  'Cherry',
  'Coconut',
  'Cranberry',
  'Date',
  'Dragonfruit',
  'Elderberry',
  'Fig',
  'Grape',
  'Grapefruit',
  'Guava',
  'Honeydew',
  'Kiwi',
  'Kumquat',
  'Lemon',
  'Lime',
  'Lychee',
  'Mango',
  'Melon',
  'Nectarine',
  'Orange',
  'Papaya',
  'Passionfruit',
  'Peach',
  'Pear',
  'Pineapple',
  'Plum',
  'Pomegranate',
  'Raspberry',
  'Strawberry',
  'Tangerine',
  'Watermelon',
];

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  // Simple case: no itemKey needed, strings are their own keys
  final list = ListViewModel<String, String>(
    dataView: DataView.fromList(fruits),
    focused: true,
  );

  String? selected;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  final cmd = model.list.update(msg);

  // Handle confirm
  if (cmd case ListActionCmd(:final id)) {
    if (id == model.list.id) {
      model.selected = model.list.cursorItem;
    }
    return (model, null);
  }

  if (cmd is! Unhandled) return (model, cmd);

  // Quit
  if (msg case KeyMsg(:final key)) {
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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final ui = Box(
    topTitles: [Line('ListView Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Box(
            border: BorderType.plain,
            borderStyle: StyleResolver(theme).border(const {WidgetState.focused}),
            topTitles: [Line('Fruits (${fruits.length})', style: theme.focus.ink)],
            child: ListView(
              model: model.list,
              theme: theme,
              itemBuilder: (item, index, _) => [Line(' $item')],
            ),
          ),
        ),
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
          child: Box(
            border: BorderType.plain,
            borderStyle: model.selected != null ? theme.success.ink : theme.border.ink,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Selected')],
            child: Line(
              model.selected ?? 'Press Enter to select',
              style: model.selected != null ? Style(fg: theme.success.color) : theme.muted.ink,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Line('↑↓/jk navigate | Enter select | Esc quit', style: theme.muted.ink),
            ),
            ConstrainedBox(
              additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
              child: Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted.ink),
            ),
          ],
        ),
      ],
    ),
  );

  frame.render(ui);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'ListView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
