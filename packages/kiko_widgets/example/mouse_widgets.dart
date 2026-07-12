// Real widgets, driven by the mouse in one routing line.
//
// A TableView and a ListView, each a real kiko widget with its own
// `update(Msg)`. The app already knows how to drive them from the KEYBOARD —
// route the message to the focused one, switch on the result. Making them
// mouse-driven adds almost nothing:
//
//   1. Turn the mouse on (`mouseEvents: true`). That is the only wiring: a kiko
//      widget already tags its own region with its model id (`..tag = model.id`
//      in its build), so the router resolves a pointer to it with nothing added
//      around it. `Tagged(...)` is for an app-composed region with no model of
//      its own — a panel, a form — not for a widget that tags itself; see
//      scrollable_form.dart.
//
//   2. Forward routed pointer traffic in the ONE generic line kiko_core
//      documents — the same `update(Msg)` the keyboard already calls, picked by
//      id from a map instead of by focus:
//
//        case Routed(:final targetId?) when targets.containsKey(targetId):
//          return _handle(model, targets[targetId]!.update(msg));
//
//   3. Add the one thing a click needs that the widget cannot do for itself:
//      move focus to whatever was pressed. Focus is the app's to arbitrate — a
//      widget cannot see its siblings — so this is one app-side line, not a
//      widget-emitted command.
//
// Everything else is already there. A click emits the SAME `TableActionCmd` /
// `ListActionCmd` an Enter emits, addressed by the same id, handled in the same
// place — the app never grew a second, mouse-only path. The wheel scrolls
// whichever widget is under the cursor; hovering highlights a row. The generic
// line does not care that a Table and a List are different widgets.
//
// tab switches focus · ↑/↓ or the wheel moves · enter or a click activates · q quits

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
    dataSource: TableDataSource.fromList(employees),
    keyField: 'id',
    columns: [
      TableColumn(field: 'id', label: Line('ID'), width: 5, alignment: TextAlign.end),
      TableColumn(field: 'name', label: Line('Name')),
      TableColumn(field: 'dept', label: Line('Department'), width: 14),
    ],
  );

  late final list = ListViewModel<String, String>(id: 'departments', dataView: DataView.fromList(departments));

  /// Every mouse-addressable widget, keyed by the id it tags its region with.
  /// App-side by design: the framework routes ids and stops there. The same map
  /// backs both the generic routing line and focus-on-click.
  late final Map<String, Component> targets = {table.id: table, list.id: list};

  late final FocusGroup<Component> focus = FocusGroup([table, list]);

  final List<String> log = [];

  void focusOn(String id) {
    final i = focus.children.indexWhere((c) => c.id == id);
    if (i >= 0) focus.setIndex(i);
  }

  void note(String line) {
    log.insert(0, line);
    if (log.length > 5) log.removeLast();
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext _) {
  // First frame: page the table's initial rows into its cache.
  if (msg is InitMsg) {
    model.table.insertRows(employees, 0);
    return (model, null);
  }

  // (3) A press focuses the widget it landed on, before that widget sees the
  // event. Focus is the app's to arbitrate — the router only says which id was
  // hit — so this is one app-side line, never a widget-emitted command.
  if (msg case PointerMsg(targetId: final id?, isDown: true)) model.focusOn(id);

  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());
    case KeyMsg(key: 'tab'):
      model.focus.cycle(1);
      return (model, null);

    // Keyboard drives the FOCUSED widget: one target, one pointer to it.
    case final KeyMsg key:
      return _handle(model, model.focus.focused.update(key));

    // (2) The one generic line. Every routed pointer message reaches the widget
    // answering to its id, through the same `update(Msg)` the keyboard uses. A
    // null targetId (the background) declines the pattern and falls through.
    case Routed(targetId: final id?) when model.targets.containsKey(id):
      return _handle(model, model.targets[id]!.update(msg));

    default:
      return (model, null);
  }
}

/// Receives what a widget returned, whether a key or a pointer produced it.
///
/// The activation cases are the whole point: a click and an Enter reach here as
/// the identical id-addressed command, so one case serves both input devices.
(AppModel, Cmd?) _handle(AppModel model, UpdateResult result) {
  switch (result) {
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
      return (model, null);
  }
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
