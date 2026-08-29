// Simple ListView example with string items.
//
// Shows:
// - Basic list setup over an in-memory items list
// - Cursor navigation (arrows, j/k, pageUp/pageDown)
// - Item rendering via itemBuilder
// - Confirm action (Enter)
// - Click to select (same ListActivateEvent as Enter), wheel-scroll, per-row hover

import 'dart:io';

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
    items: fruits,
    focused: true,
  );

  String? selected;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Reads the list's own confirm event: an activation installs the selection.
Cmd? onEvent(AppModel model, WidgetEvent event) {
  if (event case ListActivateEvent(:final id) when id == model.list.id) {
    model.selected = model.list.cursorItem;
  }
  return null;
}

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A pointer only reaches the list when it's actually the target — a click
  // on unrelated chrome (the "Selected" box, the help row) has a different
  // target (or none) and must not be treated as a click on the list.
  if (msg case Routed(:final targetId) when targetId != model.list.id) {
    return (model, null);
  }

  switch (model.list.update(msg)) {
    case Handled(:final events, :final cmd):
      return (model, Batch([cmd, for (final e in events) onEvent(model, e)]));
    case Declined():
      break;
  }

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
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));

  final ui = Container(
    topTitles: [Line('ListView Demo', style: resolver.ink(t.muted))],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            border: BorderType.plain,
            borderStyle: StyleResolver(theme).border(const {WidgetState.focused}),
            topTitles: [Line('Fruits (${fruits.length})', style: resolver.ink(t.focus))],
            child: ListView(
              model: model.list,
              theme: theme,
              itemBuilder: (item, index, _) => [Line(' $item')],
            ),
          ),
        ),
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
          child: Container(
            border: BorderType.plain,
            borderStyle: model.selected != null ? resolver.ink(t.success) : resolver.ink(t.border),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Selected')],
            child: Line(
              model.selected ?? 'Press Enter to select',
              style: model.selected != null ? resolver.ink(t.success) : resolver.ink(t.muted),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Line(
                '↑↓/jk navigate | Enter/click select | wheel scroll | Esc quit',
                style: resolver.ink(t.muted),
              ),
            ),
            ConstrainedBox(
              additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
              child: Line('Theme: ${model.themeName} (F1/F2)', style: resolver.ink(t.muted)),
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

Future<void> main() async {
  exit(
    await Application(title: 'ListView Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
