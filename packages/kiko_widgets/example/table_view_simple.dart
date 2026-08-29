// Simple TableView example with static data.
//
// Shows:
// - Basic setup: rows straight into the constructor
// - Column definitions with width/alignment
// - Cell-level cursor navigation (arrows, h/j/k/l)
// - Row selection (space)
// - Confirm action (Enter)
// - Crosshair toggle (c): current row + current column, not just the cursor
//   row and cell
// - Custom anatomy toggle (y): a TableViewStyle override replaces the
//   theme-derived crosshair with a fixed warm look, independent of theme
// - Click-to-select, wheel-scroll, per-row hover

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

final List<Map<String, Object?>> employees = [
  {'id': '1', 'name': 'Alice Johnson', 'dept': 'Engineering', 'salary': 95000},
  {'id': '2', 'name': 'Bob Smith', 'dept': 'Marketing', 'salary': 72000},
  {'id': '3', 'name': 'Carol White', 'dept': 'Engineering', 'salary': 88000},
  {'id': '4', 'name': 'David Brown', 'dept': 'Sales', 'salary': 65000},
  {'id': '5', 'name': 'Eva Martinez', 'dept': 'Engineering', 'salary': 102000},
  {'id': '6', 'name': 'Frank Lee', 'dept': 'Marketing', 'salary': 78000},
  {'id': '7', 'name': 'Grace Kim', 'dept': 'Sales', 'salary': 71000},
  {'id': '8', 'name': 'Henry Chen', 'dept': 'Engineering', 'salary': 92000},
  {'id': '9', 'name': 'Iris Davis', 'dept': 'HR', 'salary': 68000},
  {'id': '10', 'name': 'Jack Wilson', 'dept': 'Engineering', 'salary': 115000},
  {'id': '11', 'name': 'Karen Taylor', 'dept': 'Marketing', 'salary': 82000},
  {'id': '12', 'name': 'Leo Garcia', 'dept': 'Sales', 'salary': 69000},
  {'id': '13', 'name': 'Maya Patel', 'dept': 'Engineering', 'salary': 98000},
  {'id': '14', 'name': 'Nick Adams', 'dept': 'HR', 'salary': 62000},
  {'id': '15', 'name': 'Olivia Moore', 'dept': 'Engineering', 'salary': 105000},
];

// ═══════════════════════════════════════════════════════════
// STYLE
// ═══════════════════════════════════════════════════════════

// A fixed, theme-independent look for the crosshair — the "this table gets
// an orange crosshair" tier: an anatomy override wins outright over whatever
// the current theme would derive, ember or not.
const _emberTableStyle = TableViewStyle(
  cursorRow: Style(bg: Color.rgb(0x2a1d10)),
  cursorColumn: Style(bg: Color.rgb(0x2a1d10)),
  cursorCell: Style(
    fg: Color.rgb(0x0a0908),
    bg: Color.rgb(0xe07830),
    addModifier: Modifier.bold,
  ),
);

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  late final table = TableViewModel(
    rows: employees,
    keyField: 'id',
    columns: [
      TableColumn(
        field: 'id',
        label: Line('ID'),
        width: 6,
        alignment: TextAlign.end,
      ),
      TableColumn(
        field: 'name',
        label: Line('Name', style: const Style(addModifier: Modifier.bold)),
      ),
      TableColumn(
        field: 'dept',
        label: Line('Department', style: const Style(addModifier: Modifier.bold)),
        width: 15,
        render: (ctx) {
          final dept = ctx.value?.toString() ?? '';
          final color = switch (dept) {
            'Engineering' => Color.cyan,
            'Marketing' => Color.magenta,
            'Sales' => Color.green,
            'HR' => Color.yellow,
            _ => Color.white,
          };
          return Line.fromTexts([Text(dept, style: Style(fg: color))]);
        },
      ),
      TableColumn(
        field: 'salary',
        label: Line('Salary', style: const Style(addModifier: Modifier.bold)),
        width: 12,
        alignment: TextAlign.end,
        render: (ctx) {
          final salary = ctx.value as int? ?? 0;
          final formatted = '\$${_formatNumber(salary)}';
          return Line(formatted);
        },
      ),
    ],
    selectionEnabled: true,
    focused: true,
  );

  String? confirmedCell;

  /// Whether the ember-style [_emberTableStyle] override is active.
  bool customStyleOn = false;
}

