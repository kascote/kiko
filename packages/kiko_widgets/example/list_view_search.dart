// Demonstrates combining TextInput with a filterable ListView.
//
// Shows how to:
// - Filter a list based on text input
// - Handle focus between search and list using FocusGroup
// - Update dataSource when filter changes
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
    dataSource: ListDataSource.fromList(allItems),
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

    // Update dataSource - this resets cursor to 0
    list.dataSource = ListDataSource.fromList(filteredItems);
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

  // Search box
  final searchBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.search.focused ? theme.focus : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextInput(model.search, theme: theme),
    ).titleTop(Line('Search (${items.length}/${allItems.length})')),
  );

  // List area using ListView
  final listBox = Expanded(
    child: Block(
      borders: Borders.all,
      borderStyle: model.list.focused ? theme.focus : theme.border,
      child: ListView(
        model: model.list,
        theme: theme,
        itemBuilder: (item, index, _) {
          final style = model.selected == item ? Style(fg: theme.success.fg) : const Style();
          return Text.raw(' $item', style: style);
        },
        emptyPlaceholder: Text.raw('No matches', style: theme.muted),
      ),
    ).titleTop(Line('Results')),
  );

  // Selected item display
  final selectedBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.selected != null ? theme.success : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        model.selected ?? 'Press Enter to select',
        style: model.selected != null ? Style(fg: theme.success.fg) : theme.muted,
      ),
    ).titleTop(Line('Selected')),
  );

  // Help
  final help = Fixed(
    1,
    child: Row(
      children: [
        Expanded(
          child: Text.raw(
            'Tab switch | ↑↓/jk nav | Enter select | / search | Esc quit',
            style: theme.muted,
          ),
        ),
        Fixed(25, child: themeIndicator(model)),
      ],
    ),
  );

  final ui = Block(
    child: Column(children: [searchBox, listBox, selectedBox, help]),
  ).titleTop(Line('Searchable List Demo', style: theme.muted));

  frame.renderWidget(ui, frame.area);
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
