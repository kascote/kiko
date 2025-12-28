// Simple ListView example with string items.
//
// Shows:
// - Basic list setup with ListDataSource.fromList()
// - Cursor navigation (arrows, j/k, pageUp/pageDown)
// - Item rendering via itemBuilder
// - Confirm action (Enter)

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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

class AppModel {
  // Simple case: no itemKey needed, strings are their own keys
  final list = ListViewModel<String, String>(
    dataSource: ListDataSource.fromList(fruits),
    focused: true,
  );

  String? selected;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  final cmd = model.list.update(msg);

  // Handle confirm
  if (cmd case ListConfirmCmd(:final source)) {
    if (source == model.list) {
      model.selected = model.list.getCursorItem();
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
  final listWidget = Block(
    borders: Borders.all,
    borderStyle: const Style(fg: Color.green),
    child: ListView(
      model: model.list,
      itemBuilder: (item, index, state) {
        final style = state.focused ? const Style(fg: Color.black, bg: Color.green) : const Style();
        return Text.raw(' $item', style: style);
      },
    ),
  ).titleTop(Line('Fruits (${fruits.length})'));

  final selectedBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.selected != null ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        model.selected ?? 'Press Enter to select',
        style: Style(fg: model.selected != null ? Color.white : Color.darkGray),
      ),
    ).titleTop(Line('Selected')),
  );

  final help = Fixed(
    1,
    child: Text.raw(
      '↑↓/jk navigate | Enter select | Esc quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
    ),
  );

  final ui = Block(
    child: Column(
      children: [
        Expanded(child: listWidget),
        selectedBox,
        help,
      ],
    ),
  ).titleTop(Line('ListView Demo', style: const Style(fg: Color.darkGray)));

  frame.renderWidget(ui, frame.area);
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
