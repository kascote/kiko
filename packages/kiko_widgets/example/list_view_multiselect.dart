// Multi-select ListView with disabled items and multi-line items.
//
// Shows:
// - Multi-line items (itemHeight: 2)
// - Multi-select with Space toggle
// - Range select with Shift+arrow/j/k
// - Disabled items via isDisabled callback
// - Separator between items
// - Item key extraction for complex objects

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

class Contact {
  final String id;
  final String name;
  final String email;
  final bool archived;

  const Contact(this.id, this.name, this.email, {this.archived = false});
}

final contacts = [
  const Contact('1', 'Alice Anderson', 'alice@example.com'),
  const Contact('2', 'Bob Brown', 'bob@example.com'),
  const Contact('3', 'Charlie Chen', 'charlie@example.com', archived: true),
  const Contact('4', 'Diana Davis', 'diana@example.com'),
  const Contact('5', 'Eve Evans', 'eve@example.com'),
  const Contact('6', 'Frank Fisher', 'frank@example.com', archived: true),
  const Contact('7', 'Grace Garcia', 'grace@example.com'),
  const Contact('8', 'Henry Hill', 'henry@example.com'),
  const Contact('9', 'Ivy Irwin', 'ivy@example.com'),
  const Contact('10', 'Jack Jones', 'jack@example.com'),
  const Contact('11', 'Kate Kim', 'kate@example.com', archived: true),
  const Contact('12', 'Leo Lee', 'leo@example.com'),
];

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  late final list = ListViewModel<Contact, String>(
    dataSource: ListDataSource.fromList(contacts),
    itemKey: (c) => c.id, // use ID for selection tracking
    itemHeight: 2, // 2 lines per item
    multiSelect: true,
    isDisabled: (i) => contacts[i].archived, // archived = disabled
    focused: true,
  );
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  final cmd = model.list.update(msg);
  if (cmd is! Unhandled) return (model, cmd);

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
      itemBuilder: (contact, index, state) {
        final checkbox = state.checked ? '✅' : '⬜';

        final nameStyle = Style(
          fg: state.disabled
              ? Color.darkGray
              : state.focused
              ? Color.black
              : Color.white,
          bg: state.focused ? Color.green : null,
          addModifier: state.disabled ? Modifier.empty : Modifier.bold,
        );
        final emailStyle = Style(
          fg: state.disabled ? Color.darkGray : Color.gray,
          bg: state.focused ? Color.green : null,
        );
        final archivedTag = state.disabled ? ' (archived)' : '';

        return Column(
          children: [
            Fixed(
              1,
              child: Text.raw(
                ' $checkbox ${contact.name}$archivedTag',
                style: nameStyle,
              ),
            ),
            Fixed(1, child: Text.raw('      ${contact.email}', style: emailStyle)),
          ],
        );
      },
      separatorBuilder: () => Line.fromSpans([Span('─' * 40, style: const Style(fg: Color.darkGray))]),
    ),
  ).titleTop(Line('Contacts'));

  // Selection summary
  final selectedKeys = model.list.getSelectedKeys();
  final selectedNames = contacts.where((c) => selectedKeys.contains(c.id)).map((c) => c.name);
  final summary = selectedKeys.isEmpty ? 'No contacts checked' : 'Checked: ${selectedNames.join(', ')}';

  final summaryBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: selectedKeys.isNotEmpty ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        summary,
        style: Style(fg: selectedKeys.isNotEmpty ? Color.white : Color.darkGray),
      ),
    ).titleTop(Line('Checked (${selectedKeys.length})')),
  );

  final help = Fixed(
    1,
    child: Text.raw(
      '↑↓/jk nav | Space toggle | Shift+↑↓ range | Esc quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
    ),
  );

  final ui = Block(
    child: Column(
      children: [
        Expanded(child: listWidget),
        summaryBox,
        help,
      ],
    ),
  ).titleTop(Line('Multi-Select Demo', style: const Style(fg: Color.darkGray)));

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Multi-Select Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