String _formatNumber(int n) {
  final str = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Crosshair + custom anatomy toggles, ahead of the table's own key
  // bindings so 'c'/'y' never reach it as unhandled keys.
  if (msg case KeyMsg(:final key)) {
    if (key == 'c') {
      model.table.showCrosshair = !model.table.showCrosshair;
      return (model, null);
    }
    if (key == 'y') {
      model.customStyleOn = !model.customStyleOn;
      model.table.styles = model.customStyleOn ? _emberTableStyle : const TableViewStyle();
      return (model, null);
    }
  }

  // A pointer only reaches the table when it's actually the target — a click
  // on unrelated chrome (the selection/confirmed boxes, the help row) has a
  // different target (or none) and must not be treated as a click on the table.
  if (msg case Routed(:final targetId) when targetId != model.table.id) {
    return (model, null);
  }

  final result = model.table.update(msg);

  // Handle confirm
  if (result case Handled(cmd: TableActionCmd(:final id, action: 'primary'))) {
    if (id == model.table.id) {
      final row = model.table.cursorRowData;
      final field = model.table.cursorColField;
      final value = model.table.cursorCellValue;
      model.confirmedCell = '$field: $value (row ${row?['id']})';
    }
    return (model, null);
  }

  switch (result) {
    case Handled(:final cmd):
      return (model, cmd);
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

  final tableWidget = Container(
    border: BorderType.plain,
    borderStyle: StyleResolver(theme).border(const {WidgetState.focused}),
    topTitles: [Line('Employees (${employees.length})', style: resolver.ink(t.focus))],
    child: TableView(
      model: model.table,
      theme: theme,
    ),
  );

  // Selected rows info
  final selectedKeys = model.table.getSelectedKeys();
  final selectedCount = selectedKeys.length;
  final selectedInfo = selectedCount > 0
      ? 'Selected: $selectedCount rows (${selectedKeys.join(", ")})'
      : 'No rows selected';

  final selectedBox = ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
    child: Container(
      border: BorderType.plain,
      borderStyle: selectedCount > 0 ? resolver.ink(t.success) : resolver.ink(t.border),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Selection')],
      child: Line(
        selectedInfo,
        style: selectedCount > 0 ? resolver.ink(t.success) : resolver.ink(t.muted),
      ),
    ),
  );

  // Confirmed cell info
  final confirmedBox = ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
    child: Container(
      border: BorderType.plain,
      borderStyle: model.confirmedCell != null ? resolver.ink(t.accent) : resolver.ink(t.border),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Confirmed')],
      child: Line(
        model.confirmedCell ?? 'Press Enter to confirm cell',
        style: model.confirmedCell != null ? resolver.ink(t.accent) : resolver.ink(t.muted),
      ),
    ),
  );

  final help = Row(
    children: [
      Expanded(
        child: Line(
          '↑↓←→/hjkl/click nav | Space select | Enter confirm | wheel scroll | c crosshair'
          '${model.table.showCrosshair ? " (on)" : ""} | y style'
          '${model.customStyleOn ? " (on)" : ""} | Esc quit',
          style: resolver.ink(t.muted),
        ),
      ),
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
        child: Line('Theme: ${model.themeName} (F1/F2)', style: resolver.ink(t.muted)),
      ),
    ],
  );

  final ui = Container(
    topTitles: [Line('TableView Demo', style: resolver.ink(t.muted))],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tableWidget),
        selectedBox,
        confirmedBox,
        help,
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
    await Application(title: 'TableView Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
