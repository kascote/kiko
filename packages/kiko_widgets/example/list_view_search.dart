// Demonstrates combining TextInput with a filterable ListView.
//
// Shows how to:
// - Filter a list based on text input
// - Handle focus between search and list using FocusGroup
// - Swap the list's data view when the filter changes
// - Select items with Enter via ListConfirmCmd
// - Click the search box to place the caret, click a result to select it
//   (same as Enter), wheel-scroll and per-row hover on the list

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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A pointer reaches whichever widget it's actually addressed to — a wheel
  // scrolls and a hover highlights the list even while search holds
  // keyboard focus. A down-click also moves keyboard focus (the app's call).
  if (msg case Routed(:final targetId)) {
    if (targetId == model.search.id) {
      if (msg case final PointerMsg pointer when pointer.isDown) {
        model.search.focused = true;
        model.list.focused = false;
      }
      final result = model.search.update(msg);
      model.refreshFilter();
      return switch (result) {
        Handled(:final cmd) => (model, cmd),
        Declined() => (model, null),
      };
    }
    if (targetId == model.list.id) {
      if (msg case final PointerMsg pointer when pointer.isDown) {
        model.list.focused = true;
        model.search.focused = false;
      }
      return _handleListResult(model, model.list.update(msg));
    }
    return (model, null); // addressed to neither widget we own
  }

  // Route to search input if focused (keyboard)
  if (model.search.focused) {
    final result = model.search.update(msg);

    // Refresh filter after search processes the message
    model.refreshFilter();

    switch (result) {
      case Handled(:final cmd):
        return (model, cmd);
      case Declined():
        break;
    }
  }

  // Route to list if focused (keyboard)
  if (model.list.focused) {
    final result = model.list.update(msg);

    // Handle confirm
    if (result case Handled(cmd: ListActionCmd(:final id))) {
      if (id == model.list.id) {
        model.selected = model.list.cursorItem;
      }
      return (model, null);
    }

    switch (result) {
      case Handled(:final cmd):
        return (model, cmd);
      case Declined():
        break;
    }
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

/// Shared by the pointer and keyboard paths: installs a confirmed selection,
/// or otherwise just runs the result's effect.
(AppModel, Cmd?) _handleListResult(AppModel model, UpdateResult result) {
  if (result case Handled(cmd: ListActionCmd(:final id)) when id == model.list.id) {
    model.selected = model.list.cursorItem;
    return (model, null);
  }
  return switch (result) {
    Handled(:final cmd) => (model, cmd),
    Declined() => (model, null),
  };
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme);
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final items = model.filteredItems;

  final ui = Box(
    topTitles: [Line('Searchable List Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        // Search box
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
          child: Box(
            border: BorderType.plain,
            borderStyle: resolver.border({if (model.search.focused) WidgetState.focused}),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Search (${items.length}/${allItems.length})')],
            child: ConstrainedBox(
              additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
              child: TextInput(model: model.search, theme: theme),
            ),
          ),
        ),
        // List area using ListView
        Expanded(
          child: Box(
            border: BorderType.plain,
            borderStyle: resolver.border({if (model.list.focused) WidgetState.focused}),
            topTitles: [Line('Results')],
            child: ListView(
              model: model.list,
              theme: theme,
              itemBuilder: (item, index, _) {
                final style = model.selected == item ? Style(fg: theme.success.color) : const Style();
                return [Line(' $item', style: style)];
              },
              emptyPlaceholder: Line('No matches', style: theme.muted.ink),
            ),
          ),
        ),
        // Selected item display
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
        // Help
        Row(
          children: [
            Expanded(
              child: Line(
                'Tab/click switch | ↑↓/jk nav | Enter/click select | wheel scroll | / search | Esc quit',
                style: theme.muted.ink,
              ),
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
  await Application(title: 'Searchable List Demo', mouseEvents: true).run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
