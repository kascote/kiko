// Simple ListView example with string items.
//
// Shows:
// - Basic list setup with DataView.fromList()
// - Cursor navigation (arrows, j/k, pageUp/pageDown)
// - Item rendering via itemBuilder
// - Confirm action (Enter)

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final ui = box(
    topTitles: [Line('ListView Demo', style: theme.muted)],
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        plume.Expanded<PaintToken>(
          child: box(
            border: BorderType.plain,
            borderStyle: theme.focus,
            topTitles: [Line('Fruits (${fruits.length})', style: theme.focus)],
            child: listView(
              model: model.list,
              theme: theme,
              itemBuilder: (item, index, _) => [Line(' $item')],
            ),
          ),
        ),
        plume.ConstrainedBox<PaintToken>(
          additionalConstraints: const plume.BoxConstraints(minH: 3, maxH: 3),
          child: box(
            border: BorderType.plain,
            borderStyle: model.selected != null ? theme.success : theme.border,
            padding: const plume.EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Selected')],
            child: lineNode(
              Line(
                model.selected ?? 'Press Enter to select',
                style: model.selected != null ? Style(fg: theme.success.fg) : theme.muted,
              ),
            ),
          ),
        ),
        plume.Row<PaintToken>(
          children: [
            plume.Expanded<PaintToken>(
              child: lineNode(Line('↑↓/jk navigate | Enter select | Esc quit', style: theme.muted)),
            ),
            plume.ConstrainedBox<PaintToken>(
              additionalConstraints: const plume.BoxConstraints(minW: 25, maxW: 25),
              child: lineNode(Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted)),
            ),
          ],
        ),
      ],
    ),
  );

  frame.renderNode(ui);
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
