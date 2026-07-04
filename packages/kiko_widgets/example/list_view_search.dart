// Demonstrates combining TextInput with a filterable ListView.
//
// Shows how to:
// - Filter a list based on text input
// - Handle focus between search and list using FocusGroup
// - Swap the list's data view when the filter changes
// - Select items with Enter via ListConfirmCmd

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

const allItems = [
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
  final search = TextInputModel(placeholder: 'Type to filter...');
  late final list = ListViewModel<String, String>(
    dataView: DataView.fromList(allItems),
  );

  String _lastQuery = '';
  String? selected;

  AppModel() {
    search.focused = true;
  }

  List<String> get filteredItems {
    final query = search.value.toLowerCase();
    if (query.isEmpty) return allItems;
    return allItems.where((item) => item.toLowerCase().contains(query)).toList();
  }

  /// Update list dataSource when filter changes.
  void refreshFilter() {
    final query = search.value;
    if (query == _lastQuery) return;
    _lastQuery = query;

    // Swap the whole backing in — a synchronous client-side filter, not a load.
    list.dataView = DataView.fromList(filteredItems);
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Route to search input if focused
  if (model.search.focused) {
    final cmd = model.search.update(msg);

    // Refresh filter after search processes the message
    model.refreshFilter();

    if (cmd is! Unhandled) return (model, cmd);
  }

  // Route to list if focused
  if (model.list.focused) {
    final cmd = model.list.update(msg);

    // Handle confirm
    if (cmd case ListActionCmd(:final id)) {
      if (id == model.list.id) {
        model.selected = model.list.cursorItem;
      }
      return (model, null);
    }

    if (cmd is! Unhandled) return (model, cmd);
  }

  if (msg case KeyMsg(:final key)) {
    // Tab switches focus
    if (key == 'tab') {
      if (model.search.focused) {
        model.search.focused = false;
        model.list.focused = true;
      } else {
        model.list.focused = false;
        model.search.focused = true;
      }
      return (model, null);
    }

    // Down arrow from search enters list
    if (key == 'down' && model.search.focused) {
      model.search.focused = false;
      model.list.focused = true;
      return (model, null);
    }

    // / focuses search
    if (key == '/') {
      model.list.focused = false;
      model.search.focused = true;
      return (model, null);
    }

    // Escape: if in list, go to search; otherwise quit
    if (key == 'escape') {
      if (model.list.focused) {
        model.list.focused = false;
        model.search.focused = true;
        return (model, null);
      }
      return (model, const Quit());
    }

    // Quit
    if (key == 'ctrl+q') {
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

  final items = model.filteredItems;

  final ui = box(
    topTitles: [Line('Searchable List Demo', style: theme.muted)],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search box
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
          child: box(
            border: BorderType.plain,
            borderStyle: model.search.focused ? theme.focus : theme.border,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Search (${items.length}/${allItems.length})')],
            child: ConstrainedBox(
              additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
              child: textInput(model.search, theme),
            ),
          ),
        ),
        // List area using ListView
        Expanded(
          child: box(
            border: BorderType.plain,
            borderStyle: model.list.focused ? theme.focus : theme.border,
            topTitles: [Line('Results')],
            child: listView(
              model: model.list,
              theme: theme,
              itemBuilder: (item, index, _) {
                final style = model.selected == item ? Style(fg: theme.success.fg) : const Style();
                return [Line(' $item', style: style)];
              },
              emptyPlaceholder: Line('No matches', style: theme.muted),
            ),
          ),
        ),
        // Selected item display
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
          child: box(
            border: BorderType.plain,
            borderStyle: model.selected != null ? theme.success : theme.border,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Selected')],
            child: lineNode(
              Line(
                model.selected ?? 'Press Enter to select',
                style: model.selected != null ? Style(fg: theme.success.fg) : theme.muted,
              ),
            ),
          ),
        ),
        // Help
        Row(
          children: [
            Expanded(
              child: lineNode(
                Line('Tab switch | ↑↓/jk nav | Enter select | / search | Esc quit', style: theme.muted),
              ),
            ),
            ConstrainedBox(
              additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
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
  await Application(title: 'Searchable List Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
