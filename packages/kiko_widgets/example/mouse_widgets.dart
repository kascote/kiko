// Real widgets, driven by the mouse in one routing line.
//
// A TableView and a ListView, each a real kiko widget with its own
// `update(Msg)`. The app already knows how to drive them from the KEYBOARD —
// route the message to the focused one, switch on the result. Making them
// mouse-driven adds almost nothing:
//
//   1. Turn the mouse on (`mouseEvents: true`). That is the only wiring: a kiko
//      widget already tags its own region with its model id (`..tag = model.id`
//      in its build), so a pointer resolves to it with nothing added around it.
//      `Tagged(...)` is for an app-composed region with no model of its own — a
//      panel, a form — not for a widget that tags itself; see
//      scrollable_form.dart.
//
//   2. Hand the FocusGroup to a FocusRouter and call it as one arm of update.
//      The router delivers a pointer to the widget answering to its id, sends
//      every other key to the focused widget, moves focus to whatever a press
//      lands on (focus is the app's to arbitrate — a widget cannot see its
//      siblings — and the router is app-side glue doing exactly that), and
//      reserves the traversal key before any widget sees it.
//
// Everything else is already there. A click emits the SAME `TableActionCmd` /
// `ListActionCmd` an Enter emits, addressed by the same id, and key and pointer
// results converge in the router's answer — one switch handles both devices,
// and the app never grew a second, mouse-only path. The wheel scrolls whichever
// widget is under the cursor; hovering highlights a row. The router does not
// care that a Table and a List are different widgets.
//
// tab/shift+tab switch focus · ↑/↓ or the wheel moves · enter or a click activates · q quits

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

final List<Map<String, Object?>> employees = [
  {'id': '1', 'name': 'Alice Johnson', 'dept': 'Engineering'},
  {'id': '2', 'name': 'Bob Smith', 'dept': 'Marketing'},
  {'id': '3', 'name': 'Carol White', 'dept': 'Engineering'},
  {'id': '4', 'name': 'David Brown', 'dept': 'Sales'},
  {'id': '5', 'name': 'Eva Martinez', 'dept': 'Engineering'},
  {'id': '6', 'name': 'Frank Lee', 'dept': 'Marketing'},
  {'id': '7', 'name': 'Grace Kim', 'dept': 'Sales'},
  {'id': '8', 'name': 'Henry Chen', 'dept': 'Engineering'},
  {'id': '9', 'name': 'Iris Davis', 'dept': 'HR'},
  {'id': '10', 'name': 'Jack Wilson', 'dept': 'Engineering'},
  {'id': '11', 'name': 'Karen Taylor', 'dept': 'Marketing'},
  {'id': '12', 'name': 'Leo Garcia', 'dept': 'Sales'},
  {'id': '13', 'name': 'Maya Patel', 'dept': 'Engineering'},
  {'id': '14', 'name': 'Nick Adams', 'dept': 'HR'},
  {'id': '15', 'name': 'Olivia Moore', 'dept': 'Engineering'},
];

const departments = ['Engineering', 'Marketing', 'Sales', 'HR', 'Finance', 'Legal', 'Support', 'Design'];

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  late final table = TableViewModel(
    id: 'employees',
    rows: employees,
    keyField: 'id',
    columns: [
      TableColumn(field: 'id', label: Line('ID'), width: 5, alignment: TextAlign.end),
      TableColumn(field: 'name', label: Line('Name')),
      TableColumn(field: 'dept', label: Line('Department'), width: 14),
    ],
  );

  late final list = ListViewModel<String, String>(id: 'departments', items: departments);

  late final FocusGroup<Component> focus = FocusGroup([table, list]);

  /// Routes keyboard and pointer traffic between the two widgets: pointers by
  /// the id each widget tags itself with, keys to the focused one, focus to
  /// whatever a press lands on. The default traversal bindings apply:
  /// Tab cycles forward, Shift+Tab backward.
  late final router = FocusRouter(focus);

  final List<String> log = [];

  void note(String line) {
    log.insert(0, line);
    if (log.length > 5) log.removeLast();
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  // (2) The one routing line, switched on where key and pointer results
  // converge. The activation cases are the whole point: a click and an Enter
  // arrive as the identical id-addressed command, so one case serves both
  // input devices.
  switch (model.router.route(msg, ctx)) {
    case Handled(cmd: TableActionCmd(:final id, action: 'primary')):
      final row = model.table.cursorRowData;
      model.note('$id · activated "${row?['name'] ?? '?'}"');
      return (model, null);
    case Handled(cmd: ListActionCmd(:final id)):
      model.note('$id · activated "${model.list.cursorItem ?? '?'}"');
      return (model, null);
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic — fall through to fallback keys
  }

  // Fallback: only input nothing consumed lands here, so q can never quit
  // out from under a widget that wanted the key.
  if (msg case KeyMsg(key: 'q')) return (model, const Quit());
  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

const Theme _theme = Theme.dark;

void view(AppModel model, Frame frame) {
  final resolver = StyleResolver(_theme);
  frame.buffer.setStyle(frame.area, Style(bg: _theme.background.color));

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line(
          'Mouse-driven widgets — tab · ↑/↓ · wheel · enter · click · q quits',
          style: _theme.muted.ink,
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _pane(
                'Employees',
                model.focus.focused.id == model.table.id,
                resolver,
                TableView(model: model.table, theme: _theme),
              ),
            ),
            Expanded(
              child: _pane(
                'Departments',
                model.focus.focused.id == model.list.id,
                resolver,
                ListView(model: model.list, theme: _theme, itemBuilder: (item, i, _) => [Line(' $item')]),
              ),
            ),
          ],
        ),
      ),
      _log(model),
    ],
  );

  frame.render(ui);
}

View _pane(String title, bool focused, StyleResolver resolver, View child) => Container(
  border: BorderType.plain,
  borderStyle: resolver.border({if (focused) WidgetState.focused}),
  topTitles: [Line(' $title ', style: focused ? _theme.focus.ink : _theme.muted.ink)],
  child: child,
);

View _log(AppModel model) => Container(
  border: BorderType.plain,
  topTitles: [Line(' activations ', style: _theme.muted.ink)],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      if (model.log.isEmpty)
        Line(' click a row, or press enter on one', style: _theme.muted.ink)
      else
        for (final line in model.log) Line(' $line', style: Style(fg: _theme.background.on)),
    ],
  ),
);

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Mouse-driven widgets', mouseEvents: true).run(
      init: AppModel(),
      update: update,
      view: view,
    ),
  );
}
