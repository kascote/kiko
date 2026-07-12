// Multi-select ListView with disabled items and multi-line items.
//
// Shows:
// - Multi-line items (itemHeight: 2)
// - Multi-select with Space toggle
// - Range select with Shift+arrow/j/k
// - Disabled items via isDisabled callback
// - Separator between items
// - Item key extraction for complex objects
// - Click activates a row (same as Enter; the checkbox toggle stays on Space),
//   wheel-scroll, per-row hover

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

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

class AppModel with ThemeSwitcher {
  late final list = ListViewModel<Contact, String>(
    dataView: DataView.fromList(contacts),
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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A pointer only reaches the list when it's actually the target — a click
  // on unrelated chrome (the "Checked" box, the help row) has a different
  // target (or none) and must not be treated as a click on the list.
  if (msg case Routed(:final targetId) when targetId != model.list.id) {
    return (model, null);
  }

  switch (model.list.update(msg)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break;
  }

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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final selectedKeys = model.list.getSelectedKeys();
  final selectedNames = contacts.where((c) => selectedKeys.contains(c.id)).map((c) => c.name);
  final summary = selectedKeys.isEmpty ? 'No contacts checked' : 'Checked: ${selectedNames.join(', ')}';

  final ui = Container(
    topTitles: [Line('Multi-Select Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            border: BorderType.plain,
            borderStyle: resolver.border(const {WidgetState.focused}),
            topTitles: [Line('Contacts', style: theme.focus.ink)],
            child: ListView(
              model: model.list,
              theme: theme,
              itemBuilder: (contact, index, state) {
                final checkbox = state.checked ? '●' : '○';
                final archivedTag = state.disabled ? ' (archived)' : '';
                return [
                  Line(
                    ' $checkbox ${contact.name}$archivedTag',
                    style: const Style(addModifier: Modifier.bold),
                  ),
                  Line('      ${contact.email}', style: theme.muted.ink),
                ];
              },
              separatorBuilder: () => Line.fromTexts([Text('─' * 40, style: theme.border.ink)]),
            ),
          ),
        ),
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
          child: Container(
            border: BorderType.plain,
            borderStyle: selectedKeys.isNotEmpty ? theme.success.ink : theme.border.ink,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Checked (${selectedKeys.length})')],
            child: Line(summary, style: selectedKeys.isNotEmpty ? Style(fg: theme.success.color) : theme.muted.ink),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Line(
                '↑↓/jk nav | Space toggle | Shift+↑↓ range | click activate | wheel scroll | Esc quit',
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
  await Application(title: 'Multi-Select Demo', mouseEvents: true).run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
