// Simple TableView example with static data.
//
// Shows:
// - Basic setup with TableDataSource.fromList()
// - Column definitions with width/alignment
// - Cell-level cursor navigation (arrows, h/j/k/l)
// - Row selection (space)
// - Confirm action (Enter)

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
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  late final table = TableViewModel(
    dataSource: TableDataSource.fromList(employees),
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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Initial data load
  if (msg is InitMsg) {
    // Load first page synchronously (fromList returns immediately)
    model.table.insertRows(employees, 0);
    return (model, null);
  }

  final cmd = model.table.update(msg);

  // Handle confirm
  if (cmd case TableActionCmd(:final id, action: 'primary')) {
    if (id == model.table.id) {
      final row = model.table.cursorRowData;
      final field = model.table.cursorColField;
      final value = model.table.cursorCellValue;
      model.confirmedCell = '$field: $value (row ${row?['id']})';
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
  final theme = model.theme;
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final tableWidget = Box(
    border: BorderType.plain,
    borderStyle: theme.focus,
    topTitles: [Line('Employees (${employees.length})', style: theme.focus)],
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
    child: Box(
      border: BorderType.plain,
      borderStyle: selectedCount > 0 ? theme.success : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Selection')],
      child: Line(
        selectedInfo,
        style: selectedCount > 0 ? Style(fg: theme.success.fg) : theme.muted,
      ),
    ),
  );

  // Confirmed cell info
  final confirmedBox = ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
    child: Box(
      border: BorderType.plain,
      borderStyle: model.confirmedCell != null ? theme.accent : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Confirmed')],
      child: Line(
        model.confirmedCell ?? 'Press Enter to confirm cell',
        style: model.confirmedCell != null ? Style(fg: theme.accent.fg) : theme.muted,
      ),
    ),
  );

  final help = Row(
    children: [
      Expanded(
        child: Line(
          '↑↓←→/hjkl nav | Space select | Enter confirm | Esc quit',
          style: theme.muted,
        ),
      ),
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
        child: Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted),
      ),
    ],
  );

  final ui = Box(
    topTitles: [Line('TableView Demo', style: theme.muted)],
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

void main() async {
  await Application(title: 'TableView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
