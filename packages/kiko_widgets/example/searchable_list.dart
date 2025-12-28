// Demonstrates combining TextInput with a filterable list.
//
// Shows how to:
// - Filter a list based on text input
// - Handle focus between search and list
// - Navigate list with arrow keys
// - Select items with Enter

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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

enum FocusArea { search, list }

class AppModel {
  final search = TextInputModel(placeholder: 'Type to filter...');

  FocusArea focusArea = FocusArea.search;
  int listIndex = 0;
  String? selected;

  AppModel() {
    search.focused = true;
  }

  List<String> get filteredItems {
    final query = search.value.toLowerCase();
    if (query.isEmpty) return allItems;
    return allItems.where((item) => item.toLowerCase().contains(query)).toList();
  }

  void setFocus(FocusArea area) {
    focusArea = area;
    search.focused = area == FocusArea.search;
    // Clamp list index when switching to list
    if (area == FocusArea.list && filteredItems.isNotEmpty) {
      listIndex = listIndex.clamp(0, filteredItems.length - 1);
    }
  }

  void moveListIndex(int delta) {
    if (filteredItems.isEmpty) return;
    listIndex = (listIndex + delta).clamp(0, filteredItems.length - 1);
  }

  void selectCurrent() {
    if (filteredItems.isNotEmpty && listIndex < filteredItems.length) {
      selected = filteredItems[listIndex];
    }
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Clear selection on new search
  final prevQuery = model.search.value;

  // Route to search input if focused
  if (model.focusArea == FocusArea.search) {
    final cmd = model.search.update(msg);

    // Reset list index when query changes
    if (model.search.value != prevQuery) {
      model
        ..listIndex = 0
        ..selected = null;
    }

    if (cmd is! Unhandled) return (model, cmd);
  }

  if (msg case KeyMsg(:final key)) {
    // Navigation between areas
    if (key == 'tab') {
      model.setFocus(
        model.focusArea == FocusArea.search ? FocusArea.list : FocusArea.search,
      );
      return (model, null);
    }

    // Arrow keys for list (work in both areas)
    if (key == 'down' || key == 'ctrl+n') {
      if (model.focusArea == FocusArea.search) {
        model.setFocus(FocusArea.list);
      } else {
        model.moveListIndex(1);
      }
      return (model, null);
    }
    if (key == 'up' || key == 'ctrl+p') {
      if (model.focusArea == FocusArea.list) {
        if (model.listIndex == 0) {
          model.setFocus(FocusArea.search);
        } else {
          model.moveListIndex(-1);
        }
      }
      return (model, null);
    }

    // Select with Enter
    if (key == 'enter') {
      model.selectCurrent();
      return (model, null);
    }

    // Back to search with Escape or /
    if (key == '/' || (key == 'escape' && model.focusArea == FocusArea.list)) {
      model.setFocus(FocusArea.search);
      return (model, null);
    }

    // Quit
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
  final items = model.filteredItems;

  // Search box
  final searchBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.focusArea == FocusArea.search ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextInput(model.search),
    ).titleTop(Line('Search (${items.length}/${allItems.length})')),
  );

  // List area
  final listBox = Expanded(
    child: Block(
      borders: Borders.all,
      borderStyle: model.focusArea == FocusArea.list ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      child: _ListView(
        items: items,
        selectedIndex: model.focusArea == FocusArea.list ? model.listIndex : -1,
      ),
    ).titleTop(Line('Results')),
  );

  // Selected item display
  final selectedBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.selected != null ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        model.selected ?? 'Press Enter to select',
        style: Style(
          fg: model.selected != null ? Color.white : Color.darkGray,
        ),
      ),
    ).titleTop(Line('Selected')),
  );

  // Help
  final help = Fixed(
    1,
    child: Text.raw(
      'Tab to switch | ↑↓ navigate | Enter select | / search | Esc quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
    ),
  );

  final ui =
      Block(
        child: Column(
          children: [searchBox, listBox, selectedBox, help],
        ),
      ).titleTop(
        Line('Searchable List Demo', style: const Style(fg: Color.darkGray)),
      );

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// LIST WIDGET
// ═══════════════════════════════════════════════════════════

class _ListView extends Widget {
  final List<String> items;
  final int selectedIndex;

  _ListView({required this.items, required this.selectedIndex});

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final visibleCount = area.height;

    // Calculate scroll offset to keep selection visible
    var scrollOffset = 0;
    if (selectedIndex >= 0) {
      if (selectedIndex >= scrollOffset + visibleCount) {
        scrollOffset = selectedIndex - visibleCount + 1;
      } else if (selectedIndex < scrollOffset) {
        scrollOffset = selectedIndex;
      }
    }

    for (var i = 0; i < visibleCount && i + scrollOffset < items.length; i++) {
      final itemIndex = i + scrollOffset;
      final item = items[itemIndex];
      final y = area.y + i;
      final isSelected = itemIndex == selectedIndex;

      final style = isSelected ? const Style(fg: Color.black, bg: Color.green) : const Style();

      final prefix = isSelected ? '▶ ' : '  ';
      final text = '$prefix$item';

      // Render line
      final lineArea = Rect.create(x: area.x, y: y, width: area.width, height: 1);

      if (isSelected) {
        // Fill background for selected item
        frame.buffer.setStyle(lineArea, style);
      }

      Span(text, style: style).render(lineArea, frame);
    }

    // Show empty state
    if (items.isEmpty) {
      const Span('No matches', style: Style(fg: Color.darkGray)).render(area, frame);
    }
  }
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
